FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV PYTHONUNBUFFERED=1

WORKDIR /

RUN apt-get update --yes --quiet && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
      software-properties-common gpg-agent build-essential apt-utils ca-certificates && \
    add-apt-repository --yes ppa:deadsnakes/ppa && \
    apt-get update --yes --quiet && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
      python3.11 python3.11-dev python3.11-distutils bash curl && \
    ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/python3.11 /usr/bin/python3 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download F16 weights + multimodal projector.
# F16 matches the BF16 throughput profile measured on GB10 (~2324 t/s).
RUN mkdir -p /models && \
    curl -L -o /models/granite-docling.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/granite-docling-258M-f16.gguf" && \
    curl -L -o /models/mmproj.gguf \
      "https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/mmproj-granite-docling-258M-f16.gguf"

WORKDIR /work
ADD ./src /work
RUN pip install --no-cache-dir -r /work/requirements.txt && chmod +x /work/start.sh

# Reset the inherited llama-server ENTRYPOINT; start.sh launches it.
ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
