"""OCR backend selection.

Set OCR_BACKEND to pick the engine that reads receipts:
  vision (default) Apple Vision OCR + a small extraction model — macOS only
  ollama           a vision model on an Ollama server — any platform, used by Docker

The chosen backend's module is imported lazily below. That matters: importing
vision_backend pulls in the pyobjc Vision bindings, which cannot be installed on
Linux, so a top-level import would make the app unstartable inside a container.
"""
import os

from .common import OCRBusyError, OCRImageError, OCRUnavailableError

OCR_BACKEND = os.environ.get("OCR_BACKEND", "vision").strip().lower()

# The MLX-VLM backend was replaced by 'vision', which does the same job in about
# a sixth of the memory. Accept the old name so an existing .env keeps working.
if OCR_BACKEND == "mlx":
    print("OCR_BACKEND=mlx is retired; using 'vision' instead. Update your .env.")
    OCR_BACKEND = "vision"

if OCR_BACKEND == "vision":
    from .vision_backend import extract_receipt_data, shutdown as shutdown_ocr
elif OCR_BACKEND == "ollama":
    from .ollama_backend import extract_receipt_data

    def shutdown_ocr() -> None:
        """Nothing to stop: the Ollama backend owns no process of its own."""
else:
    raise ValueError(
        f"Unknown OCR_BACKEND '{OCR_BACKEND}'. Expected 'vision' or 'ollama'."
    )

__all__ = [
    "extract_receipt_data",
    "shutdown_ocr",
    "OCRBusyError",
    "OCRImageError",
    "OCRUnavailableError",
    "OCR_BACKEND",
]
