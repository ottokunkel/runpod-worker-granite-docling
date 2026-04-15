"""RunPod async handler — routes each job to the right engine and streams
results back. Follows the Jacob-ML/inference-worker pattern."""

import os

import runpod

from engine import LlamaCPPEngine, LlamaCPPOpenAIEngine
from utils import JobInput

MAX_CONCURRENCY = int(os.getenv("MAX_CONCURRENCY", "8"))


async def handler(job):
    job_input = JobInput(job["input"])
    engine = (
        LlamaCPPOpenAIEngine() if job_input.openai_route else LlamaCPPEngine()
    )
    async for batch in engine.generate(job_input):
        yield batch


runpod.serverless.start({
    "handler": handler,
    "concurrency_modifier": lambda _x: MAX_CONCURRENCY,
    "return_aggregate_stream": True,
})
