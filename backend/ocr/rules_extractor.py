"""Extract date, time and amount from OCR text with no model at all.

The extraction model's only real job is deciding *which* characters on the
receipt are the date and the total. On payment screens that decision is nearly
always signposted — a "Date/Time" label, a date and time sharing a row, a
currency symbol — and where it is signposted, code can make the same decision
for 0 MB and 0 ms.

This module exists to measure how far that goes. It is deliberately structured
around signals rather than layouts, because a rule tuned to one app's screen is
worth nothing on the next one:

  * a time is only believed when it shares a row with a date, or sits on a row
    that labels itself as a time — which is what keeps the phone's status-bar
    clock out of the results without any position-based hack
  * a date on a row that labels itself beats a bare date elsewhere, which is
    what keeps a "payment details" field of "22.10.25" from beating the real
    "25/10/2025 23:40:59" two rows below
  * the amount reuses receipt_text.amount_from_text, which already prefers
    total-labelled rows and discards balance-like ones

Input is the tab-joined row text that receipt_text.assemble_text produces, so a
value's label is whatever non-numeric text precedes it on its row.
"""
import re

from .receipt_text import (
    EXCLUDE_LABELS,
    MONEY_RE,
    amount_from_text,
    normalise_date,
    normalise_time,
)

# Numeric dates (20/10/2025, 2025-10-20) and spelled months (5 Sep 2026).
_DATE_RE = re.compile(
    r"\d{1,2}\s*[/\-.]\s*\d{1,2}\s*[/\-.]\s*\d{2,4}"
    r"|\d{4}-\d{2}-\d{2}"
    r"|\d{1,2}\s+[A-Za-z]{3,9}\.?\s+\d{4}",
)
# "10:28AM" with no space is a real format, so the meridiem is optional and
# unspaced.
_TIME_RE = re.compile(r"\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?", re.IGNORECASE)

# Rows whose date or time is not the transaction's. "Printing time" on a thermal
# receipt is seconds after the sale and sits right next to it.
_ROW_EXCLUDE = (
    "printing time", "print time", "printed", "expiry", "expires", "valid until",
    "due date", "statement date",
)

_DATE_LABELS = (
    "date", "tarikh", "日期", "checkout time", "invoice date", "transaction date",
    "date/time", "date & time", "date and time",
)
_TIME_LABELS = (
    "time", "masa", "时间", "date/time", "date & time", "date and time",
    "checkout time", "transaction date",
)


def _rows(ocr_text: str) -> list[str]:
    return [row for row in ocr_text.splitlines() if row.strip()]


def _label_of(row: str) -> str:
    """The non-numeric text on a row — its label side.

    assemble_text joins a row's detections left to right with tabs, and payment
    screens put the field name first, so the cells that carry no value are the
    label for the ones that do.
    """
    cells = [c for c in row.split("\t") if c.strip()]
    parts = [c for c in cells if not (_DATE_RE.search(c) or _TIME_RE.search(c) or MONEY_RE.search(c))]
    return " ".join(parts).lower()


def extract_date_time(ocr_text: str) -> tuple[str | None, str | None]:
    """Pick the transaction date and time out of assembled OCR text."""
    rows = _rows(ocr_text)

    # A narrow column wraps "23/10/2025 19:46:57" onto two rows, leaving the time
    # alone with neither a date nor a label — which the guard below would
    # otherwise discard as a status-bar clock. A bare continuation row inherits
    # the date from the row above it.
    inherits_date = [False] * len(rows)
    for i, row in enumerate(rows[:-1]):
        following = rows[i + 1]
        if (_DATE_RE.search(row)
                and not _TIME_RE.search(row)
                and _TIME_RE.search(following)
                and not _DATE_RE.search(following)
                and not _label_of(following).strip()):
            inherits_date[i + 1] = True

    best_date = best_date_score = None
    best_time = best_time_score = None

    for index, row in enumerate(rows):
        low = row.lower()
        if any(bad in low for bad in _ROW_EXCLUDE):
            continue
        if any(bad in low for bad in EXCLUDE_LABELS):
            # A row about a balance or a reward is not about this transaction.
            continue

        label = _label_of(row)
        dates = [d for d in (normalise_date(m) for m in _DATE_RE.findall(row)) if d]
        times = [t for t in (normalise_time(m) for m in _TIME_RE.findall(row)) if t]

        has_date_label = any(l in label for l in _DATE_LABELS)
        has_time_label = any(l in label for l in _TIME_LABELS)

        for value in dates:
            # A labelled row wins; a row that also carries a time is the classic
            # "20/04/2026 19:16:30" pairing and is nearly as good. Earlier rows
            # break ties, since the transaction summary sits above the fine print.
            score = (2 if has_date_label else 0) + (1 if times else 0) - index * 0.001
            if best_date_score is None or score > best_date_score:
                best_date, best_date_score = value, score

        beside_date = bool(dates) or inherits_date[index]
        for value in times:
            # The decisive rule: a bare time with neither a date beside it nor a
            # time label is almost certainly the phone's status-bar clock.
            if not beside_date and not has_time_label:
                continue
            score = (2 if has_time_label else 0) + (1 if beside_date else 0) - index * 0.001
            if best_time_score is None or score > best_time_score:
                best_time, best_time_score = value, score

    return best_date, best_time


def extract(ocr_text: str, guarded_amount: bool = True) -> dict:
    """Return {'date', 'time', 'amount'} using no model.

    Fields are normalised strings (DD/MM/YYYY, HH:MM:SS, a bare 2dp decimal) or
    None. Formatting into the app's 'RM 12.50' shape is left to the caller, so
    this stays comparable with what the extraction model produces.
    """
    date, time_value = extract_date_time(ocr_text)
    return {
        "date": date,
        "time": time_value,
        "amount": amount_from_text(ocr_text, guarded=guarded_amount),
    }
