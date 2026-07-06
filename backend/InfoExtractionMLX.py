from mlx_vlm import generate, load
from mlx_vlm.prompt_utils import apply_chat_template
from mlx_vlm.utils import load_config

# 1. Setup the model path and image
model_path = "mlx-community/Qwen3.5-0.8B-4bit"
image_path = "img/tr2.jpg"

# 2. Load the model and processor
# trusted=True is often needed for custom architectures like Qwen2-VL
print(f"Loading model: {model_path}...")
model, processor = load(model_path, trust_remote_code=True)
config = load_config(model_path, trust_remote_code=True)

# 3. Construct the Prompt
# We ask for JSON format to make extraction easier for your application
prompt = """
    You are a silent, automated data extraction tool. Your ONLY job is to extract data from the image into a JSON format.

    Find the following fields:
    1.  'date': The transaction date. Format it strictly as DD/MM/YYYY. If no date is found, return null.
    2.  'amount': The total paid amount. Format it as a positive value with the currency, like 'RM XX.00'. Always remove any negative signs. If no amount is found, return null.

    Your response MUST be a raw JSON object and NOTHING ELSE. Do not add explanations, apologies, or markdown formatting.

    Example of your ONLY valid response:
    {"date": "25/10/2025", "amount": "RM 12.50"}
    """

# 4. Apply the chat template (handles image token processing)
formatted_prompt = apply_chat_template(processor, config, prompt, num_images=1)

# 5. Generate the output
print("Extracting data...")
output = generate(
    model,
    processor,
    formatted_prompt,
    [image_path],
    verbose=False,
    max_tokens=200,  # Limit tokens since we only want specific fields
    temperature=0.0,  # Zero temperature for deterministic/factual results
)

print("\n--- Extraction Result ---")
print(output.text)
