FROM ghcr.io/ggml-org/llama.cpp:server-cuda

RUN apt-get update && \
    apt-get install -y python3 python3-pip curl && \
    rm -rf /var/lib/apt/lists/*

# Download Q8_0 model + multimodal projector
RUN mkdir -p /models && \
    curl -L -o /models/granite-docling-258M-Q8_0.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/granite-docling-258M-Q8_0.gguf" && \
    curl -L -o /models/mmproj-granite-docling-258M-Q8_0.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/mmproj-granite-docling-258M-Q8_0.gguf"

COPY requirements.txt /requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /requirements.txt

COPY handler.py /handler.py

ENV MODEL_PATH=/models/granite-docling-258M-Q8_0.gguf
ENV MMPROJ_PATH=/models/mmproj-granite-docling-258M-Q8_0.gguf
ENV LLAMA_HOST=127.0.0.1
ENV LLAMA_PORT=8080
ENV GPU_LAYERS=99

CMD ["python3", "-u", "/handler.py"]
