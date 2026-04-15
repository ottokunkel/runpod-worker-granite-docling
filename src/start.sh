#!/bin/bash
# Boot llama-server on port 3098 with the baked-in granite-docling F16 model
# and the GB10 benchmark-tuned flags, wait for it to print "listening", then
# hand off to the RunPod handler. Pattern adapted from Jacob-ML/inference-worker.

set -e -o pipefail

cleanup() {
    echo "start.sh: cleaning up..."
    pkill -P $$
    exit 0
}
trap cleanup SIGINT SIGTERM

# Default llama-server args — baked-in F16 weights + GB10-tuned flags.
# Override via LLAMA_SERVER_CMD_ARGS env var. --port is always 3098.
DEFAULT_ARGS="--model /models/granite-docling.gguf \
--mmproj /models/mmproj.gguf \
--n-gpu-layers 999 \
--ctx-size 8192 \
--batch-size 2048 \
--ubatch-size 512 \
--parallel 1 \
--flash-attn on \
--no-warmup \
--metrics"

if [ -z "$LLAMA_SERVER_CMD_ARGS" ]; then
    LLAMA_SERVER_CMD_ARGS="$DEFAULT_ARGS"
fi

if [[ "$LLAMA_SERVER_CMD_ARGS" == *"--port"* ]]; then
    echo "start.sh: error: do not define --port in LLAMA_SERVER_CMD_ARGS (port 3098 is fixed)."
    exit 1
fi

echo "start.sh: launching llama-server on :3098 with args: $LLAMA_SERVER_CMD_ARGS"

# Clean up any stale instance from a previous boot.
pkill llama-server 2>/dev/null || true

touch llama.server.log
LD_LIBRARY_PATH=/app /app/llama-server $LLAMA_SERVER_CMD_ARGS --host 0.0.0.0 --port 3098 2>&1 | tee llama.server.log &
LLAMA_PID=$!

# Wait for "listening" in the log, with liveness + timeout guards.
tries=0
while true; do
    if grep -q "listening" llama.server.log; then
        echo "start.sh: llama-server is up"
        break
    fi
    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "start.sh: error: llama-server exited before becoming healthy"
        tail -n 80 llama.server.log || true
        exit 1
    fi
    tries=$((tries + 1))
    if [ "$tries" -ge 240 ]; then
        echo "start.sh: error: llama-server did not report 'listening' within 120 s"
        exit 1
    fi
    sleep 0.5
done

echo "start.sh: delegating to handler.py"
exec python3 -u handler.py "$@"
