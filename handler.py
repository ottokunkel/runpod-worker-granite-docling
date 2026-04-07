"""RunPod serverless handler for granite-docling-258M via llama.cpp server."""

import os
import subprocess
import time

import requests
import runpod

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MODEL_PATH = os.getenv("MODEL_PATH", "/models/granite-docling-258M-Q8_0.gguf")
MMPROJ_PATH = os.getenv("MMPROJ_PATH", "/models/mmproj-granite-docling-258M-Q8_0.gguf")
LLAMA_HOST = os.getenv("LLAMA_HOST", "127.0.0.1")
LLAMA_PORT = int(os.getenv("LLAMA_PORT", "8080"))
GPU_LAYERS = os.getenv("GPU_LAYERS", "99")
SERVER_URL = f"http://{LLAMA_HOST}:{LLAMA_PORT}"

# ---------------------------------------------------------------------------
# Server lifecycle
# ---------------------------------------------------------------------------

def start_llama_server():
    """Start llama-server and block until it reports healthy."""
    cmd = [
        "llama-server",
        "-m", MODEL_PATH,
        "--mmproj", MMPROJ_PATH,
        "-ngl", GPU_LAYERS,
        "--host", LLAMA_HOST,
        "--port", str(LLAMA_PORT),
        "--ctx-size", "16384",
    ]
    print(f"[handler] starting llama-server: {' '.join(cmd)}")
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    for _ in range(120):
        try:
            r = requests.get(f"{SERVER_URL}/health", timeout=2)
            if r.status_code == 200:
                print("[handler] llama-server is healthy")
                return proc
        except requests.ConnectionError:
            pass
        time.sleep(1)

    proc.kill()
    raise RuntimeError("llama-server did not become healthy within 120 s")


# ---------------------------------------------------------------------------
# Request handler
# ---------------------------------------------------------------------------

def handler(job):
    """
    Expected input:
      {
        "image":       "<base64-encoded image>",   // or
        "image_url":   "https://...",
        "prompt":      "Convert this page to markdown.",  // optional
        "max_tokens":  8192,    // optional
        "temperature": 0.0      // optional
      }
    """
    inp = job["input"]

    image_b64 = inp.get("image")
    image_url = inp.get("image_url")
    prompt = inp.get("prompt", "Convert this page to markdown.")
    max_tokens = int(inp.get("max_tokens", 8192))
    temperature = float(inp.get("temperature", 0.0))

    # Build multimodal content array
    content = []

    if image_b64:
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{image_b64}"},
        })
    elif image_url:
        content.append({
            "type": "image_url",
            "image_url": {"url": image_url},
        })
    else:
        return {"error": "Provide 'image' (base64) or 'image_url'."}

    content.append({"type": "text", "text": prompt})

    try:
        resp = requests.post(
            f"{SERVER_URL}/v1/chat/completions",
            json={
                "messages": [{"role": "user", "content": content}],
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
            timeout=300,
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        return {"error": f"Inference request failed: {exc}"}

    result = resp.json()
    return {
        "output": result["choices"][0]["message"]["content"],
        "usage": result.get("usage", {}),
    }


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

print("[handler] cold-starting llama-server …")
_server_proc = start_llama_server()

runpod.serverless.start({"handler": handler})
