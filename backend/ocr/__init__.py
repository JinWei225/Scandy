"""OCR backend selection.

Set OCR_BACKEND to pick the engine that reads receipts:
  mlx    (default) local MLX-VLM on Apple Silicon — fastest, macOS only
  ollama           a vision model on an Ollama server — any platform, used by Docker

The chosen backend's module is imported lazily below. That matters: importing
mlx_backend pulls in mlx_vlm, which cannot be installed on Linux, so a top-level
import would make the app unstartable inside a container.
"""
import os

from .common import OCRBusyError, OCRUnavailableError

OCR_BACKEND = os.environ.get("OCR_BACKEND", "mlx").strip().lower()

if OCR_BACKEND == "mlx":
    from .mlx_backend import extract_receipt_data
elif OCR_BACKEND == "ollama":
    from .ollama_backend import extract_receipt_data
else:
    raise ValueError(
        f"Unknown OCR_BACKEND '{OCR_BACKEND}'. Expected 'mlx' or 'ollama'."
    )

__all__ = ["extract_receipt_data", "OCRBusyError", "OCRUnavailableError", "OCR_BACKEND"]
