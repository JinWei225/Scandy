"""Pieces shared across OCR backends: the single-scan lock, the error types, and
the image prompt used by any backend that sends a picture to a vision model.

The 'vision' backend does not use build_system_prompt: it sends OCR text to an
extraction model with a JSON template instead, and parses the fields itself in
receipt_text.py. Only the Ollama backend prompts a vision model directly."""
import datetime
import json
import threading

# Only one scan may run at a time regardless of backend. On MLX this protects the
# GPU; on Ollama it stops several Waitress threads piling requests onto one model.
OCR_LOCK = threading.Lock()


class OCRBusyError(Exception):
    """Another scan is already running."""


class OCRUnavailableError(Exception):
    """The configured OCR backend is not reachable or not set up yet."""


class OCRImageError(Exception):
    """The uploaded file could not be read as an image.

    A client error, unlike OCRUnavailableError: nothing is wrong with the
    server, the picture is simply not usable. Separate so the API can answer
    400 and say "try another photo", rather than 503 sending someone off to
    debug a backend that is working perfectly.
    """


def build_system_prompt(now: datetime.datetime | None = None) -> str:
    """The extraction prompt. Identical across backends so results stay comparable."""
    now = now or datetime.datetime.now()
    current_time_str = now.strftime("%Y-%m-%d %H:%M:%S")

    return f"""
        You are a silent, automated data extraction tool. Your ONLY job is to extract data from the image into a JSON format.
        The current datetime is: {current_time_str}. If there is not enough information from the image given, refer to this current time.
        Find the following fields:
        1. 'date': The transaction date. Format it strictly as DD/MM/YYYY. If no date is found, return null.
        2. 'time': The transaction time. Format it strictly as HH:MM:SS. If no time is found, return null.
        3. 'amount': The total paid amount. Format it as a positive value with the currency, like 'RM XX.00'. Always remove any negative signs.

        Your response MUST be a raw JSON object and NOTHING ELSE.
        """


def parse_model_json(raw_text: str) -> dict:
    """Cleans and parses a model response. Sometimes models wrap the object in a
    markdown ```json block, so we strip that before decoding."""
    clean_json = raw_text.replace("```json", "").replace("```", "").strip()

    try:
        return json.loads(clean_json)
    except json.JSONDecodeError:
        print(f"Warning: Model returned invalid JSON: {clean_json}")
        return {
            "date": None,
            "time": None,
            "amount": None,
            "error": "JSON parse failed",
        }
