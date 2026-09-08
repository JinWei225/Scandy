"""Apple Vision OCR + a small extraction model, run locally on macOS.

This replaces the MLX-VLM backend. Same job, roughly a sixth of the memory:

    LFM2.5-VL-3B 4bit (was)   3196 MB resident idle,  5197 MB peak,  8.5 s/scan
    Vision + NuExtract (now)   495 MB resident idle,   592 MB peak,  0.6 s/scan

The reason the small pipeline can match a 3B VLM is the division of labour. Text
recognition goes to Apple's Vision framework, which ships with macOS, costs no
disk and no resident memory of its own, and reads a blurry thermal receipt
better than either OCR model benchmarked against it. The 0.5B model then only
has to say *which characters* are the date and the total — it is never asked to
reformat anything, because at that size it gets reformatting wrong. Parsing
happens in receipt_text.py.

Numbers and method: backend/bench/compare_pipelines.py.

macOS only, like the MLX backend it replaces; Docker and Linux use the Ollama
backend. The pyobjc and llama.cpp imports live inside this module so importing
the app elsewhere does not fail — see ocr/__init__.py.
"""
import atexit
import json
import os
import shutil
import socket
import subprocess
import threading
import time
import urllib.error
import urllib.request

from PIL import Image

from .common import OCR_LOCK, OCRBusyError, OCRUnavailableError
from .receipt_text import assemble_text, build_result

# --- Configuration -----------------------------------------------------------
# Plain constants, edited here rather than read from the environment. Everything
# below is a deliberate choice backed by the benchmark, so it should change by
# editing this file and re-reading the comment that says why.

# The extraction model: 0.5B, Q4, ~491 MB on disk. Downloaded once on first scan
# and cached in ~/.cache/huggingface.
LLM_REPO = "QuantFactory/NuExtract-1.5-tiny-GGUF"
LLM_FILE = "NuExtract-1.5-tiny.Q4_K_M.gguf"

# Set to a .gguf path to use a local file and skip the download entirely.
LLM_GGUF_PATH: str | None = None

# Set to e.g. "http://127.0.0.1:8080" to reuse a llama-server you already run,
# instead of letting Scandy start and own one.
LLM_SERVER_URL: str | None = None

# KV cache, not weights, is what makes a small model expensive to keep resident.
# A receipt never needs 2048 tokens.
LLM_CONTEXT_TOKENS = 2048

# Vision reads a receipt fine at this size, and it bounds the work a 12 MP phone
# photo can create.
MAX_IMAGE_EDGE = 1600

# BCP-47 tags for Vision's recogniser. English alone was what the benchmark
# measured, and it still read the Chinese-language receipt's dates and totals
# correctly. Add "zh-Hans" if you want Chinese item names transcribed too.
OCR_LANGUAGES = ["en-US"]

# How to recover an amount the model did not find. "guarded" prefers
# total-labelled lines and skips balance-like ones (9/9 on the synthetic
# layouts); "naive" takes the largest money value (2/9 — it picks the account
# balance); "off" disables recovery. See receipt_text.amount_from_text.
AMOUNT_FALLBACK = "guarded"

_STARTUP_TIMEOUT = 180
_REQUEST_TIMEOUT = 120

# NuExtract takes input text plus a JSON template whose empty strings define the
# schema. It fills them with spans copied from the text — no instructions, no
# formatting rules, nothing it can get creatively wrong.
_TEMPLATE = '{"date": "", "time": "", "total_amount": "", "currency": "", "merchant": ""}'

# Constrained decoding, so malformed output is impossible rather than merely
# unlikely. NOTE: llama.cpp's GBNF parser requires each rule on a single line —
# a rule wrapped across lines is rejected with "failed to parse grammar".
_GRAMMAR = (
    'root ::= "{" ws "\\"date\\":" ws string "," ws "\\"time\\":" ws string "," ws '
    '"\\"total_amount\\":" ws string "," ws "\\"currency\\":" ws string "," ws '
    '"\\"merchant\\":" ws string ws "}"\n'
    'string ::= "\\"" [^"]* "\\""\n'
    'ws ::= [ \\t\\n]*\n'
)


# --- Apple Vision ------------------------------------------------------------

def _recognise_text(image_path: str) -> tuple[list[dict], int]:
    """Run Vision's text recogniser. Returns (detections, image height)."""
    try:
        import Quartz
        import Vision
        from Foundation import NSURL
    except ImportError as exc:
        raise OCRUnavailableError(
            "The Apple Vision bindings are not installed. Run: uv sync"
        ) from exc

    url = NSURL.fileURLWithPath_(image_path)
    source = Quartz.CGImageSourceCreateWithURL(url, None)
    if source is None:
        raise OCRUnavailableError(f"Could not read the image at {image_path}")
    cg_image = Quartz.CGImageSourceCreateImageAtIndex(source, 0, None)
    if cg_image is None:
        raise OCRUnavailableError("The uploaded file is not a readable image.")

    width = Quartz.CGImageGetWidth(cg_image)
    height = Quartz.CGImageGetHeight(cg_image)

    handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    # Language correction "fixes" receipt tokens into dictionary words, which is
    # exactly wrong for reference numbers and merchant names.
    request.setUsesLanguageCorrection_(False)
    if OCR_LANGUAGES:
        request.setRecognitionLanguages_(OCR_LANGUAGES)

    ok, error = handler.performRequests_error_([request], None)
    if not ok:
        raise OCRUnavailableError(f"Apple Vision failed to read the image: {error}")

    detections = []
    for observation in request.results() or []:
        candidates = observation.topCandidates_(1)
        if not candidates:
            continue
        candidate = candidates[0]
        box = observation.boundingBox()
        # Vision normalises coordinates with the origin at the bottom-left;
        # assemble_text wants pixels from the top-left.
        top = (1.0 - (box.origin.y + box.size.height)) * height
        detections.append({
            "text": candidate.string(),
            "conf": float(candidate.confidence()),
            "x0": box.origin.x * width,
            "cy": top + (box.size.height * height) / 2.0,
        })
    return detections, height


def _downscale(image_path: str) -> str:
    """Cap the longest edge, returning a path to use for OCR.

    Returns the original path when no resize is needed, so the common case of an
    already-small upload costs nothing.
    """
    try:
        with Image.open(image_path) as img:
            if max(img.size) <= MAX_IMAGE_EDGE:
                return image_path
            scale = MAX_IMAGE_EDGE / max(img.size)
            resized = img.convert("RGB").resize(
                (max(1, round(img.width * scale)), max(1, round(img.height * scale))),
                Image.LANCZOS,
            )
            target = f"{os.path.splitext(image_path)[0]}.ocr.jpg"
            resized.save(target, "JPEG", quality=92)
            return target
    except OSError:
        # An unusual-but-valid format is still worth handing to Vision.
        return image_path


# --- llama.cpp server --------------------------------------------------------

_SERVER_LOCK = threading.Lock()
_SERVER: subprocess.Popen | None = None
_SERVER_URL: str | None = None


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def _model_path() -> str:
    if LLM_GGUF_PATH:
        if not os.path.exists(LLM_GGUF_PATH):
            raise OCRUnavailableError(
                f"LLM_GGUF_PATH points at a missing file: {LLM_GGUF_PATH}"
            )
        return LLM_GGUF_PATH
    try:
        from huggingface_hub import hf_hub_download
    except ImportError as exc:
        raise OCRUnavailableError("huggingface_hub is not installed. Run: uv sync") from exc
    try:
        return hf_hub_download(LLM_REPO, LLM_FILE)
    except Exception as exc:
        raise OCRUnavailableError(
            f"Could not download {LLM_FILE} from {LLM_REPO}: {exc}. "
            "Check your network, or set LLM_GGUF_PATH to a local .gguf file."
        ) from exc


def _healthy(url: str, timeout: float = 1.0) -> bool:
    try:
        with urllib.request.urlopen(f"{url}/health", timeout=timeout) as response:
            return response.status == 200
    except (urllib.error.URLError, TimeoutError, ConnectionError, OSError):
        return False


def _ensure_server() -> str:
    """Return the base URL of a healthy llama-server, starting one if needed.

    Started lazily, then kept alive: loading costs about a second, and the
    process only holds ~490 MB, which was the whole point of the change.
    """
    global _SERVER, _SERVER_URL

    if LLM_SERVER_URL:
        if not _healthy(LLM_SERVER_URL, timeout=3):
            raise OCRUnavailableError(
                f"No llama-server answering at {LLM_SERVER_URL} (LLM_SERVER_URL). "
                "Start it, or set LLM_SERVER_URL back to None to let Scandy run its own."
            )
        return LLM_SERVER_URL

    with _SERVER_LOCK:
        if _SERVER is not None and _SERVER.poll() is None and _SERVER_URL:
            return _SERVER_URL

        binary = shutil.which("llama-server")
        if not binary:
            raise OCRUnavailableError(
                "llama-server is not on PATH. Install it with: brew install llama.cpp"
            )

        model = _model_path()
        port = _free_port()
        url = f"http://127.0.0.1:{port}"
        print(f"Starting llama-server on port {port} with {os.path.basename(model)}...")

        process = subprocess.Popen(
            [
                binary, "-m", model,
                "-c", str(LLM_CONTEXT_TOKENS),
                "-ngl", "99",
                "-np", "1",
                "--port", str(port),
                "--no-webui",
                "--log-disable",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

        deadline = time.time() + _STARTUP_TIMEOUT
        while time.time() < deadline:
            if process.poll() is not None:
                detail = (process.stderr.read() or b"").decode("utf-8", "replace")[-500:]
                raise OCRUnavailableError(
                    f"llama-server exited with code {process.returncode}. {detail}"
                )
            if _healthy(url):
                _SERVER, _SERVER_URL = process, url
                _write_pid_file(process.pid)
                print("Extraction model ready.")
                return url
            time.sleep(0.25)

        process.terminate()
        raise OCRUnavailableError(
            f"llama-server did not become ready within {_STARTUP_TIMEOUT}s."
        )


# stop.sh reads this to reap a llama-server orphaned by a SIGKILL. Without it an
# abandoned process keeps ~490 MB resident and the next start just spawns another
# alongside it, which is precisely the memory problem this backend exists to fix.
PID_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "llama-server.pid")


def _write_pid_file(pid: int) -> None:
    try:
        with open(PID_FILE, "w") as handle:
            handle.write(str(pid))
    except OSError as exc:
        print(f"Warning: could not write {PID_FILE}: {exc}")


def shutdown() -> None:
    """Stop the extraction model. Safe to call more than once.

    Called from atexit and from run_waitress.py's signal handlers — atexit alone
    is not enough, because Python's default SIGTERM handling exits without
    running it, and SIGTERM is exactly how stop.sh stops the server.
    """
    global _SERVER, _SERVER_URL

    if _SERVER is not None and _SERVER.poll() is None:
        _SERVER.terminate()
        try:
            _SERVER.wait(timeout=10)
        except subprocess.TimeoutExpired:
            _SERVER.kill()
    _SERVER, _SERVER_URL = None, None

    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass
    except OSError:
        pass


atexit.register(shutdown)


def _extract_fields(url: str, receipt_text: str) -> dict:
    """Ask the model which spans are the date, time and total."""
    prompt = (
        "<|input|>\n### Template:\n"
        f"{_TEMPLATE}\n### Text:\n{receipt_text}\n\n<|output|>\n"
    )
    payload = json.dumps({
        "prompt": prompt,
        "grammar": _GRAMMAR,
        "temperature": 0.0,
        "n_predict": 200,
        "cache_prompt": False,
    }).encode("utf-8")

    request = urllib.request.Request(
        f"{url}/completion",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=_REQUEST_TIMEOUT) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise OCRUnavailableError(f"Extraction model returned HTTP {exc.code}: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise OCRUnavailableError(f"Lost contact with the extraction model: {exc}") from exc

    content = body.get("content", "")
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        # The grammar makes this near-impossible, but a truncated response at the
        # token limit would land here. The amount fallback still has a chance.
        print(f"Warning: extraction model returned invalid JSON: {content!r}")
        return {}


# --- Public entry point ------------------------------------------------------

def extract_receipt_data(image_path: str) -> dict:
    """Extract date, time and amount from a receipt image.

    Returns {'date': '25/10/2025', 'time': '10:23:54', 'amount': 'RM 12.50'},
    with None for any field that could not be read.

    Raises OCRBusyError instead of queueing when a scan is already running —
    waiting would silently tie up a second server thread for the whole scan.
    """
    if not OCR_LOCK.acquire(timeout=0.5):
        raise OCRBusyError("Another scan is in progress. Please try again shortly.")

    scaled_path = None
    try:
        # Start the model before doing OCR work: on a first run this downloads
        # the weights, and failing then costs nothing.
        url = _ensure_server()

        scaled_path = _downscale(image_path)
        detections, height = _recognise_text(scaled_path)
        receipt_text = assemble_text(detections, height)

        if not receipt_text.strip():
            return {"date": None, "time": None, "amount": None}

        extracted = _extract_fields(url, receipt_text)
        # Passing no text is how recovery is disabled: build_result only reaches
        # for the fallback when the model gave it nothing usable anyway.
        fallback_text = "" if AMOUNT_FALLBACK == "off" else receipt_text
        return build_result(
            extracted, fallback_text, guarded_fallback=AMOUNT_FALLBACK != "naive"
        )
    finally:
        if scaled_path and scaled_path != image_path and os.path.exists(scaled_path):
            os.remove(scaled_path)
        OCR_LOCK.release()
