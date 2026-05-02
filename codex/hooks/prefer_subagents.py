import json
import sys

payload = json.load(sys.stdin)
prompt = payload.get("prompt", "")

# Não bloqueia nada. Só injeta política operacional.
instruction = """
Execution policy for this turn:

Keep the main thread clean.

If the user request requires execution, reading files, editing code, testing, debugging,
searching, comparing, refactoring, or documentation changes, use subagents instead of
doing noisy work in the main thread.

If the work can be parallelized, spawn multiple subagents, up to 5.

Default subagent settings:
- model: gpt-5.4-mini
- reasoning effort: medium

Main agent responsibilities:
1. create a short plan;
2. split the work into bounded subagent tasks;
3. wait for all subagents;
4. consolidate results;
5. return only the useful final summary.

Avoid raw logs, long exploration notes, and intermediate dumps in the main thread.
"""

print(
    json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": instruction,
            }
        }
    )
)
