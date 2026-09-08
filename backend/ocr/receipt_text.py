"""Turning OCR detections into the three fields the app stores.

Everything here is deterministic Python, deliberately. A 0.5B extraction model is
good at copying a span it can see and bad at reformatting it: benchmarking three
different small models showed each one reading a date correctly and then emitting
it in the wrong format, or doing 12-hour arithmetic wrong. So the model is only
ever asked "which characters are the date", and the parsing, the AM/PM
resolution and the currency handling happen here where they are testable.

See backend/bench/compare_pipelines.py for the measurements behind that split.
"""
import datetime
import re
from decimal import Decimal, InvalidOperation

# Detections below this confidence are dropped before the text is assembled.
MIN_OCR_CONF = 0.5

# Rows are grouped by vertical centre within this fraction of the image height.
ROW_TOLERANCE = 0.01


def assemble_text(lines: list[dict], height: int, tol_frac: float = ROW_TOLERANCE) -> str:
    """Sort OCR detections top-to-bottom and rejoin same-row ones with a tab.

    Receipts are label/value pairs laid out in columns. Feeding the detections in
    raw detector order shreds those pairs apart, and nothing downstream can
    recover the association once it is gone.

    Each element of `lines` is {"text", "conf", "x0", "cy"} with cy/x0 in pixels
    measured from the top-left, which is what every OCR engine here is adapted to
    produce.
    """
    kept = [ln for ln in lines if ln["conf"] >= MIN_OCR_CONF and ln["text"].strip()]
    kept.sort(key=lambda ln: ln["cy"])

    rows: list[dict] = []
    tol = max(tol_frac * height, 1.0)
    for ln in kept:
        if rows and abs(ln["cy"] - rows[-1]["cy"]) <= tol:
            rows[-1]["items"].append(ln)
            rows[-1]["cy"] = sum(i["cy"] for i in rows[-1]["items"]) / len(rows[-1]["items"])
        else:
            rows.append({"cy": ln["cy"], "items": [ln]})

    out = []
    for row in rows:
        row["items"].sort(key=lambda ln: ln["x0"])
        out.append("\t".join(i["text"].strip() for i in row["items"]))
    return "\n".join(out)


# --- Field normalisation -----------------------------------------------------

# Day-first: these are Malaysian receipts, so 05-09-2026 is 5 September. This is
# an ordered list rather than a heuristic on purpose — if the locale ever
# changes, reorder it here instead of guessing per receipt.
_DATE_FORMATS = [
    "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%Y/%m/%d",
    "%d/%m/%y", "%d-%m-%y", "%d %b %Y", "%d %B %Y",
    "%b %d, %Y", "%B %d, %Y", "%d.%m.%Y",
]

# A date more than a day ahead, or implausibly far back, is a misread rather
# than a real transaction. Returning nothing beats storing a wrong year.
_MIN_YEAR = 2000
_FUTURE_TOLERANCE = datetime.timedelta(days=1)


def normalise_date(value, today: datetime.date | None = None) -> str | None:
    """Parse a date span copied off a receipt into DD/MM/YYYY, or None."""
    if not value or not isinstance(value, str):
        return None
    raw = value.strip()
    if not raw:
        return None

    parsed = None
    for fmt in _DATE_FORMATS:
        try:
            parsed = datetime.datetime.strptime(raw, fmt).date()
            break
        except ValueError:
            continue

    if parsed is None:
        # The span often carries more than the date — "05-09-2026 07:35 PM".
        match = re.search(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", raw)
        if match:
            d, m, y = match.groups()
            y = ("20" + y) if len(y) == 2 else y
            try:
                parsed = datetime.date(int(y), int(m), int(d))
            except ValueError:
                return None
        else:
            match = re.search(r"(\d{4})-(\d{2})-(\d{2})", raw)
            if not match:
                return None
            y, m, d = match.groups()
            try:
                parsed = datetime.date(int(y), int(m), int(d))
            except ValueError:
                return None

    today = today or datetime.date.today()
    if parsed.year < _MIN_YEAR or parsed > today + _FUTURE_TOLERANCE:
        return None
    return parsed.strftime("%d/%m/%Y")


def normalise_time(value) -> str | None:
    """Parse a time span into HH:MM:SS, resolving 12-hour spans like '07:35 PM'."""
    if not value or not isinstance(value, str):
        return None
    raw = value.strip().upper()
    match = re.search(r"(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?", raw)
    if not match:
        return None

    hh, mm, ss, meridiem = match.groups()
    hh, mm, ss = int(hh), int(mm), int(ss or 0)
    if meridiem == "PM" and hh != 12:
        hh += 12
    elif meridiem == "AM" and hh == 12:
        hh = 0
    if not (0 <= hh < 24 and 0 <= mm < 60 and 0 <= ss < 60):
        return None
    return f"{hh:02d}:{mm:02d}:{ss:02d}"


# Above this, assume a misread (a reference number caught by the money regex)
# rather than a genuinely enormous receipt.
MAX_AMOUNT = Decimal("100000")


def normalise_amount(value) -> str | None:
    """Strip currency and separators, return a positive 2dp decimal string.

    Decimal, never float: this is money, and it is stored as cents downstream.
    """
    if value is None:
        return None
    raw = re.sub(r"[^\d.,\-]", "", str(value).strip()).lstrip("-")
    if not raw:
        return None

    # Whichever separator comes last is the decimal mark; the other groups digits.
    if "," in raw and "." in raw:
        raw = raw.replace(",", "") if raw.rfind(".") > raw.rfind(",") else raw.replace(".", "").replace(",", ".")
    elif "," in raw:
        raw = raw.replace(",", ".") if len(raw.split(",")[-1]) == 2 else raw.replace(",", "")

    try:
        amount = Decimal(raw)
    except InvalidOperation:
        return None
    if not (0 < amount <= MAX_AMOUNT):
        return None
    return f"{amount:.2f}"


# --- Amount recovery ---------------------------------------------------------
#
# A span-copying model misses a total that carries no "total" label — the
# headline figure on an e-wallet payment screen. Recovering it from the OCR text
# is cheap, but "largest number on the receipt" is a trap: any receipt that also
# prints an account balance, cash tendered, or a credit limit has a larger number
# on it than the amount actually paid. Measured on synthetic layouts, the naive
# rule scored 2/9 and the guarded one below 9/9
# (backend/bench/compare_pipelines.py --probe-amount-fallback).

CURRENCY_RE = r"(?:RM|MYR|SGD|USD|EUR|GBP|\$|€|£)"

# Money looks like 1,234.56 or 12.50 — the two decimals are what keep quantities,
# table numbers, years and reference codes out of the candidate pool.
MONEY_RE = re.compile(r"-?\d{1,3}(?:,\d{3})*\.\d{2}\b|-?\d+\.\d{2}\b")

TOTAL_LABELS = (
    "grand total", "grandtotal", "total accounts receivable", "amount payable",
    "amount paid", "total amount", "nett total", "net total", "total due",
    "total", "jumlah", "amaun", "bayaran",
)

# Lines whose number is emphatically not what the customer paid. This list is
# Malaysian-receipt-shaped; extend it as new formats turn up.
EXCLUDE_LABELS = (
    "balance", "baki", "change", "kembalian", "cash", "tunai", "tendered",
    "available", "credit limit", "points", "point", "mata", "saving", "savings",
    "discount", "diskaun", "rebate", "deposit", "wallet balance", "outstanding",
    "previous", "opening", "closing", "reward",
)


def _money_in(text: str) -> list[Decimal]:
    values = []
    for match in MONEY_RE.findall(text):
        try:
            values.append(abs(Decimal(match.replace(",", ""))))
        except InvalidOperation:
            continue
    return values


def amount_from_text(ocr_text: str, guarded: bool = True) -> str | None:
    """Recover the paid amount from assembled OCR text.

    guarded=False is the plain "largest money value" rule, kept so the
    difference stays measurable. guarded=True prefers a line that labels itself
    a total and, before falling back to a maximum, drops the lines that label
    themselves a balance, change, or anything else that is not the amount paid.
    """
    labelled: list[Decimal] = []
    loose: list[Decimal] = []

    for line in ocr_text.splitlines():
        line_has_currency = re.search(CURRENCY_RE, line, re.IGNORECASE) is not None
        low_line = line.lower()
        # assemble_text joins a row's detections with tabs, left to right, so a
        # value's label is the non-numeric text *before* it. Text after it is a
        # different column: on "-RM10.60 <tab> +10 points" the points are a
        # sibling value, not a description of the amount.
        preceding: list[str] = []

        for cell in (c for c in line.split("\t") if c.strip()):
            values = _money_in(cell)
            if not values:
                preceding.append(cell)
                continue

            if not guarded:
                if line_has_currency or any(l in low_line for l in TOTAL_LABELS):
                    loose.extend(values)
                continue

            context = " ".join(preceding + [cell]).lower()
            is_total = any(label in context for label in TOTAL_LABELS)

            # A bare "186.75" in a column only counts if something names it.
            if not (line_has_currency or is_total):
                continue
            # Exclusion outranks the total label: "Total Savings" says both, and
            # it is emphatically not what the customer paid.
            if any(label in context for label in EXCLUDE_LABELS):
                continue
            (labelled if is_total else loose).extend(values)

    pool = labelled or loose
    if not pool:
        return None
    return normalise_amount(max(pool))


# --- Assembling the app's answer ---------------------------------------------

_CURRENCY_NAMES = {
    "RM": "RM", "MYR": "RM", "$": "$", "USD": "USD", "SGD": "SGD",
    "EUR": "EUR", "€": "EUR", "GBP": "GBP", "£": "GBP",
}
DEFAULT_CURRENCY = "RM"


def _currency_label(value) -> str:
    if isinstance(value, str):
        token = value.strip().upper()
        if token in _CURRENCY_NAMES:
            return _CURRENCY_NAMES[token]
    return DEFAULT_CURRENCY


def build_result(extracted: dict, ocr_text: str, guarded_fallback: bool = True) -> dict:
    """Map a model's raw extraction onto {'date', 'time', 'amount'}.

    Returns the shape the rest of the app already consumes: DD/MM/YYYY,
    HH:MM:SS and an amount string like 'RM 186.75'. A field that cannot be
    parsed comes back as None rather than as a guess — main.extract_data_from_image
    fills a missing date/time with 'now', and the user confirms everything in the
    UI regardless, so a visible gap is strictly better than a wrong number.
    """
    if not isinstance(extracted, dict):
        extracted = {}

    # A span-copier hands back the whole "20/04/2026 13:08:11" run under whichever
    # field matched first and leaves the other empty, so each falls back to the
    # other's span. The regexes cannot cross-match: dates need / - . separators
    # and times need a colon.
    date_span = extracted.get("date")
    time_span = extracted.get("time")
    date = normalise_date(date_span) or normalise_date(time_span)
    time_value = normalise_time(time_span) or normalise_time(date_span)

    amount = normalise_amount(extracted.get("amount") or extracted.get("total_amount"))
    if amount is None:
        # Only when the model found nothing usable. A recovered amount must never
        # overwrite one the model actually read, or this would override correct
        # answers as readily as missing ones.
        amount = amount_from_text(ocr_text, guarded=guarded_fallback)

    result = {"date": date, "time": time_value, "amount": None}
    if amount is not None:
        result["amount"] = f"{_currency_label(extracted.get('currency'))} {amount}"
    return result
