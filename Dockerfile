FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Download F16 weights + multimodal projector.
# F16 matches the BF16 throughput profile measured on GB10 (~2324 t/s).
RUN mkdir -p /models && \
    curl -L -o /models/granite-docling.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/granite-docling-258M-f16.gguf" && \
    curl -L -o /models/mmproj.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/mmproj-granite-docling-258M-f16.gguf"

EXPOSE 8000

# Flags from the GB10 batched-bench sweep (-c 2048 -b 2048 -ub 512 peaked
# at ~2324 t/s). ctx bumped to 8192 for long-page image-token headroom.
# --parallel 1 matches RunPod Serverless (1 in-flight req/worker) and drops
# the multi-slot KV-cache bookkeeping.
# --flash-attn on is a major win on Blackwell tensor cores.
# --no-warmup skips the CUDA graph warmup so the container reports ready
# sooner — the first request pays the warmup cost instead.
CMD ["llama-server", \
     "--model", "/models/granite-docling.gguf", \
     "--mmproj", "/models/mmproj.gguf", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--n-gpu-layers", "999", \
     "--ctx-size", "8192", \
     "--batch-size", "2048", \
     "--ubatch-size", "512", \
     "--parallel", "1", \
     "--flash-attn", "on", \
     "--no-warmup", \
     "--metrics"]
