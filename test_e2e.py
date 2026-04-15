"""E2E test against a deployed RunPod Serverless endpoint.

Reads OPENAI_BASE_URL + OPENAI_API_KEY from .env. Sends a single image
transcription request and prints the result + timing.

    python test_e2e.py
"""

import os
import time

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

MODEL = os.getenv("OPENAI_MODEL", "granite-docling")
IMAGE_URL = os.getenv(
    "TEST_IMAGE_URL",
    "https://huggingface.co/ibm-granite/granite-docling-258M/resolve/main/assets/new_arxiv.png",
)

client = OpenAI()  # reads OPENAI_BASE_URL + OPENAI_API_KEY from env

print(f"POST {client.base_url}chat/completions   model={MODEL}")

t0 = time.perf_counter()
resp = client.chat.completions.create(
    model=MODEL,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": IMAGE_URL}},
            {"type": "text",      "text": "Convert this page to docling."},
        ],
    }],
    max_tokens=1024,
    temperature=0.0,
    timeout=300.0,
)
elapsed = time.perf_counter() - t0

content = resp.choices[0].message.content or ""
print(f"\nelapsed: {elapsed:.2f}s")
print(f"usage:   {resp.usage}")
print(f"\n--- transcription ({len(content)} chars) ---\n{content}")
