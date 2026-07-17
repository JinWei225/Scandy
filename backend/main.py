import json
import os
import sqlite3
import threading
import uuid
from datetime import datetime
from receipt_extractor import extract_receipt_data

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(BASE_DIR, "database.sqlite")
SUBSCRIPTIONS_FILE = os.path.join(BASE_DIR, "subscriptions.json")

# Guards read-modify-write cycles on the JSON files (accounts, subscriptions).
# Waitress serves from multiple threads in a single process, so a threading
# lock is enough to prevent lost updates and duplicate subscription charges.
_JSON_LOCK = threading.RLock()

def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            date TEXT,
            time TEXT,
            description TEXT,
            amount TEXT,
            category TEXT,
            account_id TEXT,
            type TEXT,
            transfer_related_id TEXT
        )
    """)
    conn.commit()
    conn.close()

init_db()
ACCOUNTS_FILE = os.path.join(BASE_DIR, "accounts.json")

CATEGORIES = {
    "expense": [
        "Food & Drink",
        "Shopping",
        "Transport",
        "Bills & Utilities",
        "Entertainment",
        "Health",
        "Groceries",
        "Installments",
        "Other"
    ],
    "income": [
        "Salary",
        "Investments",
        "Gifts",
        "Refunds",
        "Other"
    ],
    "transfer": ["Transfer"]
}

def format_amount(raw):
    """Formats a stored cents value (TEXT column) as 'RM x.xx'. Falls back to RM 0.00 so a bad row can never break the frontend summaries."""
    try:
        return f"RM {int(raw) / 100.0:.2f}"
    except (ValueError, TypeError):
        return "RM 0.00"

def extract_data_from_image(image_path):
    # OCRBusyError intentionally propagates so the API can answer 429.
    data = extract_receipt_data(image_path)
    data = _clean_extracted_data(data)
    if data.get("amount"):
        # Partial result is fine: the user confirms everything in the UI anyway,
        # so missing date/time just default to now instead of failing the scan.
        now = datetime.now()
        if not data.get("date"):
            data["date"] = now.strftime("%d/%m/%Y")
        if not data.get("time"):
            data["time"] = now.strftime("%H:%M:%S")
        return data
    return {"error": "Could not extract an amount from the image", "date": None, "time": None, "amount": None}

def _clean_extracted_data(data):
    if "error" in data:
        return data

    # Clean the amount field, but don't add other fields yet
    if data.get("amount"):
        data["amount"] = data["amount"].replace('-', '')
    
    return data

def get_all_transactions():
    try:
        conn = get_db_connection()
        rows = conn.execute("SELECT * FROM transactions").fetchall()
        conn.close()
        data = []
        account_by_id = {}
        for row in rows:
            d = dict(row)
            try:
                cents = int(d.get("amount"))
            except (ValueError, TypeError):
                cents = 0
            d["amount_cents"] = cents
            d["amount"] = format_amount(cents)
            account_by_id[d["id"]] = d.get("account_id")
            data.append(d)

        # Expose both sides of a transfer so the frontend can pre-fill
        # From/To when editing either leg. Outgoing leg is type 'expense'.
        for d in data:
            related_id = d.get("transfer_related_id")
            if related_id and related_id in account_by_id:
                counterpart_account = account_by_id[related_id]
                if d.get("type") == "income":
                    d["from_account_id"] = counterpart_account
                    d["to_account_id"] = d.get("account_id")
                else:
                    d["from_account_id"] = d.get("account_id")
                    d["to_account_id"] = counterpart_account

        return sort_transactions(data)
    except Exception as e:
        print(f"Error reading DB: {e}")
        return []

def sort_transactions(data):
    # Sort by date and time, newest first.
    # Date format in JSON is "DD/MM/YYYY" or "YYYY-MM-DD"
    # Time format is "HH:MM:SS" or "HH:MM"
    
    def parse_datetime(item):
        d_str = item.get("date")
        t_str = item.get("time", "00:00:00")
        
        if not d_str or not isinstance(d_str, str):
            return datetime.min
            
        # Try finding the right date parser
        dt = None
        for d_fmt in ["%d/%m/%Y", "%Y-%m-%d"]:
            try:
                dt = datetime.strptime(d_str, d_fmt)
                break
            except ValueError:
                continue
        
        if not dt:
            return datetime.min
            
        # Try finding the right time parser
        for t_fmt in ["%H:%M:%S", "%H:%M"]:
            try:
                tm = datetime.strptime(t_str, t_fmt).time()
                return datetime.combine(dt.date(), tm)
            except ValueError:
                continue
        
        # Fallback to date only if time is weird
        return dt

    # Sort
    sorted_data = sorted(data, key=parse_datetime, reverse=True)
    return sorted_data

def create_manual_transaction(data):
    amount_int = int(round(float(data.get('amount', 0)) * 100))
    new_record = {
        "id": str(uuid.uuid4()),
        "date": data.get("date"),
        "time": data.get("time", "00:00:00"),
        "description": data.get("description"),
        "amount": str(amount_int),
        "category": data.get("category", "Uncategorized"),
        "account_id": data.get("account_id"),
        "type": data.get("type", "expense"),
        "transfer_related_id": None
    }
    
    conn = get_db_connection()
    conn.execute("""
        INSERT INTO transactions (id, date, time, description, amount, category, account_id, type, transfer_related_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (new_record["id"], new_record["date"], new_record["time"], new_record["description"], new_record["amount"], new_record["category"], new_record["account_id"], new_record["type"], new_record["transfer_related_id"]))
    conn.commit()
    conn.close()

    # Format amount for frontend response
    new_record["amount_cents"] = amount_int
    new_record["amount"] = format_amount(amount_int)
    return new_record

def _insert_transfer_pair(conn, data):
    """Inserts a transfer pair on an existing connection. Does not commit."""
    date_str = data.get("date")
    time_str = data.get("time", "00:00:00")
    amount_int = int(round(float(data.get("amount", 0)) * 100))
    from_account = data.get("from_account_id")
    to_account = data.get("to_account_id")
    description = data.get("description") or "Transfer"
    uid = str(uuid.uuid4())

    # Outgoing (Expense) from Source
    outgoing = {
        "id": f"{uid}_out",
        "date": date_str,
        "time": time_str,
        "description": description,
        "amount": str(amount_int),
        "category": "Transfer",
        "account_id": from_account,
        "type": "expense",
        "transfer_related_id": f"{uid}_in"
    }

    # Incoming (Income) to Destination
    incoming = {
        "id": f"{uid}_in",
        "date": date_str,
        "time": time_str,
        "description": description,
        "amount": str(amount_int),
        "category": "Transfer",
        "account_id": to_account,
        "type": "income",
        "transfer_related_id": f"{uid}_out"
    }

    for t in [outgoing, incoming]:
        conn.execute("""
            INSERT INTO transactions (id, date, time, description, amount, category, account_id, type, transfer_related_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (t["id"], t["date"], t["time"], t["description"], t["amount"], t["category"], t["account_id"], t["type"], t["transfer_related_id"]))

    for t in [outgoing, incoming]:
        t["amount_cents"] = amount_int
        t["amount"] = format_amount(amount_int)

    return [outgoing, incoming]

def create_transfer_transactions(data):
    """Creates a pair of transactions for a transfer."""
    conn = get_db_connection()
    try:
        pair = _insert_transfer_pair(conn, data)
        conn.commit()
    finally:
        conn.close()
    return pair

def update_transaction_by_id(transaction_id, data_to_update):
    """Finds a transaction and updates its details."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT * FROM transactions WHERE id = ?", (transaction_id,)).fetchone()

        if not row:
            return None # Indicate that the transaction was not found

        transaction_to_update = dict(row)
        related_id = transaction_to_update.get("transfer_related_id")

        # Editing an existing transfer, or converting a regular transaction into one.
        # The pair is recreated from scratch; everything happens in one commit so a
        # failure (e.g. bad amount) can never delete data without replacing it.
        if data_to_update.get("type") == "transfer":
            if not data_to_update.get("to_account_id") or not data_to_update.get("account_id"):
                raise ValueError("Transfer requires both From and To accounts.")

            # Parse the amount BEFORE deleting anything.
            amount_val = data_to_update.get("amount")
            if amount_val is not None:
                amount_val = float(str(amount_val).replace("RM", "").strip())
            else:
                try:
                    amount_val = int(transaction_to_update.get("amount")) / 100.0
                except (ValueError, TypeError):
                    amount_val = 0.0

            transfer_data = {
                "date": data_to_update.get("date", transaction_to_update["date"]),
                "time": data_to_update.get("time", transaction_to_update.get("time", "00:00:00")),
                "description": data_to_update.get("description") or transaction_to_update.get("description") or "Transfer",
                "amount": amount_val,
                "from_account_id": data_to_update.get("account_id"),
                "to_account_id": data_to_update.get("to_account_id")
            }

            conn.execute("DELETE FROM transactions WHERE id = ?", (transaction_id,))
            if related_id:
                conn.execute("DELETE FROM transactions WHERE id = ?", (related_id,))
            pair = _insert_transfer_pair(conn, transfer_data)
            conn.commit()
            return pair[0]

        # Converting a transfer leg into a regular expense/income: the counterpart
        # leg must go too, otherwise it lingers as a phantom on the other account.
        if related_id:
            conn.execute("DELETE FROM transactions WHERE id = ?", (related_id,))
            transaction_to_update["transfer_related_id"] = None

        # Update the fields from the provided data
        transaction_to_update["date"] = data_to_update.get("date", transaction_to_update["date"])
        transaction_to_update["time"] = data_to_update.get("time", transaction_to_update.get("time", "00:00:00"))
        transaction_to_update["description"] = data_to_update.get("description", transaction_to_update["description"])

        # Handle amount update - if it's a number, format it
        if "amount" in data_to_update:
             amount_str = str(data_to_update['amount']).replace("RM", "").strip()
             transaction_to_update["amount"] = str(int(round(float(amount_str) * 100)))

        transaction_to_update["category"] = data_to_update.get("category", transaction_to_update["category"])
        transaction_to_update["account_id"] = data_to_update.get("account_id", transaction_to_update.get("account_id"))
        transaction_to_update["type"] = data_to_update.get("type", transaction_to_update.get("type", "expense"))

        conn.execute("""
            UPDATE transactions SET
            date=?, time=?, description=?, amount=?, category=?, account_id=?, type=?, transfer_related_id=?
            WHERE id=?
        """, (
            transaction_to_update["date"],
            transaction_to_update["time"],
            transaction_to_update["description"],
            transaction_to_update["amount"],
            transaction_to_update["category"],
            transaction_to_update["account_id"],
            transaction_to_update["type"],
            transaction_to_update["transfer_related_id"],
            transaction_to_update["id"]
        ))
        conn.commit()
    finally:
        conn.close()

    try:
        transaction_to_update["amount_cents"] = int(transaction_to_update["amount"])
    except (ValueError, TypeError):
        transaction_to_update["amount_cents"] = 0
    transaction_to_update["amount"] = format_amount(transaction_to_update["amount"])
    return transaction_to_update

def delete_transaction_by_id(transaction_id):
    """Deletes a transaction by ID, along with the other leg if it is part of a transfer pair."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT transfer_related_id FROM transactions WHERE id = ?", (transaction_id,)).fetchone()
        if not row:
            return False
        conn.execute("DELETE FROM transactions WHERE id = ?", (transaction_id,))
        if row["transfer_related_id"]:
            conn.execute("DELETE FROM transactions WHERE id = ?", (row["transfer_related_id"],))
        conn.commit()
    finally:
        conn.close()
    return True

def _write_json_atomic(path, payload):
    """Writes JSON via a temp file + os.replace so a crash mid-write can never truncate the file."""
    tmp_path = f"{path}.tmp"
    with open(tmp_path, "w") as f:
        json.dump(payload, f, indent=4)
    os.replace(tmp_path, path)

def get_all_subscriptions():
    try:
        with _JSON_LOCK, open(SUBSCRIPTIONS_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_all_subscriptions(subscriptions):
    with _JSON_LOCK:
        _write_json_atomic(SUBSCRIPTIONS_FILE, subscriptions)

def save_subscription(data):
    with _JSON_LOCK:
        subscriptions = get_all_subscriptions()

        # Check if 'id' is missing or empty string/null
        if "id" not in data or not data["id"]:
            data["id"] = str(uuid.uuid4())
            subscriptions.append(data)
        else:
            # Update existing
            for i, sub in enumerate(subscriptions):
                if sub["id"] == data["id"]:
                    subscriptions[i] = data
                    break
            else:
                # If ID provided but not found, treat as new (or append)
                subscriptions.append(data)

        save_all_subscriptions(subscriptions)
    return data

def delete_subscription(sub_id):
    with _JSON_LOCK:
        subscriptions = get_all_subscriptions()
        initial_len = len(subscriptions)
        subscriptions = [s for s in subscriptions if s["id"] != sub_id]

        if len(subscriptions) < initial_len:
            save_all_subscriptions(subscriptions)
            return True
    return False

def check_and_record_subscriptions():
    # The lock is held across the whole check-and-record pass so two clients
    # hitting /api/subscriptions/check at once cannot double-charge.
    with _JSON_LOCK:
        subscriptions = get_all_subscriptions()
        today = datetime.now()
        current_month_str = today.strftime("%Y-%m")
        created_transactions = []

        updated = False

        for sub in subscriptions:
            try:
                # Check if already recorded for this month
                last_recorded = sub.get("last_recorded_date")
                if last_recorded and last_recorded.startswith(current_month_str):
                    continue

                # Check if due date has passed or is today
                try:
                    day_of_month = int(sub.get("day_of_month", 1))
                except (ValueError, TypeError):
                    day_of_month = 1

                if today.day >= day_of_month:
                    transaction_date = f"{day_of_month:02d}/{today.month:02d}/{today.year}"

                    tx_data = {
                        "date": transaction_date,
                        "description": f"Subscription: {sub.get('name')}",
                        "amount": sub.get("amount"),
                        "category": sub.get("category", "Bills & Utilities"),
                        "account_id": sub.get("account_id")
                    }

                    create_manual_transaction(tx_data)
                    created_transactions.append(tx_data)

                    # Update subscription
                    sub["last_recorded_date"] = today.strftime("%Y-%m-%d")
                    updated = True
            except Exception as e:
                # One bad subscription record must not break the whole check
                print(f"Skipping subscription {sub.get('id')} ({sub.get('name')}): {e}")
                continue

        if updated:
            save_all_subscriptions(subscriptions)

        return created_transactions

def get_all_accounts():
    try:
        with _JSON_LOCK, open(ACCOUNTS_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_all_accounts(accounts):
    with _JSON_LOCK:
        _write_json_atomic(ACCOUNTS_FILE, accounts)

def save_account(data):
    with _JSON_LOCK:
        accounts = get_all_accounts()

        if "id" not in data or not data["id"]:
            data["id"] = str(uuid.uuid4())
            accounts.append(data)
        else:
            for i, acc in enumerate(accounts):
                if acc["id"] == data["id"]:
                    accounts[i] = data
                    break
            else:
                accounts.append(data)

        save_all_accounts(accounts)
    return data

def delete_account(account_id):
    with _JSON_LOCK:
        accounts = get_all_accounts()
        initial_len = len(accounts)
        accounts = [a for a in accounts if a["id"] != account_id]

        if len(accounts) < initial_len:
            save_all_accounts(accounts)
            return True
    return False

def get_account_balances():
    accounts = get_all_accounts()

    # Initialize balances with initial_balance from account config
    balances = {}
    for acc in accounts:
        try:
            initial = float(acc.get("initial_balance", 0) or 0)
        except (ValueError, TypeError):
            initial = 0.0
        balances[acc["id"]] = int(round(initial * 100))

    # Aggregate in SQL instead of formatting every amount to "RM x.xx"
    # and parsing it straight back (CAST of a malformed amount yields 0)
    conn = get_db_connection()
    rows = conn.execute("""
        SELECT account_id, type, SUM(CAST(amount AS INTEGER)) AS total
        FROM transactions
        WHERE account_id IS NOT NULL
        GROUP BY account_id, type
    """).fetchall()
    conn.close()

    for row in rows:
        acc_id = row["account_id"]
        if acc_id in balances:
            if row["type"] == "income":
                balances[acc_id] += row["total"]
            else:
                balances[acc_id] -= row["total"]

    # Convert back to float for output
    for k in balances:
        balances[k] = balances[k] / 100.0

    return balances
