# Use an official ggml-org/llama.cpp image as the base image
FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV PYTHONUNBUFFERED=1
ENV LLAMA_PARALLEL=16
ENV LLAMA_CTX_SIZE=131072

# Set up the working directory
WORKDIR /

RUN apt-get update --yes --quiet && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    software-properties-common \
    gpg-agent \
    build-essential apt-utils \
    && apt-get install --reinstall ca-certificates \
    && add-apt-repository --yes ppa:deadsnakes/ppa && apt update --yes --quiet \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-distutils \
    python3.11-lib2to3 \
    python3.11-gdbm \
    python3.11-tk \
    bash \
    curl && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Bake the granite-docling model + mmproj into the image
RUN mkdir -p /models && \
    curl -fsSL https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/granite-docling-258M-f16.gguf \
        -o /models/granite-docling.gguf && \
    curl -fsSL https://huggingface.co/ggml-org/granite-docling-258M-GGUF/resolve/main/mmproj-granite-docling-258M-f16.gguf \
        -o /models/mmproj.gguf

# Set the working directory
WORKDIR /work

# Add ./src as /work
ADD ./src /work

# Install runpod and its dependencies
RUN pip install -r ./requirements.txt && chmod +x /work/start.sh

# Set the entrypoint
ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
