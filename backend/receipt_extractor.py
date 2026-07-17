import datetime
import json
import threading

from mlx_vlm import generate, load
from mlx_vlm.prompt_utils import apply_chat_template
from mlx_vlm.utils import load_config

# Global variables to store the model in memory
_MODEL = None
_PROCESSOR = None
_CONFIG = None
_MODEL_PATH = "mlx-community/Qwen3.5-0.8B-4bit"

_GPU_LOCK = threading.Lock()


class OCRBusyError(Exception):
    """Another scan is already running on the GPU."""


def _load_model_locked():
    """
    Lazy loads the model only when the first request is made.
    This prevents memory usage until necessary.
    Caller must hold _GPU_LOCK.
    """
    global _MODEL, _PROCESSOR, _CONFIG
    if _MODEL is None:
        print("Loading OCR model...")
        _MODEL, _PROCESSOR = load(_MODEL_PATH, trust_remote_code=True)
        _CONFIG = load_config(_MODEL_PATH, trust_remote_code=True)


def extract_receipt_data(image_path: str) -> dict:
    """
    Extracts date and amount from a receipt image.
    Returns: A dictionary like {'date': '25/10/2025', 'time': '10:23:54', 'amount': 'RM 12.50'}
    Raises OCRBusyError instead of queueing when a scan is already running —
    waiting would silently tie up a second server thread for the whole scan.
    """
    if not _GPU_LOCK.acquire(timeout=0.5):
        raise OCRBusyError("Another scan is in progress. Please try again shortly.")

    try:
        # 1. Ensure model is loaded
        _load_model_locked()

        # 2. Get current datetime
        now = datetime.datetime.now()
        current_time_str = now.strftime("%Y-%m-%d %H:%M:%S")

        # 3. Define the strict JSON prompt
        system_prompt = f"""
        You are a silent, automated data extraction tool. Your ONLY job is to extract data from the image into a JSON format.
        The current datetime is: {current_time_str}. If there is not enough information from the image given, refer to this current time.
        Find the following fields:
        1. 'date': The transaction date. Format it strictly as DD/MM/YYYY. If no date is found, return null.
        2. 'time': The transaction time. Format it strictly as HH:MM:SS. If no time is found, return null.
        3. 'amount': The total paid amount. Format it as a positive value with the currency, like 'RM XX.00'. Always remove any negative signs.

        Your response MUST be a raw JSON object and NOTHING ELSE.
        """

        # 4. Format prompt using the chat template
        formatted_prompt = apply_chat_template(
            _PROCESSOR, _CONFIG, system_prompt, num_images=1
        )

        # 5. Generate output
        raw_output = generate(
            _MODEL,
            _PROCESSOR,
            formatted_prompt,
            [image_path],
            verbose=False,
            max_tokens=200,
            temperature=0.0,
        )
    finally:
        _GPU_LOCK.release()

    # 6. Clean and Parse JSON
    # Sometimes models add markdown ```json blocks, so we clean that up
    clean_json = raw_output.text.replace("```json", "").replace("```", "").strip()

    try:
        data = json.loads(clean_json)
        return data
    except json.JSONDecodeError:
        print(f"Warning: Model returned invalid JSON: {clean_json}")
        return {
            "date": None,
            "time": None,
            "amount": None,
            "error": "JSON parse failed",
        }


# Optional: Allow running this file directly for testing
if __name__ == "__main__":
    # Test run
    result = extract_receipt_data("./img/test2.jpg")
    print("Test Result:", result)
