# Prompt Contracts For `$implement-tdd`

Use these snippets when preparing subagent dispatches. Keep prompts bounded: include only task text, relevant paths, test commands, constraints, and acceptance criteria.

## Coordinator Matrix

The main thread produces:

```markdown
| Task | Agent | Depends on | Write scope | Red command | Green command | Integration order |
| --- | --- | --- | --- | --- | --- | --- |
```

Use the expanded form when dispatching implementation work:

```markdown
| Task | Stack | Agent | Mandatory skills loaded | Depends on | Write scope | Red command | Green command | Integration order |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

Rules:

- Mark same files, migrations, shared contracts, routers, schemas, fixtures, and test harness changes as sequential.
- Record the stack and mandatory skill files for each implementation task before dispatch.
- Do not use generic fallback agents for coding work when a stack-specific agent exists.
- If no specialist exists for the stack, stop and ask whether to create one, unless the edit is tiny and demonstrably stack-neutral.
- Dispatch only one wave of non-overlapping tasks at a time.
- Put shared setup, dependency installation, generated clients, migrations, and contract changes before dependent tasks.
- For any parallel write-capable wave, assign each task its own git worktree path and task branch.
- Record the reference branch for the wave. Use the current branch unless the plan explicitly names another reference branch.
- Integrate completed parallel worktrees sequentially: reconcile one task branch with the current reference branch, resolve conflicts, rerun validation, merge, then continue to the next worktree.
- Never resolve conflicts or merge two parallel worktrees at the same time.

## Implementer Prompt Shape

```text
You are the <agent-name> implementer for task <task-id>.

Agent/skill gate:
- Assigned stack: <stack>
- Mandatory skills/instructions to load before planning or editing:
  - <absolute path or skill name>
- If this task is outside your assigned stack, report blocked instead of implementing.
- If a mandatory skill/instruction file cannot be loaded, report blocked instead of continuing.

Workspace:
- Worktree path: <assigned worktree path>
- Task branch: <assigned task branch>
- Reference branch: <reference branch>
- Work only inside the assigned worktree. Do not edit the original checkout or another agent's worktree.

Use strict TDD:
1. load every mandatory skill/instruction file and keep it as an active harness, not a memory summary;
2. if context was compacted, summarized, reset, or the exact skill text is no longer available, reload the mandatory skill files before continuing;
3. before tests, code edits, or review findings, write structured evidence at `.codex/agent-events/skill-harness/<task-id>-<agent-name>.md` using this shape:
   ```markdown
   # Skill Harness Evidence

   task: <task-id>
   agent: <agent-name>

   loaded:
   - path: <absolute path or skill name>
     status: loaded
     checksum-or-timestamp: <sha256 or mtime when practical>

   rules:
   - <3-7 non-negotiable rules from the loaded skills>

   constraints:
   - <how those rules constrain this task>
   ```
4. write/update tests first;
5. include happy path and relevant error-path coverage;
6. run the red command and record the failing signal;
7. implement the smallest production change;
8. run the green command and record the passing signal;
9. refactor only if it generalizes or removes real duplication;
10. append JSONL events to .codex/agent-events/events.jsonl;
11. write final result to .codex/agent-events/results/<task-id>.md, including the skill-harness evidence path and applied skill rules.

Task:
<full bounded task text>

Write scope:
<paths>

Commands:
- Red: <command>
- Green: <command>
- Integration: <optional command>

Do not edit outside the write scope unless blocked; report blocked if scope is wrong.
Before final result, confirm the current path is the assigned worktree and list the task branch.
```

## Aggregator Prompt Shape

```text
Review the completed $implement-tdd work read-only unless explicitly asked to integrate.

Check:
- TDD evidence includes red and green;
- skill-harness evidence exists for each specialist task, uses the structured `task:`, `agent:`, `loaded:`, `rules:`, and `constraints:` fields, and proves the agent used loaded skill files as active constraints rather than summarized background;
- tests cover happy path and relevant error paths;
- changed files stay inside intended scope;
- no unresolved blocked/error events remain;
- targeted and integration validation commands were run or clearly could not run.
- for frontend or full-stack work, the main thread performed manual end-to-end validation in a browser against the running app/API, covering every user-facing flow and case of use named in the spec/tasks; if not, the blocker is explicit.

Return findings first, then validation summary, then remaining risks.
```
