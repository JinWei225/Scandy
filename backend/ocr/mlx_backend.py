"""MLX-VLM backend — runs the model locally on Apple Silicon via Metal.

This is the default and the fastest option, but it only works on an Apple Silicon
Mac. The mlx_vlm import lives in this module (not at package level) so that
importing the app on any other platform does not fail; see ocr/__init__.py.
"""
from mlx_vlm import generate, load
from mlx_vlm.prompt_utils import apply_chat_template
from mlx_vlm.utils import load_config

from .common import OCR_LOCK, OCRBusyError, build_system_prompt, parse_model_json

# Global variables to store the model in memory
_MODEL = None
_PROCESSOR = None
_CONFIG = None
_MODEL_PATH = "mlx-community/Qwen3.5-0.8B-4bit"


def _load_model_locked():
    """
    Lazy loads the model only when the first request is made.
    This prevents memory usage until necessary.
    Caller must hold OCR_LOCK.
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
    if not OCR_LOCK.acquire(timeout=0.5):
        raise OCRBusyError("Another scan is in progress. Please try again shortly.")

    try:
        # 1. Ensure model is loaded
        _load_model_locked()

        # 2. Build the shared extraction prompt
        system_prompt = build_system_prompt()

        # 3. Format prompt using the chat template
        formatted_prompt = apply_chat_template(
            _PROCESSOR, _CONFIG, system_prompt, num_images=1
        )

        # 4. Generate output
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
        OCR_LOCK.release()

    return parse_model_json(raw_output.text)
