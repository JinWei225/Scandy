#!/usr/bin/env python3
"""Compare receipt-extraction pipelines on memory, storage, speed and accuracy.

The question this answers: the Mac mini has to stay usable for daily work, so how
much RAM does each candidate pipeline hold resident, and what does that cost in
accuracy and latency?

Arms (pick with --arms, default runs the four below):

  vlm-lfm3b             current production: LFM2.5-VL-3B-MLX-4bit, image -> JSON
  vlm-qwen08b           candidate A: Qwen3.5-0.8B-MLX-4bit (VLM), image -> JSON
  ocr-vision+nuextract  candidate B (spec option B), Apple Vision OCR -> NuExtract-1.5-tiny Q4_K_M
  ocr-rapid+nuextract   candidate B, portable: RapidOCR (PP-OCR ONNX) -> same LLM
  ocr-vision+qwen08b    opt-in: Apple Vision OCR -> Qwen3.5-0.8B Q4_K_M as a text model
  ocr-vision+rules      no model at all: Apple Vision OCR -> deterministic Python
  ocr-mlkit+rules       phone OCR (replayed) -> deterministic Python
  ocr-mlkit+nuextract   phone OCR (replayed) -> NuExtract-tiny
  ocr-vision+lfm12b     opt-in: Apple Vision OCR -> LFM2.5-1.2B-Instruct Q4_K_M as a text model

Every arm runs in its own subprocess so nothing shares a warm allocator. The
parent samples phys_footprint (the number Activity Monitor shows) for the worker
and every child it spawns, at 100 ms, and attributes samples to phases the worker
announces, so "resident while idle" is measured separately from "peak while
scanning".

Usage:
    .venv/bin/python backend/bench/compare_pipelines.py
    .venv/bin/python backend/bench/compare_pipelines.py --arms vlm-qwen08b,ocr-vision+nuextract
    .venv/bin/python backend/bench/compare_pipelines.py --repeats 5 --images-dir backend/img

Bench-only dependencies (not needed by the app):
    uv pip install --python .venv psutil pyobjc-framework-Vision rapidocr-onnxruntime
"""
from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import datetime
import json
import os
import re
import shutil
import socket
import statistics
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BENCH_DIR = Path(__file__).resolve().parent

# Seconds to sit still with the model loaded so the idle footprint can be read
# without inference noise. This is the number that decides whether the Mac mini
# stays comfortable, so it gets its own quiet window.
IDLE_SECS = 4.0
SAMPLE_INTERVAL = 0.1

# ---------------------------------------------------------------------------
# Model identifiers
# ---------------------------------------------------------------------------

LFM_VLM_REPO = "LiquidAI/LFM2.5-VL-3B-MLX-4bit"
QWEN_VLM_REPO = "mlx-community/Qwen3.5-0.8B-MLX-4bit"
NUEXTRACT_REPO = "QuantFactory/NuExtract-1.5-tiny-GGUF"
NUEXTRACT_FILE = "NuExtract-1.5-tiny.Q4_K_M.gguf"
QWEN_GGUF_REPO = "unsloth/Qwen3.5-0.8B-GGUF"
QWEN_GGUF_FILE = "Qwen3.5-0.8B-Q4_K_M.gguf"
LFM_TEXT_GGUF_REPO = "unsloth/LFM2.5-1.2B-Instruct-GGUF"
LFM_TEXT_GGUF_FILE = "LFM2.5-1.2B-Instruct-Q4_K_M.gguf"

# Stage 3 of the spec: a JSON template whose empty strings define the schema, and
# a grammar that makes malformed output impossible rather than merely unlikely.
NUEXTRACT_TEMPLATE = (
    '{"date": "", "time": "", "total_amount": "", "currency": "", "merchant": ""}'
)

# NOTE: llama.cpp's GBNF parser wants each rule on one line. The grammar printed
# in scandy-ocr-pipeline-spec.md is wrapped across lines, and llama-server rejects
# it with "failed to parse grammar" — unwrap it if you copy it out of the spec.
JSON_GRAMMAR = (
    'root ::= "{" ws "\\"date\\":" ws string "," ws "\\"time\\":" ws string "," ws '
    '"\\"total_amount\\":" ws string "," ws "\\"currency\\":" ws string "," ws '
    '"\\"merchant\\":" ws string ws "}"\n'
    'string ::= "\\"" [^"]* "\\""\n'
    'ws ::= [ \\t\\n]*\n'
)

# The production prompt lives in backend/ocr/common.py and takes an image. This is
# the same instruction retargeted at OCR text, so the text-model arm is asked for
# exactly the fields the app already consumes.
TEXT_LLM_PROMPT = """You are a silent, automated data extraction tool. Extract data from the receipt text below into JSON.
The current datetime is: {now}. If the text does not say, refer to this current time.
Find the following fields:
1. 'date': The transaction date. Format it strictly as DD/MM/YYYY. If no date is found, return null.
2. 'time': The transaction time. Format it strictly as HH:MM:SS. If no time is found, return null.
3. 'amount': The total paid amount. Format it as a positive value with the currency, like 'RM XX.00'. Always remove any negative signs.

Your response MUST be a raw JSON object and NOTHING ELSE.

### Receipt text:
{text}
"""

QWEN_TEXT_GRAMMAR = (
    'root ::= "{" ws "\\"date\\":" ws string "," ws "\\"time\\":" ws string "," ws '
    '"\\"amount\\":" ws string ws "}"\n'
    'string ::= "\\"" [^"]* "\\""\n'
    'ws ::= [ \\t\\n]*\n'
)


# ---------------------------------------------------------------------------
# Memory sampling (parent side)
# ---------------------------------------------------------------------------

_libproc = ctypes.CDLL(ctypes.util.find_library("proc") or "/usr/lib/libSystem.B.dylib")
_RUSAGE_BUF = 512
# rusage_info_v0: uuid[16] then ten uint64s; ri_phys_footprint is the 8th of those.
_PHYS_FOOTPRINT_INDEX = 7


def phys_footprint(pid: int) -> int:
    """Bytes of physical memory macOS charges to `pid`.

    This is what Activity Monitor calls "Memory" and what the memory pressure
    system actually acts on, which RSS is not: RSS double-counts shared pages and
    misses some of what a Metal-backed process holds.
    """
    buf = (ctypes.c_uint8 * _RUSAGE_BUF)()
    if _libproc.proc_pid_rusage(ctypes.c_int(pid), ctypes.c_int(0), ctypes.byref(buf)) != 0:
        return 0
    return struct.unpack_from("<10Q", bytes(buf), 16)[_PHYS_FOOTPRINT_INDEX]


class TreeSampler(threading.Thread):
    """Samples the footprint of a process and every descendant it spawns.

    The OCR + text-model arms run llama-server as a separate process, so summing
    the tree is the only way to compare them fairly against an in-process VLM.
    """

    def __init__(self, root_pid: int):
        super().__init__(daemon=True)
        self.root_pid = root_pid
        self.samples: list[tuple[float, int, dict[int, int]]] = []
        self._stop = threading.Event()

    def _pids(self) -> list[int]:
        import psutil

        try:
            proc = psutil.Process(self.root_pid)
            return [self.root_pid] + [c.pid for c in proc.children(recursive=True)]
        except Exception:
            return [self.root_pid]

    def run(self) -> None:
        while not self._stop.is_set():
            per_pid = {}
            for pid in self._pids():
                fp = phys_footprint(pid)
                if fp:
                    per_pid[pid] = fp
            if per_pid:
                self.samples.append((time.time(), sum(per_pid.values()), per_pid))
            time.sleep(SAMPLE_INTERVAL)

    def stop(self) -> None:
        self._stop.set()
        self.join(timeout=2)


def window_stats(samples, start: float, end: float) -> dict:
    """max/median footprint in MB over a time window, from the sampled tree."""
    vals = [total for ts, total, _ in samples if start <= ts <= end]
    if not vals:
        return {"peak_mb": None, "median_mb": None, "n": 0}
    return {
        "peak_mb": round(max(vals) / 1e6, 1),
        "median_mb": round(statistics.median(vals) / 1e6, 1),
        "n": len(vals),
    }


# ---------------------------------------------------------------------------
# Normalisation and scoring (spec stage 4)
# ---------------------------------------------------------------------------

_DATE_FORMATS = [
    "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%Y/%m/%d",
    "%d/%m/%y", "%d-%m-%y", "%d %b %Y", "%d %B %Y",
    "%b %d, %Y", "%B %d, %Y", "%d.%m.%Y",
]


def normalise_date(value) -> str | None:
    """Parse a date span copied off a receipt into DD/MM/YYYY.

    Format order matters: `05-09-2026` is day-first here because the receipts are
    Malaysian. Change the order, not a heuristic, if that ever stops being true.
    """
    if not value or not isinstance(value, str):
        return None
    raw = value.strip()
    if not raw:
        return None
    for fmt in _DATE_FORMATS:
        try:
            return datetime.datetime.strptime(raw, fmt).strftime("%d/%m/%Y")
        except ValueError:
            continue
    # Fall back to pulling a date out of a longer span like "05-09-2026 07:35 PM".
    m = re.search(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", raw)
    if m:
        d, mo, y = m.groups()
        y = ("20" + y) if len(y) == 2 else y
        try:
            return datetime.date(int(y), int(mo), int(d)).strftime("%d/%m/%Y")
        except ValueError:
            return None
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", raw)
    if m:
        y, mo, d = m.groups()
        try:
            return datetime.date(int(y), int(mo), int(d)).strftime("%d/%m/%Y")
        except ValueError:
            return None
    return None


def normalise_time(value) -> str | None:
    """Parse a time span into HH:MM:SS, resolving 12-hour spans like '07:35 PM'."""
    if not value or not isinstance(value, str):
        return None
    raw = value.strip().upper()
    if not raw:
        return None
    m = re.search(r"(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?", raw)
    if not m:
        return None
    hh, mm, ss, ampm = m.groups()
    hh, mm, ss = int(hh), int(mm), int(ss or 0)
    if ampm == "PM" and hh != 12:
        hh += 12
    elif ampm == "AM" and hh == 12:
        hh = 0
    if not (0 <= hh < 24 and 0 <= mm < 60 and 0 <= ss < 60):
        return None
    return f"{hh:02d}:{mm:02d}:{ss:02d}"


def normalise_amount(value) -> str | None:
    """Strip currency and separators, return a 2dp decimal string.

    Decimal, not float: this is money, and the comparison against ground truth
    should not turn on a binary rounding artefact.
    """
    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    raw = re.sub(r"[^\d.,\-]", "", raw).lstrip("-")
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
    if amount <= 0:
        return None
    return f"{amount:.2f}"


# --- Amount fallback ---------------------------------------------------------
#
# NuExtract copies spans and does not reason, so it misses a total that carries no
# "total" label — the headline figure on an e-wallet screen. Recovering that in
# code is cheap, but "largest number on the receipt" is a trap: a receipt that
# also prints an account balance, cash tendered, or a credit limit will have a
# larger number than the amount actually paid. So the guarded pass throws those
# lines away first and only then takes a maximum.

CURRENCY_RE = r"(?:RM|MYR|SGD|USD|EUR|GBP|\$|€|£)"
# A money-looking number: optional sign, thousands groups, exactly two decimals.
# Requiring the decimals is what keeps quantities, table numbers and years out.
MONEY_RE = re.compile(r"-?\d{1,3}(?:,\d{3})*\.\d{2}\b|-?\d+\.\d{2}\b")

TOTAL_LABELS = (
    "grand total", "grandtotal", "total accounts receivable", "amount payable",
    "amount paid", "total amount", "nett total", "net total", "total due",
    "total", "jumlah", "amaun", "bayaran",
)
# Lines whose number is emphatically not what the customer paid.
EXCLUDE_LABELS = (
    "balance", "baki", "change", "kembalian", "cash", "tunai", "tendered",
    "available", "credit limit", "points", "point", "mata", "saving", "savings",
    "discount", "diskaun", "rebate", "deposit", "wallet balance", "outstanding",
    "previous", "opening", "closing", "reward",
)


def _money_on_line(line: str) -> list[Decimal]:
    out = []
    for match in MONEY_RE.findall(line):
        try:
            out.append(abs(Decimal(match.replace(",", ""))))
        except InvalidOperation:
            continue
    return out


def amount_from_text(ocr_text: str, guarded: bool = True) -> str | None:
    """Recover the paid amount from assembled OCR text.

    guarded=False is the plain "largest currency-prefixed number" rule.
    guarded=True prefers a line that labels itself as a total, and — when it has
    to fall back to a maximum — first drops lines that label themselves as a
    balance, change, or anything else that is not the amount paid.
    """
    labelled: list[Decimal] = []
    loose: list[Decimal] = []

    for line in ocr_text.splitlines():
        line_has_currency = re.search(CURRENCY_RE, line, re.IGNORECASE) is not None
        # assemble_text joins one row's detections with tabs, left to right, so a
        # value's label is whatever non-numeric text sits before it on the row.
        # Text that comes *after* is a different column: on "-RM10.60  +10 points"
        # the points are a sibling value, not a description of the amount.
        cells = [c for c in line.split("\t") if c.strip()]
        preceding: list[str] = []

        for cell in cells:
            values = _money_on_line(cell)
            if not values:
                preceding.append(cell)
                continue

            if not guarded:
                if line_has_currency or any(l in line.lower() for l in TOTAL_LABELS):
                    loose.extend(values)
                continue

            context = " ".join(preceding + [cell]).lower()
            is_total = any(label in context for label in TOTAL_LABELS)
            is_excluded = any(label in context for label in EXCLUDE_LABELS)

            # A bare "186.75" in a column only counts if something names it.
            if not (line_has_currency or is_total):
                continue
            # Exclusion outranks the total label: "Total Savings" says both, and
            # it is emphatically not what the customer paid.
            if is_excluded:
                continue
            (labelled if is_total else loose).extend(values)

    pool = labelled or loose
    if not pool:
        return None
    best = max(pool)
    return f"{best:.2f}" if best > 0 else None


def normalise_prediction(pred: dict) -> dict:
    """Map either arm's raw JSON onto the app's three fields, normalised.

    Both arms go through this identical path so the accuracy numbers compare the
    pipelines, not two different post-processors.
    """
    if not isinstance(pred, dict):
        return {"date": None, "time": None, "amount": None}

    amount = pred.get("amount")
    if amount in (None, "") and pred.get("total_amount") not in (None, ""):
        amount = pred.get("total_amount")

    # An extraction model that copies spans verbatim will hand back the whole
    # "20/04/2026 19:16:30" run under whichever field it matched first and leave
    # the other empty. Splitting that here is stage-4 work, not something to ask
    # a 0.5B model to get right, so each field falls back to the other's span.
    date_span, time_span = pred.get("date"), pred.get("time")
    date = normalise_date(date_span) or normalise_date(time_span)
    time_value = normalise_time(time_span) or normalise_time(date_span)
    return {"date": date, "time": time_value, "amount": normalise_amount(amount)}


def score(pred: dict, truth: dict) -> dict:
    """Field-level exact match after normalisation."""
    norm = normalise_prediction(pred)
    return {
        field: (norm[field] is not None and norm[field] == truth.get(field))
        for field in ("date", "time", "amount")
    } | {"normalised": norm}


# ---------------------------------------------------------------------------
# OCR (spec stage 2) — geometry-preserving, engine-agnostic output
# ---------------------------------------------------------------------------

MIN_OCR_CONF = 0.5


def assemble_text(lines: list[dict], height: int, tol_frac: float = 0.01) -> str:
    """Sort OCR lines top-to-bottom and rejoin same-row lines with a tab.

    Receipts are label/value pairs laid out in columns. Flattening the detections
    in raw detector order shreds those pairs apart, and no downstream model
    recovers the association once it is gone — hence grouping by vertical centre
    before joining.
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


class AppleVisionOCR:
    """Apple's Vision framework. No model files: the weights ship with macOS."""

    name = "apple-vision"
    disk_bytes = 0
    disk_note = "0 — ships with macOS (macOS-only, no Docker/Linux path)"

    def __init__(self):
        import Quartz  # noqa: F401
        import Vision  # noqa: F401

        self._Vision = Vision
        self._Quartz = Quartz

    def read(self, image_path: str) -> tuple[list[dict], int, int]:
        from Foundation import NSURL

        Vision, Quartz = self._Vision, self._Quartz
        url = NSURL.fileURLWithPath_(image_path)
        src = Quartz.CGImageSourceCreateWithURL(url, None)
        cg = Quartz.CGImageSourceCreateImageAtIndex(src, 0, None)
        width = Quartz.CGImageGetWidth(cg)
        height = Quartz.CGImageGetHeight(cg)

        handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg, None)
        req = Vision.VNRecognizeTextRequest.alloc().init()
        req.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
        req.setUsesLanguageCorrection_(False)
        ok, err = handler.performRequests_error_([req], None)
        if not ok:
            raise RuntimeError(f"Vision OCR failed: {err}")

        lines = []
        for obs in req.results() or []:
            cand = obs.topCandidates_(1)
            if not cand:
                continue
            cand = cand[0]
            box = obs.boundingBox()
            # Vision normalises coordinates with the origin at the bottom-left.
            x0 = box.origin.x * width
            y_top = (1.0 - (box.origin.y + box.size.height)) * height
            lines.append({
                "text": cand.string(),
                "conf": float(cand.confidence()),
                "x0": x0,
                "cy": y_top + (box.size.height * height) / 2.0,
            })
        return lines, width, height


class RapidPPOCR:
    """PP-OCR detection + recognition as ONNX, via rapidocr-onnxruntime.

    The portable option: the same ~15 MB of weights run on Linux in the Docker
    image and, per spec option A, in the browser through onnxruntime-web.
    """

    name = "rapidocr-ppocr"

    def __init__(self):
        from rapidocr_onnxruntime import RapidOCR

        self._engine = RapidOCR()
        self.disk_bytes = self._model_bytes()
        self.disk_note = f"{self.disk_bytes / 1e6:.0f} MB of ONNX weights (portable)"

    @staticmethod
    def _model_bytes() -> int:
        import rapidocr_onnxruntime

        root = Path(rapidocr_onnxruntime.__file__).parent
        return sum(p.stat().st_size for p in root.rglob("*.onnx"))

    def read(self, image_path: str) -> tuple[list[dict], int, int]:
        from PIL import Image

        with Image.open(image_path) as im:
            width, height = im.size
        result, _ = self._engine(image_path)
        lines = []
        for box, text, conf in result or []:
            xs = [p[0] for p in box]
            ys = [p[1] for p in box]
            lines.append({
                "text": text,
                "conf": float(conf),
                "x0": min(xs),
                "cy": (min(ys) + max(ys)) / 2.0,
            })
        return lines, width, height


# ---------------------------------------------------------------------------
# llama.cpp server (spec stage 3)
# ---------------------------------------------------------------------------

def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class LlamaServer:
    """A llama-server process holding one GGUF, with grammar-constrained output.

    Context is deliberately small. KV cache, not weights, is what makes a small
    model expensive to keep resident, and a receipt never needs 2048 tokens.
    """

    def __init__(self, gguf_path: str, ctx: int = 2048):
        self.gguf_path = gguf_path
        self.ctx = ctx
        self.port = free_port()
        self.proc: subprocess.Popen | None = None

    def start(self) -> float:
        binary = shutil.which("llama-server")
        if not binary:
            raise RuntimeError("llama-server not on PATH (brew install llama.cpp)")
        started = time.time()
        self.proc = subprocess.Popen(
            [
                binary, "-m", self.gguf_path,
                "-c", str(self.ctx),
                "-ngl", "99",
                "-np", "1",
                "--port", str(self.port),
                "--no-webui",
                "--log-disable",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = started + 120
        while time.time() < deadline:
            if self.proc.poll() is not None:
                raise RuntimeError(f"llama-server exited with {self.proc.returncode}")
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/health", timeout=1) as r:
                    if r.status == 200:
                        return time.time() - started
            except (urllib.error.URLError, TimeoutError, ConnectionError, OSError):
                time.sleep(0.25)
        raise RuntimeError("llama-server did not become healthy in 120s")

    def _post(self, path: str, body: dict) -> dict:
        req = urllib.request.Request(
            f"http://127.0.0.1:{self.port}{path}",
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.loads(r.read())

    def complete(self, prompt: str, grammar: str, n_predict: int = 200) -> str:
        """Raw completion. Right for NuExtract, which is trained on a bare
        `<|input|> … <|output|>` string and has no chat template at all."""
        return self._post("/completion", {
            "prompt": prompt,
            "grammar": grammar,
            "temperature": 0.0,
            "n_predict": n_predict,
            "cache_prompt": False,
        })["content"]

    def chat(self, prompt: str, grammar: str, n_predict: int = 200) -> str:
        """Chat completion, for instruct models.

        Feeding an instruct model through /completion skips its chat template and
        it answers as if continuing a document — that alone was enough to make the
        Qwen text arm hallucinate dates. Thinking is off: the grammar forces JSON
        from the first token, so a reasoning preamble has nowhere to go.
        """
        return self._post("/v1/chat/completions", {
            "messages": [{"role": "user", "content": prompt}],
            "grammar": grammar,
            "temperature": 0.0,
            "max_tokens": n_predict,
            "chat_template_kwargs": {"enable_thinking": False},
        })["choices"][0]["message"]["content"]

    def stop(self) -> None:
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()


# ---------------------------------------------------------------------------
# Arm implementations (worker side)
# ---------------------------------------------------------------------------

def hf_snapshot_bytes(repo: str) -> int:
    """On-disk size of a cached HF snapshot, following symlinks into blobs."""
    from huggingface_hub import snapshot_download

    path = Path(snapshot_download(repo))
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def hf_file(repo: str, filename: str) -> str:
    from huggingface_hub import hf_hub_download

    return hf_hub_download(repo, filename)


class VLMArm:
    """image -> VLM -> JSON. The shape the app runs today."""

    def __init__(self, repo: str):
        self.repo = repo
        self.model = None
        self.processor = None
        self.config = None

    @staticmethod
    def preimport() -> None:
        import mlx.core  # noqa: F401
        import mlx_vlm  # noqa: F401

    def load(self) -> dict:
        from mlx_vlm import load
        from mlx_vlm.utils import load_config

        self.model, self.processor = load(self.repo, trust_remote_code=True)
        self.config = load_config(self.repo, trust_remote_code=True)
        return {"disk_bytes": hf_snapshot_bytes(self.repo), "disk_note": self.repo}

    def run(self, image_path: str) -> dict:
        from mlx_vlm import generate
        from mlx_vlm.prompt_utils import apply_chat_template

        sys.path.insert(0, str(REPO_ROOT / "backend"))
        from ocr.common import build_system_prompt, parse_model_json

        t0 = time.perf_counter()
        prompt = apply_chat_template(self.processor, self.config, build_system_prompt(), num_images=1)
        out = generate(
            self.model, self.processor, prompt, [image_path],
            verbose=False, max_tokens=200, temperature=0.0,
        )
        total_ms = (time.perf_counter() - t0) * 1000
        return {
            "pred": parse_model_json(out.text),
            "raw": out.text,
            "ocr_ms": 0.0,
            "llm_ms": round(total_ms, 1),
            "total_ms": round(total_ms, 1),
            "ocr_text": None,
        }


class OCRLLMArm:
    """image -> OCR -> text LLM -> JSON. Spec option B."""

    def __init__(self, ocr_cls, gguf_repo: str, gguf_file: str, mode: str):
        self.ocr_cls = ocr_cls
        self.gguf_repo = gguf_repo
        self.gguf_file = gguf_file
        self.mode = mode  # "nuextract" or "chat"
        self.ocr = None
        self.server = None
        self.amount_fallback = "off"  # set by the worker from --amount-fallback

    def preimport(self) -> None:
        if self.ocr_cls is RapidPPOCR:
            import rapidocr_onnxruntime  # noqa: F401
        else:
            import Quartz  # noqa: F401
            import Vision  # noqa: F401

    def load(self) -> dict:
        self.ocr = self.ocr_cls()
        gguf = hf_file(self.gguf_repo, self.gguf_file)
        self.server = LlamaServer(gguf)
        self.server.start()
        llm_bytes = os.path.getsize(gguf)
        return {
            "disk_bytes": llm_bytes + self.ocr.disk_bytes,
            "disk_note": f"{llm_bytes / 1e6:.0f} MB {self.gguf_file} + OCR {self.ocr.disk_note}",
        }

    def _prompt(self, text: str) -> tuple[str, str]:
        if self.mode == "nuextract":
            prompt = (
                "<|input|>\n### Template:\n"
                f"{NUEXTRACT_TEMPLATE}\n### Text:\n{text}\n\n<|output|>\n"
            )
            return prompt, JSON_GRAMMAR
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return TEXT_LLM_PROMPT.format(now=now, text=text), QWEN_TEXT_GRAMMAR

    def run(self, image_path: str) -> dict:
        sys.path.insert(0, str(REPO_ROOT / "backend"))
        from ocr.common import parse_model_json

        t0 = time.perf_counter()
        lines, _width, height = self.ocr.read(image_path)
        text = assemble_text(lines, height)
        t1 = time.perf_counter()
        prompt, grammar = self._prompt(text)
        send = self.server.complete if self.mode == "nuextract" else self.server.chat
        raw = send(prompt, grammar)
        t2 = time.perf_counter()

        pred = parse_model_json(raw)
        used_fallback = False
        if self.amount_fallback != "off":
            model_amount = pred.get("amount") or pred.get("total_amount")
            # Only step in where the model came back with nothing usable. A
            # recovered amount should never overwrite one the model actually read.
            if normalise_amount(model_amount) is None:
                recovered = amount_from_text(text, guarded=self.amount_fallback == "guarded")
                if recovered:
                    pred["amount"] = recovered
                    used_fallback = True

        return {
            "pred": pred,
            "raw": raw,
            "amount_fallback_used": used_fallback,
            "ocr_ms": round((t1 - t0) * 1000, 1),
            "llm_ms": round((t2 - t1) * 1000, 1),
            "total_ms": round((t2 - t0) * 1000, 1),
            "ocr_text": text,
        }

    def teardown(self) -> None:
        if self.server:
            self.server.stop()


class OCRRulesArm:
    """image -> OCR -> deterministic Python -> JSON. No extraction model at all."""

    def __init__(self, ocr_cls):
        self.ocr_cls = ocr_cls
        self.ocr = None

    def preimport(self) -> None:
        if self.ocr_cls is RapidPPOCR:
            import rapidocr_onnxruntime  # noqa: F401
        else:
            import Quartz  # noqa: F401
            import Vision  # noqa: F401

    def load(self) -> dict:
        self.ocr = self.ocr_cls()
        return {"disk_bytes": self.ocr.disk_bytes, "disk_note": f"OCR {self.ocr.disk_note}"}

    def run(self, image_path: str) -> dict:
        sys.path.insert(0, str(REPO_ROOT / "backend"))
        from ocr.rules_extractor import extract

        t0 = time.perf_counter()
        lines, _width, height = self.ocr.read(image_path)
        text = assemble_text(lines, height)
        t1 = time.perf_counter()
        pred = extract(text)
        t2 = time.perf_counter()
        return {
            "pred": pred,
            "raw": json.dumps(pred),
            "ocr_ms": round((t1 - t0) * 1000, 1),
            "llm_ms": round((t2 - t1) * 1000, 1),
            "total_ms": round((t2 - t0) * 1000, 1),
            "ocr_text": text,
        }


class ReplayOCR:
    """Replays OCR detections captured elsewhere — used for the phone's ML Kit.

    Test 1 of the on-device question is "OCR on the phone, extraction on the Mac".
    The OCR half cannot run here, so its detections are imported from the JSON
    that tools/mlkit_ocr_bench writes, and only the extraction half is timed.
    """

    name = "mlkit-replay"
    disk_bytes = 0
    disk_note = "0 on the server — OCR ran on the phone (ML Kit ships with Play Services)"

    json_path: str | None = None
    script: str = "latin"

    def __init__(self):
        if not self.json_path:
            raise RuntimeError("ReplayOCR needs --mlkit-json")
        with open(self.json_path) as handle:
            payload = json.load(handle)
        if self.script not in payload.get("scripts", {}):
            raise RuntimeError(
                f"script '{self.script}' not in {self.json_path}; "
                f"have {list(payload.get('scripts', {}))}"
            )
        self._images = payload["scripts"][self.script]["images"]

    def read(self, image_path: str) -> tuple[list[dict], int, int]:
        name = os.path.basename(image_path)
        entry = self._images.get(name)
        if entry is None or "error" in entry:
            return [], 0, 0
        return entry["lines"], int(entry["width"]), int(entry["height"])


ARMS: dict[str, dict] = {
    "vlm-lfm3b": {
        "label": "VLM  LFM2.5-VL-3B 4bit (current)",
        "build": lambda: VLMArm(LFM_VLM_REPO),
    },
    "vlm-qwen08b": {
        "label": "VLM  Qwen3.5-0.8B 4bit",
        "build": lambda: VLMArm(QWEN_VLM_REPO),
    },
    "ocr-vision+nuextract": {
        "label": "OCR  Apple Vision + NuExtract-tiny Q4",
        "build": lambda: OCRLLMArm(AppleVisionOCR, NUEXTRACT_REPO, NUEXTRACT_FILE, "nuextract"),
    },
    "ocr-rapid+nuextract": {
        "label": "OCR  RapidOCR + NuExtract-tiny Q4",
        "build": lambda: OCRLLMArm(RapidPPOCR, NUEXTRACT_REPO, NUEXTRACT_FILE, "nuextract"),
    },
    "ocr-vision+qwen08b": {
        "label": "OCR  Apple Vision + Qwen3.5-0.8B Q4 (text)",
        "build": lambda: OCRLLMArm(AppleVisionOCR, QWEN_GGUF_REPO, QWEN_GGUF_FILE, "chat"),
    },
    "ocr-vision+rules": {
        "label": "OCR  Apple Vision + rules only (no model)",
        "build": lambda: OCRRulesArm(AppleVisionOCR),
    },
    "ocr-mlkit+rules": {
        "label": "OCR  ML Kit (phone) + rules only (no model)",
        "build": lambda: OCRRulesArm(ReplayOCR),
    },
    "ocr-mlkit+nuextract": {
        "label": "OCR  ML Kit (phone) + NuExtract-tiny Q4",
        "build": lambda: OCRLLMArm(ReplayOCR, NUEXTRACT_REPO, NUEXTRACT_FILE, "nuextract"),
    },
    "ocr-vision+lfm12b": {
        "label": "OCR  Apple Vision + LFM2.5-1.2B Q4 (text)",
        "build": lambda: OCRLLMArm(AppleVisionOCR, LFM_TEXT_GGUF_REPO, LFM_TEXT_GGUF_FILE, "chat"),
    },
}

DEFAULT_ARMS = ["vlm-lfm3b", "vlm-qwen08b", "ocr-vision+nuextract", "ocr-rapid+nuextract"]


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------

def mark(phase_file: str, phase: str) -> None:
    with open(phase_file, "a") as fh:
        fh.write(json.dumps({"ts": time.time(), "phase": phase}) + "\n")
        fh.flush()
        os.fsync(fh.fileno())


def run_worker(arm_name: str, images: list[str], repeats: int, result_file: str,
               phase_file: str, amount_fallback: str = "off",
               mlkit_json: str | None = None, mlkit_script: str = "latin") -> int:
    ReplayOCR.json_path = mlkit_json
    ReplayOCR.script = mlkit_script
    mark(phase_file, "start")
    arm = ARMS[arm_name]["build"]()
    if hasattr(arm, "amount_fallback"):
        arm.amount_fallback = amount_fallback
    arm.preimport()
    # Let the sampler get a few reads of the interpreter-plus-libraries floor
    # before any weights land, so "what the model costs" is separable from "what
    # importing mlx_vlm costs".
    time.sleep(1.5)
    mark(phase_file, "imported")

    result = {"arm": arm_name, "error": None, "runs": [], "ocr_text": {}}
    try:
        t0 = time.perf_counter()
        info = arm.load()
        result["load_s"] = round(time.perf_counter() - t0, 2)
        result.update(info)
        mark(phase_file, "loaded")

        time.sleep(IDLE_SECS)
        mark(phase_file, "idle_after_load")

        # Warm up so the first timed run is not paying for lazy Metal kernel
        # compilation or Vision's first-call model page-in.
        arm.run(images[0])
        mark(phase_file, "warm")

        for rep in range(repeats):
            for image in images:
                out = arm.run(image)
                name = os.path.basename(image)
                result["runs"].append({
                    "image": name, "rep": rep,
                    "pred": out["pred"], "raw": out["raw"],
                    "amount_fallback_used": out.get("amount_fallback_used", False),
                    "ocr_ms": out["ocr_ms"], "llm_ms": out["llm_ms"], "total_ms": out["total_ms"],
                })
                if out["ocr_text"] and name not in result["ocr_text"]:
                    result["ocr_text"][name] = out["ocr_text"]
        mark(phase_file, "inference_done")

        time.sleep(IDLE_SECS)
        mark(phase_file, "idle_after_inference")

        try:
            import mlx.core as mx

            peak = mx.get_peak_memory()
            result["mlx_peak_mb"] = round(peak / 1e6, 1) if peak else None
        except Exception:
            result["mlx_peak_mb"] = None
    except Exception as exc:  # a failed arm should not abort the whole comparison
        import traceback

        result["error"] = f"{type(exc).__name__}: {exc}"
        result["traceback"] = traceback.format_exc()
    finally:
        teardown = getattr(arm, "teardown", None)
        if teardown:
            teardown()
        mark(phase_file, "done")
        Path(result_file).write_text(json.dumps(result))
    return 0 if result["error"] is None else 1


# ---------------------------------------------------------------------------
# Parent
# ---------------------------------------------------------------------------

def prepare_images(images_dir: Path, max_edge: int, workdir: Path) -> list[str]:
    """Downscale once, then feed every arm the identical pixels.

    Spec stage 1 downscales to ~1600px anyway, and doing it here means the arms
    are compared on extraction, not on who happens to resize more cleverly.
    """
    from PIL import Image

    out = []
    # Case-insensitive, and .jpeg counts: globbing only "*.jpg" silently skipped
    # an image and made the scored total quietly smaller than the image count.
    candidates = sorted(
        p for p in images_dir.iterdir()
        if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png"}
    )
    for src in candidates:
        if max_edge <= 0:
            out.append(str(src))
            continue
        dst = workdir / src.name
        with Image.open(src) as im:
            im = im.convert("RGB")
            if max(im.size) > max_edge:
                scale = max_edge / max(im.size)
                im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
            im.save(dst, "JPEG", quality=92)
        out.append(str(dst))
    return out


def run_arm(arm_name: str, images: list[str], repeats: int, workdir: Path,
            amount_fallback: str = "off", mlkit_json: str | None = None,
            mlkit_script: str = "latin") -> dict:
    result_file = workdir / f"{arm_name.replace('/', '_')}.result.json"
    phase_file = workdir / f"{arm_name.replace('/', '_')}.phases.jsonl"
    phase_file.write_text("")

    cmd = [
        sys.executable, str(Path(__file__).resolve()),
        "--_worker", arm_name,
        "--_result", str(result_file),
        "--_phases", str(phase_file),
        "--repeats", str(repeats),
        "--amount-fallback", amount_fallback,
        "--mlkit-script", mlkit_script,
        *(["--mlkit-json", mlkit_json] if mlkit_json else []),
        "--_images", *images,
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sampler = TreeSampler(proc.pid)
    sampler.start()
    stdout, _ = proc.communicate()
    sampler.stop()

    if not result_file.exists():
        return {"arm": arm_name, "error": f"worker produced no result (exit {proc.returncode})", "stdout": stdout[-2000:]}

    result = json.loads(result_file.read_text())
    result["worker_stdout"] = stdout[-2000:]

    phases = [json.loads(line) for line in phase_file.read_text().splitlines() if line.strip()]
    times = {p["phase"]: p["ts"] for p in phases}
    samples = sampler.samples

    def between(a, b):
        if a not in times or b not in times:
            return {"peak_mb": None, "median_mb": None, "n": 0}
        return window_stats(samples, times[a], times[b])

    result["memory"] = {
        "baseline": between("start", "imported"),
        "loading": between("imported", "loaded"),
        "idle_loaded": between("loaded", "idle_after_load"),
        "inference": between("warm", "inference_done"),
        "idle_after": between("inference_done", "idle_after_inference"),
        "overall_peak_mb": round(max((t for _, t, _ in samples), default=0) / 1e6, 1),
    }
    # Which process holds the memory at the peak — useful when llama-server and
    # the Python worker are both in the tree.
    if samples:
        _, _, per_pid = max(samples, key=lambda s: s[1])
        result["memory"]["peak_breakdown_mb"] = {
            str(pid): round(b / 1e6, 1) for pid, b in sorted(per_pid.items(), key=lambda kv: -kv[1])
        }
    return result


def summarise(result: dict, truth: dict) -> dict:
    """Collapse an arm's runs into the numbers the decision actually turns on."""
    runs = result.get("runs", [])
    row = {
        "arm": result["arm"],
        "label": ARMS[result["arm"]]["label"] if result["arm"] in ARMS else result["arm"],
        "error": result.get("error"),
        "load_s": result.get("load_s"),
        "disk_mb": round(result["disk_bytes"] / 1e6, 1) if result.get("disk_bytes") else None,
        "disk_note": result.get("disk_note"),
        "mlx_peak_mb": result.get("mlx_peak_mb"),
    }
    mem = result.get("memory", {})
    row["mem_baseline_mb"] = (mem.get("baseline") or {}).get("median_mb")
    row["mem_after_load_mb"] = (mem.get("idle_loaded") or {}).get("median_mb")
    row["mem_infer_peak_mb"] = (mem.get("inference") or {}).get("peak_mb")
    row["mem_peak_mb"] = mem.get("overall_peak_mb")
    # The steady state that matters is *after* a scan, not straight after load:
    # llama.cpp mmaps its weights, so pages the model has not touched yet are not
    # charged to the process, and the post-load figure flatters it.
    row["mem_idle_mb"] = (mem.get("idle_after") or {}).get("median_mb")

    if runs:
        row["ocr_ms_med"] = round(statistics.median(r["ocr_ms"] for r in runs), 1)
        row["llm_ms_med"] = round(statistics.median(r["llm_ms"] for r in runs), 1)
        row["total_ms_med"] = round(statistics.median(r["total_ms"] for r in runs), 1)
        row["total_ms_max"] = round(max(r["total_ms"] for r in runs), 1)

        fields = {"date": 0, "time": 0, "amount": 0}
        per_image: dict[str, list] = {}
        checked = 0
        for r in runs:
            gt = truth.get(r["image"])
            if not gt:
                continue
            checked += 1
            s = score(r["pred"], gt)
            for f in fields:
                fields[f] += 1 if s[f] else 0
            per_image.setdefault(r["image"], []).append(s)
        row["scored_runs"] = checked
        if checked:
            row["acc"] = {f: round(n / checked, 3) for f, n in fields.items()}
            row["acc"]["all_three"] = round(
                sum(1 for r in runs if truth.get(r["image"]) and all(
                    score(r["pred"], truth[r["image"]])[f] for f in fields)
                ) / checked, 3)
        row["per_image"] = {
            img: {
                "truth": truth.get(img),
                "predicted": [s["normalised"] for s in ss],
                "correct": [{f: s[f] for f in fields} for s in ss],
            }
            for img, ss in per_image.items()
        }
    return row


def render_report(rows: list[dict], results: list[dict], meta: dict) -> str:
    def cell(v, suffix=""):
        return "—" if v is None else f"{v}{suffix}"

    lines = [
        "# Scandy receipt pipeline comparison",
        "",
        f"- Host: {meta['host']}",
        f"- Images: {meta['n_images']} ({', '.join(meta['image_names'])}), long edge capped at {meta['max_edge']}px",
        f"- Repeats: {meta['repeats']} per image (plus one untimed warm-up)",
        f"- Memory: macOS phys_footprint of the worker process and all children, sampled every {int(SAMPLE_INTERVAL * 1000)} ms",
        f"- Generated: {meta['generated']}",
        "",
        "## Headline",
        "",
        "RAM resident idle is the median footprint while sitting loaded after a scan —",
        "the cost of leaving the pipeline up between receipts.",
        "",
        "| Pipeline | RAM resident idle | RAM peak | Disk | Load | Median scan | Date | Time | Amount | All 3 |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        acc = row.get("acc") or {}
        lines.append(
            f"| {row['label']} | {cell(row.get('mem_idle_mb'), ' MB')} | {cell(row.get('mem_peak_mb'), ' MB')} "
            f"| {cell(row.get('disk_mb'), ' MB')} | {cell(row.get('load_s'), ' s')} "
            f"| {cell(row.get('total_ms_med'), ' ms')} "
            f"| {cell(acc.get('date'))} | {cell(acc.get('time'))} | {cell(acc.get('amount'))} | {cell(acc.get('all_three'))} |"
        )

    lines += [
        "", "## Memory detail", "",
        "| Pipeline | Interpreter only | Idle after load | Peak during scan | Idle after scan | MLX peak |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['label']} | {cell(row.get('mem_baseline_mb'), ' MB')} | {cell(row.get('mem_after_load_mb'), ' MB')} "
            f"| {cell(row.get('mem_infer_peak_mb'), ' MB')} | {cell(row.get('mem_idle_mb'), ' MB')} "
            f"| {cell(row.get('mlx_peak_mb'), ' MB')} |"
        )

    lines += ["", "## Timing split", "", "| Pipeline | OCR | LLM | Total (median) | Total (worst) |", "|---|---|---|---|---|"]
    for row in rows:
        lines.append(
            f"| {row['label']} | {cell(row.get('ocr_ms_med'), ' ms')} | {cell(row.get('llm_ms_med'), ' ms')} "
            f"| {cell(row.get('total_ms_med'), ' ms')} | {cell(row.get('total_ms_max'), ' ms')} |"
        )

    lines += ["", "## Storage", "", "| Pipeline | Weights on disk | What that is |", "|---|---|---|"]
    for row in rows:
        lines.append(f"| {row['label']} | {cell(row.get('disk_mb'), ' MB')} | {row.get('disk_note') or '—'} |")

    lines += ["", "## Per-image results", ""]
    for row in rows:
        lines.append(f"### {row['label']}")
        if row.get("error"):
            lines += ["", f"FAILED: `{row['error']}`", ""]
            continue
        for img, detail in (row.get("per_image") or {}).items():
            truth = detail["truth"]
            lines.append(f"- **{img}** truth `{truth['date']} {truth['time']} {truth['amount']}`")
            for pred, ok in zip(detail["predicted"], detail["correct"]):
                flags = "".join("✓" if ok[f] else "✗" for f in ("date", "time", "amount"))
                lines.append(f"  - {flags} `{pred['date']} {pred['time']} {pred['amount']}`")
        lines.append("")

    ocr_dumps = [(r["arm"], r.get("ocr_text") or {}) for r in results if r.get("ocr_text")]
    if ocr_dumps:
        lines += ["## OCR text handed to the extraction model", ""]
        for arm, texts in ocr_dumps:
            for img, text in texts.items():
                lines += [f"<details><summary>{arm} — {img}</summary>", "", "```", text, "```", "", "</details>", ""]
    return "\n".join(lines)


# Synthetic OCR text in the shape assemble_text() produces, for the layouts that
# break a largest-number rule. These are hand-written, not read off real receipts,
# so treat them as a design check on the heuristic — not as accuracy evidence.
FALLBACK_PROBES: list[tuple[str, str, str]] = [
    ("labelled total", "186.75",
     "SUBTOTAL(MYR)\t161.00\nTAX(SST 6%)\t9.66\nGRANDTOTAL(MYR)\t186.75\nCredit Card(MYR)\t186.75"),
    ("headline only, no total label", "10.60",
     "Details\n-RM10.60\t+10 points\nMerchant\tEXAMPLE CAFE SDN BHD\nStatus\tSuccessful"),
    ("wallet balance shown", "6.00",
     "RM 6.00\tPaid\nPayment Method\teWallet Balance\neWallet Balance\tRM 250.00\nDate/Time\t20/04/2026 19:16:30"),
    ("balance dwarfs payment", "12.50",
     "Payment\tRM 12.50\nAvailable Balance\tRM 1,842.30\nStatus\tSuccessful"),
    ("cash and change", "45.60",
     "TOTAL\tRM 45.60\nCASH\tRM 100.00\nCHANGE\tRM 54.40"),
    ("points and savings", "23.90",
     "Total Amount\tRM 23.90\nTotal Savings\tRM 31.20\nPoints Earned\t120.00"),
    ("credit limit on slip", "88.00",
     "AMOUNT\tRM 88.00\nCREDIT LIMIT\tRM 5,000.00\nAPPROVED"),
    ("malay labels", "73.40",
     "JUMLAH\tRM 73.40\nTUNAI\tRM 100.00\nBAKI\tRM 26.60"),
    ("balance, no total label at all", "9.90",
     "RM 9.90\nPaid to EXAMPLE WARUNG\nBaki eWallet\tRM 430.00"),
]


def probe_amount_fallback() -> int:
    """Show what each fallback rule does on layouts a largest-number rule gets wrong."""
    print("Amount fallback on synthetic receipts (naive = largest money value,")
    print("guarded = prefer total-labelled lines, drop balance-like lines)\n")
    header = f"{'case':<32} {'expected':>10} {'naive':>12} {'guarded':>12}"
    print(header)
    print("-" * len(header))

    naive_ok = guarded_ok = 0
    for label, expected, text in FALLBACK_PROBES:
        naive = amount_from_text(text, guarded=False)
        guarded = amount_from_text(text, guarded=True)
        naive_ok += naive == expected
        guarded_ok += guarded == expected
        print(f"{label:<32} {expected:>10} "
              f"{(naive or '—') + ('  ' if naive == expected else ' ✗'):>13} "
              f"{(guarded or '—') + ('  ' if guarded == expected else ' ✗'):>13}")

    total = len(FALLBACK_PROBES)
    print("-" * len(header))
    print(f"{'':<32} {'':>10} {f'{naive_ok}/{total}':>12} {f'{guarded_ok}/{total}':>12}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arms", default=",".join(DEFAULT_ARMS),
                        help=f"comma-separated, or 'all'. Known: {', '.join(ARMS)}")
    parser.add_argument("--images-dir", default=str(REPO_ROOT / "backend" / "img"))
    parser.add_argument("--ground-truth", default=str(BENCH_DIR / "ground_truth.json"),
                        help="labels for the images; copy ground_truth.example.json "
                             "to ground_truth.json and fill it in (it stays untracked, since it\ndescribes real receipts)".replace("\n", ""))
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--max-edge", type=int, default=1600, help="downscale long edge; 0 keeps originals")
    parser.add_argument("--amount-fallback", choices=("off", "naive", "guarded"), default="off",
                        help="recover the amount from OCR text when the model returns none "
                             "(OCR arms only): 'naive' takes the largest money value, "
                             "'guarded' prefers total-labelled lines and skips balance-like ones")
    parser.add_argument("--mlkit-json", default=None,
                        help="OCR detections captured by tools/mlkit_ocr_bench, for the "
                             "ocr-mlkit+* arms")
    parser.add_argument("--mlkit-script", default="latin", choices=("latin", "chinese"),
                        help="which ML Kit script model's detections to replay")
    parser.add_argument("--probe-amount-fallback", action="store_true",
                        help="run the fallback against synthetic receipts (including ones with an "
                             "account balance) and exit — no models loaded")
    parser.add_argument("--out", default=str(BENCH_DIR / "results"))
    parser.add_argument("--_worker", dest="worker")
    parser.add_argument("--_result", dest="result_file")
    parser.add_argument("--_phases", dest="phase_file")
    parser.add_argument("--_images", dest="images", nargs="*")
    args = parser.parse_args()

    if args.probe_amount_fallback:
        return probe_amount_fallback()

    if args.worker:
        return run_worker(args.worker, args.images, args.repeats, args.result_file,
                          args.phase_file, args.amount_fallback,
                          args.mlkit_json, args.mlkit_script)

    arm_names = list(ARMS) if args.arms == "all" else [a.strip() for a in args.arms.split(",") if a.strip()]
    unknown = [a for a in arm_names if a not in ARMS]
    if unknown:
        parser.error(f"unknown arm(s): {', '.join(unknown)}. Known: {', '.join(ARMS)}")

    truth = json.loads(Path(args.ground_truth).read_text())
    truth = {k: v for k, v in truth.items()}

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="scandy-bench-") as tmp:
        workdir = Path(tmp)
        images = prepare_images(Path(args.images_dir), args.max_edge, workdir)
        if not images:
            print(f"No images found in {args.images_dir}", file=sys.stderr)
            return 1
        print(f"{len(images)} image(s): {', '.join(os.path.basename(i) for i in images)}")
        missing = [os.path.basename(i) for i in images if os.path.basename(i) not in truth]
        if missing:
            print(f"warning: no ground truth for {', '.join(missing)} — they run but are not scored")

        results = []
        for name in arm_names:
            print(f"\n=== {name} — {ARMS[name]['label']} ===", flush=True)
            started = time.time()
            result = run_arm(name, images, args.repeats, workdir, args.amount_fallback,
                             args.mlkit_json, args.mlkit_script)
            results.append(result)
            if result.get("error"):
                print(f"  FAILED: {result['error']}")
            else:
                mem = result["memory"]
                print(f"  idle {mem['idle_after']['median_mb']} MB, peak {mem['overall_peak_mb']} MB, "
                      f"load {result['load_s']} s, {len(result['runs'])} timed runs "
                      f"in {time.time() - started:.0f} s")

    rows = [summarise(r, truth) for r in results]
    meta = {
        "host": subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                               capture_output=True, text=True).stdout.strip() or "unknown",
        "n_images": len(images),
        "image_names": [os.path.basename(i) for i in images],
        "max_edge": args.max_edge,
        "repeats": args.repeats,
        "generated": datetime.datetime.now().isoformat(timespec="seconds"),
    }

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    (out_dir / f"raw-{stamp}.json").write_text(json.dumps({"meta": meta, "results": results, "rows": rows}, indent=2))
    report = render_report(rows, results, meta)
    report_path = out_dir / f"report-{stamp}.md"
    report_path.write_text(report)

    print("\n" + report.split("## Per-image results")[0])
    print(f"Full report: {report_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
