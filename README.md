# runpod-worker-granite-docling

RunPod **Serverless** worker for
[granite-docling-258M](https://huggingface.co/ggml-org/granite-docling-258M-GGUF)
— IBM's document-to-markdown vision model running on `llama-server`
(llama.cpp). The container runs `llama-server` directly on port `8000`;
RunPod proxies HTTP to it — no custom handler, no SDK.

## Build & Deploy

```bash
docker build -t runpod-worker-granite-docling .
# push to your registry, then create a RunPod Serverless endpoint:
#   - container image: <your-registry>/runpod-worker-granite-docling
#   - container port:  8000
#   - port name:       llamaserver
```

## Usage

The worker is OpenAI-compatible. Point any OpenAI client at the proxy URL:

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://<endpoint-id>-8000.proxy.runpod.net/v1",
    api_key="sk-no-key-required",
)
resp = client.chat.completions.create(
    model="granite-docling",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": "https://…/page.png"}},
            {"type": "text", "text": "Convert this page to markdown."},
        ],
    }],
)
print(resp.choices[0].message.content)
```

## Local Testing

```bash
docker run --rm --gpus all -p 8000:8000 runpod-worker-granite-docling
# in another shell:
curl -sf http://localhost:8000/health
curl -s http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":[
        {"type":"image_url","image_url":{"url":"https://huggingface.co/ibm-granite/granite-docling-258M/resolve/main/assets/new_arxiv.png"}},
        {"type":"text","text":"Convert this page to markdown."}]}],
      "max_tokens":512,"temperature":0}' | jq -r '.choices[0].message.content'
```

## Model

- **granite-docling-258M** — 258M-parameter multimodal model by IBM Research (Apache-2.0)
- F16 GGUF + multimodal projector
- Capabilities: full-page OCR, layout detection, tables, charts, equations/code
- Tuned for a GB10-class GPU with `-b 2048 -ub 512 --flash-attn on --parallel 1`
