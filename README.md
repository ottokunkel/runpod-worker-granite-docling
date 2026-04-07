# runpod-worker-granite-docling

RunPod serverless worker for [granite-docling-258M](https://huggingface.co/ggml-org/granite-docling-258M-GGUF) — IBM's document-to-markdown vision model running on llama.cpp.

Takes a document/page image and returns structured text (Markdown, HTML, DocTags).

## Build & Deploy

```bash
docker build -t runpod-worker-granite-docling .
```

Push to your container registry and create a RunPod serverless endpoint pointing to the image.

## API

**Input:**

| Field         | Type   | Required | Default                            |
|---------------|--------|----------|------------------------------------|
| `image`       | string | *        | —                                  |
| `image_url`   | string | *        | —                                  |
| `prompt`      | string | no       | `"Convert this page to markdown."` |
| `max_tokens`  | int    | no       | `8192`                             |
| `temperature` | float  | no       | `0.0`                              |

\* Provide either `image` (base64) or `image_url`.

**Output:**

```json
{
  "output": "# Document Title\n\nParsed markdown content…",
  "usage": { "prompt_tokens": 512, "completion_tokens": 1024 }
}
```

## Local Testing

```bash
docker run --gpus all -p 8080:8080 runpod-worker-granite-docling
# In another terminal:
curl -X POST http://localhost:8080/runsync \
  -H "Content-Type: application/json" \
  -d @test_input.json
```

## Environment Variables

| Variable      | Default                                              |
|---------------|------------------------------------------------------|
| `MODEL_PATH`  | `/models/granite-docling-258M-Q8_0.gguf`             |
| `MMPROJ_PATH` | `/models/mmproj-granite-docling-258M-Q8_0.gguf`      |
| `GPU_LAYERS`  | `99`                                                 |
| `LLAMA_HOST`  | `127.0.0.1`                                          |
| `LLAMA_PORT`  | `8080`                                               |

## Model

- **granite-docling-258M** — 258M-parameter multimodal model by IBM Research
- Capabilities: full-page OCR, layout detection, table recognition, chart-to-table, equation/code recognition
- Uses Q8_0 quantization (~282 MB total for model + projector)
- Apache-2.0 license
