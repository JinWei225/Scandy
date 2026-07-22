"""Ollama backend — talks to an Ollama server over HTTP.

This is what the Docker stack uses, since MLX needs Metal and cannot run inside a
Linux container. Works on any platform, CPU or GPU, at the cost of some speed.

Deliberately uses stdlib urllib rather than requests: the native Apple Silicon
install should not gain a dependency just because a Docker option exists.
"""
import base64
import io
import json
import os
import urllib.error
import urllib.request

from PIL import Image

from .common import (
    OCR_LOCK,
    OCRBusyError,
    OCRUnavailableError,
    build_system_prompt,
    parse_model_json,
)

_OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
_OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3.5:0.8b")

# A vision model spends context on the image itself, and Ollama's 4096 default is
# not enough for a full-size receipt photo (a 3 MP image alone is ~4100 tokens).
_NUM_CTX = int(os.environ.get("OLLAMA_NUM_CTX", "8192"))

# Cap the longest edge before sending. Token cost scales with image area, so an
# unbounded phone photo would overflow any context we pick; receipts stay legible
# well below this. Keeps requests predictable regardless of the source camera.
_MAX_IMAGE_EDGE = int(os.environ.get("OLLAMA_MAX_IMAGE_EDGE", "1280"))

# Generous: a first request on CPU also pays for loading the model into memory.
# Matches the proxy_read_timeout in the nginx config so the browser is not cut off first.
_TIMEOUT_SECONDS = 300


def _normalize_fields(data: dict) -> dict:
    """Coerces the extracted fields to the string shapes the rest of the app expects.
    Models answer the 'amount' with a bare number often enough to matter, and
    main._clean_extracted_data() calls .replace() on it — a float there is an
    AttributeError, i.e. a failed scan for what was actually a correct reading."""
    if not isinstance(data, dict):
        return data

    amount = data.get("amount")
    if isinstance(amount, (int, float)) and not isinstance(amount, bool):
        data["amount"] = f"RM {amount:.2f}"

    for key in ("date", "time"):
        value = data.get(key)
        if value is not None and not isinstance(value, str):
            data[key] = str(value)

    return data


def _prepare_image(image_path: str) -> bytes:
    """Returns JPEG bytes with the longest edge capped at _MAX_IMAGE_EDGE.
    Falls back to the original file if the image cannot be decoded, so an
    unusual-but-valid format is still worth a try rather than an instant failure."""
    try:
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            longest = max(img.size)
            if longest > _MAX_IMAGE_EDGE:
                scale = _MAX_IMAGE_EDGE / longest
                img = img.resize(
                    (max(1, round(img.width * scale)), max(1, round(img.height * scale))),
                    Image.LANCZOS,
                )
            buffer = io.BytesIO()
            img.save(buffer, format="JPEG", quality=90)
            return buffer.getvalue()
    except OSError:
        with open(image_path, "rb") as f:
            return f.read()


def extract_receipt_data(image_path: str) -> dict:
    """
    Extracts date and amount from a receipt image using a vision model on Ollama.
    Returns the same shape as the MLX backend.
    Raises OCRBusyError when a scan is already running, and OCRUnavailableError
    when Ollama is unreachable or the model has not been pulled yet.
    """
    if not OCR_LOCK.acquire(timeout=0.5):
        raise OCRBusyError("Another scan is in progress. Please try again shortly.")

    try:
        encoded_image = base64.b64encode(_prepare_image(image_path)).decode("utf-8")

        payload = json.dumps({
            "model": _OLLAMA_MODEL,
            "prompt": build_system_prompt(),
            "images": [encoded_image],
            "stream": False,
            # Qwen3-family models reason before answering and will spend the whole
            # num_predict budget inside a <think> block, returning an empty response.
            # Non-thinking models accept and ignore this flag.
            "think": False,
            "options": {
                "temperature": 0,
                "num_predict": 200,
                "num_ctx": _NUM_CTX,
            },
        }).encode("utf-8")

        request = urllib.request.Request(
            f"{_OLLAMA_HOST}/api/generate",
            data=payload,
            headers={"Content-Type": "application/json"},
        )

        try:
            with urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            # A missing model is the single most likely first-run failure, and the
            # fix is a specific command — say so instead of surfacing a bare 500.
            if e.code == 404:
                raise OCRUnavailableError(
                    f"Ollama does not have the model '{_OLLAMA_MODEL}'. "
                    f"Pull it with: ollama pull {_OLLAMA_MODEL}"
                ) from e
            # Include Ollama's own message — it names the actual problem
            # (context overflow, bad options) instead of a bare status code.
            detail = e.read().decode("utf-8", "replace")[:300]
            raise OCRUnavailableError(f"Ollama returned HTTP {e.code}: {detail}") from e
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            # The two setups fail for different reasons, so point at the right fix
            # rather than a generic "is it running?".
            if "//ollama:" in _OLLAMA_HOST:
                hint = "Start it with: docker compose --profile bundled up -d"
            else:
                hint = (
                    "Check that it is running and reachable from the container "
                    "(a host install must listen on 0.0.0.0, not just 127.0.0.1)."
                )
            raise OCRUnavailableError(
                f"Could not reach Ollama at {_OLLAMA_HOST}. {hint}"
            ) from e
    finally:
        OCR_LOCK.release()

    return _normalize_fields(parse_model_json(body.get("response", "")))
