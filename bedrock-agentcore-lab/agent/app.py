"""
Minimal placeholder agent for the AgentCore Runtime container contract.

Uses the `bedrock-agentcore` Python SDK's BedrockAgentCoreApp, which is
meant to handle the Runtime's HTTP contract (health check + invocation
endpoint) for you.

NOTE (unverified - see README): this SDK's exact API surface and version
pin (requirements.txt) weren't confirmed against live PyPI/AWS docs from
this sandbox. Before relying on this beyond this lab: `pip show
bedrock-agentcore`, read its actual README, and confirm `BedrockAgentCoreApp`
/ `@app.entrypoint` / `app.run()` are real, current APIs - adjust if not.

Replace the body of `invoke()` with real orchestration (e.g. a Strands
Agents or LangGraph agent that calls the tools this lab's AgentCore Gateway
exposes) once the SDK shape above is confirmed.
"""

from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()


@app.entrypoint
def invoke(payload):
    message = payload.get("prompt", "")
    return {
        "response": (
            f"Placeholder agent received: {message!r}. "
            "Replace this handler with real orchestration against the "
            "AgentCore Gateway's tools."
        ),
    }


if __name__ == "__main__":
    app.run()
