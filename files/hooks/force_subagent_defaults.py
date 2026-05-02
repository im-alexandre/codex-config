import json
import sys

payload = json.load(sys.stdin)
prompt = payload.get("prompt", "")

markers = [
    "subagent",
    "subagents",
    "spawn",
    "spawn_agent",
    "spawn_agents",
    "dispara",
    "delegar",
    "paralelizar",
    "agents",
]

if any(m.lower() in prompt.lower() for m in markers):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "UserPromptSubmit",
                    "additionalContext": """
When spawning any subagent without an explicit model, use:
- model: gpt-5.4-mini
- reasoning effort: medium

Do not use a stronger model for subagents unless the user explicitly requests it.
For arbitrary subagent tasks, use the local default/explorer/worker/reviewer agent configs.
""",
                }
            }
        )
    )
