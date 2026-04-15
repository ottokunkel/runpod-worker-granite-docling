"""OpenAI-compatible engines that forward requests to the locally running
llama-server. Follows the pattern from Jacob-ML/inference-worker."""

import json

from openai import OpenAI
from utils import JobInput

client = OpenAI(base_url="http://localhost:3098/v1/", api_key="sk-no-key")


class LlamaCPPEngine:
    """Normalises raw JobInput (messages/prompt) into an OpenAI-style call."""

    async def generate(self, job_input):
        inner = LlamaCPPOpenAIEngine()
        model = client.models.list().data[0].id

        if isinstance(job_input.llm_input, str):
            wrapped = JobInput({
                "openai_route": "/v1/completions",
                "openai_input": {
                    "model": model,
                    "prompt": job_input.llm_input,
                    "stream": job_input.stream,
                },
            })
        else:
            wrapped = JobInput({
                "openai_route": "/v1/chat/completions",
                "openai_input": {
                    "model": model,
                    "messages": job_input.llm_input,
                    "stream": job_input.stream,
                },
            })

        async for batch in inner.generate(wrapped):
            yield batch


class LlamaCPPOpenAIEngine(LlamaCPPEngine):
    """Direct OpenAI-route passthrough to the local llama-server."""

    async def generate(self, job_input):
        route = job_input.openai_route
        body = job_input.openai_input or {}

        if route == "/v1/models":
            async for r in self._list_models():
                yield r
        elif route in ("/v1/chat/completions", "/v1/completions"):
            async for r in self._complete(body, chat=route == "/v1/chat/completions"):
                yield r
        else:
            yield {"error": f"invalid route: {route}"}

    async def _list_models(self):
        try:
            resp = client.models.list()
            yield {"object": "list", "data": [m.to_dict() for m in resp.data]}
        except Exception as e:
            yield {"error": str(e)}

    async def _complete(self, body, chat):
        try:
            fn = client.chat.completions.create if chat else client.completions.create
            resp = fn(**body)

            if not body.get("stream"):
                yield resp.to_dict()
                return

            for chunk in resp:
                yield "data: " + json.dumps(chunk.to_dict(), separators=(",", ":")) + "\n\n"
            yield "data: [DONE]"

        except Exception as e:
            yield {"error": str(e)}
