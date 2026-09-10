#!/usr/bin/env python3
"""Move the SQLite/JSON ledger into Supabase, once.

    python3 tools/migrate_to_supabase.py \
        --url https://<ref>.supabase.co \
        --user-email you@example.com \
        --dry-run

    # then, for real, with the service_role key in the environment:
    SUPABASE_SERVICE_KEY=... python3 tools/migrate_to_supabase.py \
        --url https://<ref>.supabase.co --user-email you@example.com

This needs the service_role key because it writes rows on somebody's behalf,
which is exactly what row level security exists to prevent. The key is read
from the environment rather than an argument so it does not end up in your
shell history, and it is never printed.

What it does, in order:

  categories    reconciles the signup trigger's defaults with your real list,
                by inserting what is missing and then removing what is extra --
                in that order, because deleting your last category of a kind is
                refused by a trigger, and rightly so.
  accounts      inserted with fresh UUIDs; the old ISO-timestamp ids are kept
                in a lookup so transactions and subscriptions land on the right
                account.
  transactions  the '<uuid>_out' / '<uuid>_in' pairs are collapsed into a
                shared transfer_group_id.
  subscriptions inserted last, so their account_id resolves.

It then verifies by arithmetic rather than by eye: row counts, the
expense/income split, and every account's closing balance to the cent. A
mismatch is reported and exits non-zero.

Safe to abort: it refuses to run at all if the target user already has
transactions, so a half-finished run is fixed by deleting that user's rows and
starting again, never by guessing what got through.
"""
import argparse
import json
import os
import sqlite3
import sys
import uuid
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "backend")


# --- tiny PostgREST/GoTrue client -------------------------------------------

class Api:
    def __init__(self, url, key):
        self.url = url.rstrip("/")
        self._key = key

    def _call(self, method, path, body=None, headers=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(f"{self.url}{path}", data=data, method=method)
        req.add_header("apikey", self._key)
        req.add_header("Authorization", f"Bearer {self._key}")
        req.add_header("Content-Type", "application/json")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=120) as res:
                raw = res.read().decode()
                return json.loads(raw) if raw.strip() else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode()[:600]
            raise SystemExit(f"\n{method} {path} failed ({e.code})\n  {detail}")

    def get(self, path):
        return self._call("GET", path)

    def insert(self, table, rows):
        """Returns nothing; Prefer: return=minimal keeps 1,018 rows off the wire."""
        if not rows:
            return
        self._call("POST", f"/rest/v1/{table}", rows,
                   {"Prefer": "return=minimal"})

    def delete(self, path):
        return self._call("DELETE", f"/rest/v1/{path}")

    def count(self, path):
        """Rows matching a filter, without fetching them.

        PostgREST caps a plain select at 1,000 rows (db-max-rows), so counting
        by len() of a result silently reports 1,000 for a ledger of 1,018 --
        which looks exactly like a failed import that was in fact complete.
        Prefer: count=exact puts the real total in Content-Range instead.
        """
        req = urllib.request.Request(f"{self.url}/rest/v1/{path}", method="HEAD")
        req.add_header("apikey", self._key)
        req.add_header("Authorization", f"Bearer {self._key}")
        req.add_header("Prefer", "count=exact")
        req.add_header("Range-Unit", "items")
        req.add_header("Range", "0-0")
        with urllib.request.urlopen(req, timeout=60) as res:
            # "0-0/1018", or "*/0" when nothing matches.
            return int(res.headers.get("Content-Range", "*/0").split("/")[-1])


# --- source data -------------------------------------------------------------

def read_source():
    with sqlite3.connect(os.path.join(BASE, "database.sqlite")) as conn:
        conn.row_factory = sqlite3.Row
        transactions = [dict(r) for r in conn.execute("SELECT * FROM transactions")]
    def load(name):
        with open(os.path.join(BASE, name)) as f:
            return json.load(f)
    return transactions, load("accounts.json"), load("subscriptions.json"), load("categories.json")


def cents(value):
    """Transaction amounts are already integer cents in a TEXT column."""
    return abs(int(str(value).strip()))


def ringgit_to_cents(value):
    """Subscriptions and opening balances are ringgit as JSON numbers.

    Rounded, never truncated: RM 0.29 is 28.999999999999996 hundredths in
    binary, and int() on that is 28.
    """
    return abs(round(float(value or 0) * 100))


# --- the migration -----------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--url", required=True, help="https://<ref>.supabase.co")
    p.add_argument("--user-email", required=True, help="the account to import into")
    p.add_argument("--dry-run", action="store_true",
                   help="report what would happen and change nothing")
    p.add_argument("--clear-first", action="store_true",
                   help="delete this user's accounts, transactions and "
                        "subscriptions before importing, to retry a failed run")
    args = p.parse_args()

    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not key:
        raise SystemExit(
            "Set SUPABASE_SERVICE_KEY to the project's service_role key.\n"
            "  Dashboard > Settings > API. It bypasses row level security, so keep\n"
            "  it out of your shell history and out of the repository.")

    api = Api(args.url, key)
    transactions, accounts, subscriptions, categories = read_source()

    # --- who are we importing into -----------------------------------------
    users = api.get("/auth/v1/admin/users?per_page=200")
    matches = [u for u in (users.get("users") or users)
               if (u.get("email") or "").lower() == args.user_email.lower()]
    if not matches:
        raise SystemExit(f"No account found for {args.user_email}. Sign up in the app first.")
    user_id = matches[0]["id"]
    print(f"Importing into {args.user_email}  ({user_id})")

    # --- refuse to run into a ledger that is not empty -----------------------
    # Accounts and subscriptions are checked as well as transactions, because a
    # run that fails partway leaves those behind -- and a second attempt would
    # then write a duplicate set rather than resuming.
    present = {
        table: api.get(f"/rest/v1/{table}?user_id=eq.{user_id}&select=id&limit=1")
        for table in ("transactions", "accounts", "subscriptions")
    }
    if any(present.values()) and not args.clear_first:
        found = ", ".join(t for t, rows in present.items() if rows)
        raise SystemExit(
            f"That account already has rows in: {found}.\n"
            "  This imports into an empty ledger only -- a second pass would write\n"
            "  a duplicate set rather than resuming, doubling every balance.\n"
            "  Re-run with --clear-first to wipe THIS user's rows and start over.")

    if args.clear_first and not args.dry_run:
        # Only ever this user's rows, and only the three tables it writes.
        for table in ("transactions", "subscriptions", "accounts"):
            api.delete(f"{table}?user_id=eq.{user_id}")
        print("Cleared the previous import for this account.")

    print(f"\nSource: {len(transactions)} transactions, {len(accounts)} accounts, "
          f"{len(subscriptions)} subscriptions")

    # --- categories ----------------------------------------------------------
    seeded = api.get(
        f"/rest/v1/categories?user_id=eq.{user_id}&select=id,kind,name")
    have = {(c["kind"], c["name"]) for c in seeded}
    want = {("expense", n) for n in categories.get("expense", [])} | \
           {("income", n) for n in categories.get("income", [])}

    to_add = sorted(want - have)
    to_drop = sorted(have - want)
    print(f"\nCategories: {len(have)} seeded at signup, {len(want)} in categories.json")
    for kind, name in to_add:
        print(f"   + {kind:<8} {name}")
    for kind, name in to_drop:
        print(f"   - {kind:<8} {name}")

    # --- plan the rest -------------------------------------------------------
    # Fresh UUIDs, generated by the database. Insert with the old id recorded in
    # a temporary column would be neater, but there is no such column -- so the
    # accounts go in first and are read back by name.
    by_name = {a["name"]: a for a in accounts}
    if len(by_name) != len(accounts):
        raise SystemExit("Two accounts share a name; the id lookup below needs them unique.")

    groups = defaultdict(list)
    for t in transactions:
        tid = str(t["id"])
        if tid.endswith("_out") or tid.endswith("_in"):
            groups[tid.rsplit("_", 1)[0]].append(t)
    print(f"Transfers: {len(groups)} pairs collapse into one group id each")

    if args.dry_run:
        print("\nDry run -- nothing was written.")
        report_expected(transactions, accounts)
        return

    # --- write ---------------------------------------------------------------
    if to_add:
        api.insert("categories", [
            {"user_id": user_id, "kind": k, "name": n} for k, n in to_add])
    # After the inserts, so removing these can never empty a kind.
    for kind, name in to_drop:
        api.delete(f"categories?user_id=eq.{user_id}&kind=eq.{kind}"
                   f"&name=eq.{urllib.parse.quote(name)}")
    print("Categories reconciled.")

    api.insert("accounts", [{
        "user_id": user_id,
        "name": a["name"],
        "type": a["type"],
        "initial_balance_cents": ringgit_to_cents(a.get("initial_balance")),
    } for a in accounts])
    written = api.get(f"/rest/v1/accounts?user_id=eq.{user_id}&select=id,name")
    new_id_by_name = {a["name"]: a["id"] for a in written}
    account_map = {old["id"]: new_id_by_name[old["name"]] for old in accounts}
    print(f"Accounts: {len(written)} written.")

    group_uuid = {}
    rows = []
    for t in transactions:
        tid = str(t["id"])
        group = None
        if tid.endswith("_out") or tid.endswith("_in"):
            stem = tid.rsplit("_", 1)[0]
            # A fresh uuid per pair, not the old stem: only 10 of the 64 stems
            # are uuid-shaped, the other 54 are ISO timestamps left over from an
            # earlier id scheme, and Postgres rejects those for a uuid column.
            group = group_uuid.setdefault(stem, str(uuid.uuid4()))
        rows.append({
            "user_id": user_id,
            "occurred_on": t["date"],
            "occurred_at": t["time"] or "00:00:00",
            "description": (t["description"] or "").strip(),
            "amount_cents": cents(t["amount"]),
            "category": t["category"] or "Uncategorized",
            "account_id": account_map.get(t["account_id"]),
            "type": "income" if t["type"] == "income" else "expense",
            "transfer_group_id": group,
        })

    for i in range(0, len(rows), 500):
        api.insert("transactions", rows[i:i + 500])
        print(f"Transactions: {min(i + 500, len(rows))}/{len(rows)}")

    api.insert("subscriptions", [{
        "user_id": user_id,
        "name": s["name"],
        "amount_cents": ringgit_to_cents(s.get("amount")),
        "category": s.get("category") or "Bills & Utilities",
        "account_id": account_map.get(s.get("account_id")),
        "day_of_month": int(s.get("day_of_month", 1)),
        "last_recorded_date": s.get("last_recorded_date"),
    } for s in subscriptions])
    print(f"Subscriptions: {len(subscriptions)} written.")

    verify(api, user_id, transactions, accounts)


def expected_balances(transactions, accounts):
    """Opening balance plus every transaction, in cents, exactly as the old
    get_account_balances() computed it."""
    balances = {a["id"]: ringgit_to_cents(a.get("initial_balance")) for a in accounts}
    for t in transactions:
        acc = t["account_id"]
        if acc not in balances:
            continue
        amount = cents(t["amount"])
        balances[acc] += amount if t["type"] == "income" else -amount
    return balances


def report_expected(transactions, accounts):
    print("\nExpected after import:")
    print(f"   transactions       {len(transactions)}")
    print(f"   expense / income   {sum(1 for t in transactions if t['type'] == 'expense')}"
          f" / {sum(1 for t in transactions if t['type'] == 'income')}")
    total = sum(expected_balances(transactions, accounts).values())
    print(f"   total balance      RM {total / 100:,.2f}")


def verify(api, user_id, transactions, accounts):
    print("\nVerifying...")
    problems = []

    total = api.count(f"transactions?user_id=eq.{user_id}&select=id")
    if total != len(transactions):
        problems.append(f"row count is {total}, expected {len(transactions)}")

    for kind in ("expense", "income"):
        want = sum(1 for t in transactions if t["type"] == kind)
        have = api.count(
            f"transactions?user_id=eq.{user_id}&type=eq.{kind}&select=id")
        if want != have:
            problems.append(f"{kind} count is {have}, expected {want}")

    groups = api.count(
        f"transactions?user_id=eq.{user_id}"
        f"&transfer_group_id=not.is.null&select=id")
    want_legs = sum(1 for t in transactions
                    if str(t["id"]).endswith(("_out", "_in")))
    if groups != want_legs:
        problems.append(f"transfer legs is {groups}, expected {want_legs}")

    view = api.get(f"/rest/v1/account_balances?user_id=eq.{user_id}"
                   f"&select=account_id,balance_cents")
    names = {a["id"]: a["name"] for a in api.get(
        f"/rest/v1/accounts?user_id=eq.{user_id}&select=id,name")}
    got_by_name = {names[b["account_id"]]: b["balance_cents"] for b in view}

    want_by_name = {}
    for old_id, want_cents in expected_balances(transactions, accounts).items():
        name = next(a["name"] for a in accounts if a["id"] == old_id)
        want_by_name[name] = want_cents

    print(f"\n   {'account':<18}{'expected':>14}{'actual':>14}")
    for name in sorted(want_by_name):
        want_c, got_c = want_by_name[name], got_by_name.get(name)
        mark = " " if want_c == got_c else "  <-- MISMATCH"
        print(f"   {name:<18}{want_c / 100:>14,.2f}{(got_c or 0) / 100:>14,.2f}{mark}")
        if want_c != got_c:
            problems.append(f"{name}: expected {want_c} cents, got {got_c}")

    print(f"\n   {'TOTAL':<18}{sum(want_by_name.values()) / 100:>14,.2f}"
          f"{sum(got_by_name.values()) / 100:>14,.2f}")

    if problems:
        print("\nFAILED:")
        for p in problems:
            print(f"   {p}")
        sys.exit(1)
    print("\nEvery figure matches. Keep backend/database.sqlite anyway.")


if __name__ == "__main__":
    main()
