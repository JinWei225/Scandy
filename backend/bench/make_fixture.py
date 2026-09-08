#!/usr/bin/env python3
"""Build the shared rules fixture: OCR text in, expected fields out.

frontend_flutter/test/fixtures/receipt_cases.json is the contract between the
Python rules in backend/ocr/rules_extractor.py and the Dart port that runs
on-device. Both are checked against the identical cases, so the two
implementations cannot drift apart without a test going red.

Identity is scrubbed so the file is safe to commit: merchant and person names
are replaced, and reference and account numbers become synthetic strings of the
same length — they matter to the rules only as noise, and same-length noise is
the same test. Dates, times, amounts, field labels and row layout are the real
captured output, because those are what the rules actually read.

    .venv/bin/python backend/bench/make_fixture.py            regenerate
    .venv/bin/python backend/bench/make_fixture.py --check    verify Python still passes

Inputs are whatever the benchmark last captured, so re-run it after adding
receipts:
  * Apple Vision over backend/test_img  (from backend/bench/results/raw-*.json)
  * ML Kit over the same images         (backend/bench/mlkit/mlkit_ocr.json)
  * Apple Vision over backend/img       (recognised fresh)
"""
import glob
import hashlib
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "backend"))

from ocr.receipt_text import assemble_text  # noqa: E402

OUT_PATH = REPO_ROOT / "frontend_flutter" / "test" / "fixtures" / "receipt_cases.json"

# Replacements are applied longest-first, so a full name is consumed before any
# of its prefixes. The short prefixes exist because OCR wraps a long merchant
# name across two rows, leaving half of it on its own.
NAMES = {
    "SEAN HOMEMADE": "ACME BAKERY",
    "SEANHOMEMADE": "ACMEBAKERY",
    "XM FOOD ENTERPRISE": "EXAMPLE FOODS",
    "XMFOODENTERPRISE": "EXAMPLEFOODS",
    "XM FOOD": "EXAMPLE FOODS",
    "KULIM ROAD BEST CENDOL": "EXAMPLE DESSERTS",
    "KULIMROADBESTCENDOL": "EXAMPLEDESSERTS",
    "KULIM ROAD BEST": "EXAMPLE DESSERTS",
    "SUPERMOM SDN BHD": "EXAMPLE MART SDN BHD",
    "SUPERMOM": "EXAMPLE MART",
    "F2F NOODLE HOUSE SEPANG": "EXAMPLE NOODLE HOUSE",
    "F2F NOODLE HOUSE": "EXAMPLE NOODLE HOUSE",
    "MEGA FLOUR S/B ACC 4": "EXAMPLE SUPPLIES ACC 4",
    "MEGA FLOUR S/B": "EXAMPLE SUPPLIES",
    "MEGA FLOUR": "EXAMPLE SUPPLIES",
    "Rocca Bay Cafe & Waterfront": "Example Bay Cafe",
    "Rocca Bay Cafe": "Example Bay Cafe",
    "YONNY": "EXAMPLECO",
    "WOO TE": "EX TE",
    "WOo TE": "EX TE",
    "ANG JIN WEI": "SAMPLE PAYER",
    "JULIET YEOH SUET LIN": "SAMPLE PAYEE ONE",
    "JULIET YEOH SUET": "SAMPLE PAYEE ONE",
    "KEE HOOI SIANG": "SAMPLE PAYEE TWO",
    "ONG YONG WILLY": "SAMPLE PAYEE THREE",
    "Sywong": "Sample",
    "Janice": "Sample",
    "Mantou": "Item",
    # Notification banners wrap a merchant name, leaving half of it on a row.
    "HOMEMADE": "BAKERY",
    "SEAN": "ACME",
    "BIGPOS-T587": "TERMINAL-0001",
    "BIGPOS": "TERMINAL",
}

# Nothing matching these may survive scrubbing. Checked on every regeneration so
# that adding receipts cannot quietly reintroduce a real name or reference.
FORBIDDEN = re.compile(
    r"SEAN|HOMEMADE|XM ?FOOD|KULIM|SUPERMOM|ROCCA|YONNY|ANG ?JIN|JULIET|KEE ?HOOI"
    r"|ONG ?YONG|SYWONG|JANICE|F2F|MEGA ?FLOUR|MANTOU|WOO? ?TE|TNGOW|TNGDMY|OQR"
    r"|PBBEMY|UOVBMY|HLBBMY|BIGPOS",
    re.IGNORECASE,
)

# Long alphanumeric runs are references, wallet ids and account numbers. The
# lookarounds keep dates, times and money out of it — those carry separators.
REF_RE = re.compile(r"(?<![\d./:-])[A-Za-z0-9]{8,}(?![\d./:-])")


def scrub(text: str) -> str:
    for real in sorted(NAMES, key=len, reverse=True):
        text = text.replace(real, NAMES[real])

    def synthetic(match: re.Match) -> str:
        token = match.group(0)
        seed = int(hashlib.sha1(token.encode()).hexdigest(), 16)
        return "".join(str((seed >> (3 * i)) % 10) for i in range(len(token)))

    return REF_RE.sub(synthetic, text)


def check() -> int:
    """Assert the Python rules still pass the committed fixture.

    The Dart side is covered by frontend_flutter/test/receipt_rules_test.dart;
    this is the same guard for the original, so neither implementation can drift
    without something failing.
    """
    from ocr.rules_extractor import extract

    if not OUT_PATH.exists():
        print(f"{OUT_PATH} does not exist — run without --check first.")
        return 1
    cases = json.loads(OUT_PATH.read_text())["cases"]
    failures = [
        (c["id"], extract(c["ocr_text"]), c["expected"])
        for c in cases
        if extract(c["ocr_text"]) != c["expected"]
    ]
    print(f"{len(cases) - len(failures)}/{len(cases)} cases pass")
    for case_id, got, want in failures:
        print(f"  FAIL {case_id}\n    got  {got}\n    want {want}")
    return 1 if failures else 0


def main() -> int:
    if "--check" in sys.argv:
        return check()

    cases = []

    def add(engine: str, name: str, text: str, truth: dict) -> None:
        cases.append({
            "id": f"{engine}/{name}",
            "engine": engine,
            "ocr_text": scrub(text),
            "expected": {k: truth[k] for k in ("date", "time", "amount")},
        })

    bench = REPO_ROOT / "backend" / "bench"
    screens = json.loads((bench / "ground_truth_screens.json").read_text())

    # Apple Vision over the screenshots, from the newest run that covers them.
    for path in sorted(glob.glob(str(bench / "results" / "raw-*.json")), reverse=True):
        raw = json.loads(Path(path).read_text())
        arm = next((r for r in raw["results"]
                    if r["arm"] == "ocr-vision+nuextract"
                    and set(r.get("ocr_text", {})) & set(screens)), None)
        if arm:
            for name, text in arm["ocr_text"].items():
                if name in screens:
                    add("vision", name, text, screens[name])
            break
    else:
        print("warning: no benchmark run with Apple Vision text over the screenshots")

    # ML Kit over the same images, captured on the phone.
    mlkit_path = bench / "mlkit" / "mlkit_ocr.json"
    if mlkit_path.exists():
        images = json.loads(mlkit_path.read_text())["scripts"]["latin"]["images"]
        for name, entry in images.items():
            if name in screens and "lines" in entry:
                add("mlkit", name, assemble_text(entry["lines"], int(entry["height"])),
                    screens[name])
    else:
        print(f"warning: {mlkit_path} missing — no ML Kit cases")

    # Apple Vision over the physical receipts, recognised fresh.
    from ocr.vision_backend import _downscale, _recognise_text

    receipts = json.loads((bench / "ground_truth.json").read_text())
    for name, truth in receipts.items():
        image = REPO_ROOT / "backend" / "img" / name
        if not image.exists():
            continue
        detections, height = _recognise_text(_downscale(str(image)))
        add("vision-receipt", name, assemble_text(detections, height), truth)

    payload = {
        "_comment": [
            "Shared cases for the receipt-extraction rules. Used by the Dart port in",
            "frontend_flutter/lib/services/receipt_rules.dart and by the Python",
            "original in backend/ocr/rules_extractor.py, so the two cannot drift.",
            "Regenerate with: .venv/bin/python backend/bench/make_fixture.py",
            "Identity is scrubbed; see that script for exactly what is replaced.",
        ],
        "cases": cases,
    }
    leaks = sorted({
        FORBIDDEN.search(row).group(0)
        for case in cases
        for row in case["ocr_text"].splitlines()
        if FORBIDDEN.search(row)
    })
    if leaks:
        print("REFUSING TO WRITE — identity survived scrubbing: " + ", ".join(leaks))
        print("Add the missing form(s) to NAMES and re-run.")
        return 1

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(payload, indent=1, ensure_ascii=False))

    from collections import Counter

    print(f"wrote {len(cases)} cases to {OUT_PATH.relative_to(REPO_ROOT)}")
    print(dict(Counter(c["engine"] for c in cases)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
