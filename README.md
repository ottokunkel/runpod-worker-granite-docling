<p align="center">
    <img src="https://raw.githubusercontent.com/ggml-org/llama.cpp/master/media/llama1-icon-transparent.png" alt="llama.cpp logo" width="96">
</p>

# runpod-worker-granite-docling

RunPod serverless worker for IBM's [granite-docling-258M](https://huggingface.co/ggml-org/granite-docling-258M-GGUF)
vision model, running via `llama-server` (llama.cpp). Exposes an
OpenAI-compatible chat-completions endpoint that accepts a document image
and returns structured output (markdown, HTML, or DocTags).

Architecture follows [Jacob-ML/inference-worker](https://github.com/Jacob-ML/inference-worker):
`start.sh` boots `llama-server` on port `3098`, waits for it to listen,
then runs an async RunPod handler that forwards requests through the
OpenAI SDK to the local server. Streaming is supported.

## API

The worker accepts two job-input shapes:

**OpenAI-wrapped (what RunPod's `/openai/v1/...` routes deliver):**
```json
{
    "input": {
        "openai_route": "/v1/chat/completions",
        "openai_input": {
            "model": "granite-docling",
            "messages": [{"role": "user", "content": [...]}],
            "max_tokens": 512,
            "stream": false
        }
    }
}
```

**Raw (for direct `/run` / `/runsync` calls):**
```json
{
    "input": {
        "messages": [{"role": "user", "content": [...]}],
        "stream": false
    }
}
```

For image transcription, `content` is an array of
`{"type": "image_url", "image_url": {"url": "..."}}` followed by
`{"type": "text", "text": "Convert this page to markdown."}`.

## Usage — OpenAI SDK against a deployed endpoint

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://api.runpod.ai/v2/<endpoint-id>/openai/v1",
    api_key="<your-runpod-api-key>",
)
resp = client.chat.completions.create(
    model="granite-docling",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": "https://…/page.png"}},
            {"type": "text",      "text": "Convert this page to markdown."},
        ],
    }],
)
print(resp.choices[0].message.content)
```

## Configuration

Set via environment variables on the RunPod endpoint:

| Var | Default | Description |
| --- | --- | --- |
| `LLAMA_SERVER_CMD_ARGS` | *(baked-in granite-docling F16 + GB10-tuned flags)* | Full `llama-server` argv. Do **not** set `--port` — 3098 is fixed. |
| `MAX_CONCURRENCY` | `8` | Max concurrent in-flight requests per worker. |

## Build & Deploy

```bash
docker build -t runpod-worker-granite-docling .
# push to your registry, then create a RunPod Serverless endpoint from the image.
```

## Model

- **granite-docling-258M** — 258M-parameter multimodal model (IBM Research, Apache-2.0)
- Baked in as F16 GGUF + multimodal projector (~700 MB total)
- Capabilities: full-page OCR, layout detection, tables, charts, equations/code
- Tuned for Blackwell-class GPUs with `-b 2048 -ub 512 --flash-attn on --parallel 1`
