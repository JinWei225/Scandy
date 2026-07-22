"""Pieces shared by every OCR backend: the prompt, the response parsing, and the
single-scan lock. Keeping these here means swapping the model runtime cannot
accidentally change what we ask for or how we read the answer."""
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
