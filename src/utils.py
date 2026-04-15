"""JobInput adapter — parses the two job shapes the worker accepts.

Raw:      {"messages": [...], "stream": false}
          {"prompt":   "...",  "stream": false}
OpenAI:   {"openai_route": "/v1/chat/completions",
           "openai_input": {"model": "...", "messages": [...], ...}}
"""


class JobInput:
    def __init__(self, job):
        self.llm_input = job.get("messages", job.get("prompt"))
        self.stream = job.get("stream", False)
        self.openai_route = job.get("openai_route")
        self.openai_input = job.get("openai_input")
