# Prompt Contracts For `$implement-tdd`

Use these snippets when preparing subagent dispatches. Keep prompts bounded: include only task text, relevant paths, test commands, constraints, and acceptance criteria. Subagents are disposable: spawn one fresh subagent per bounded task, close it after `done`, `blocked`, or `error`, and never reuse it for a later task or correction pass. The main thread coordinates only; every execution step, including tiny edits, tests, validation, review, conflict-resolution edits, and manual/E2E checks, must be assigned to a subagent.

## Coordinator Matrix

The main thread produces:

```markdown
| Task | Agent | Model | Reasoning | Depends on | Write scope | Existing resources/interfaces | New resource justification | Red command | Green command | Prompt context | Worktree | Branch | Integration order | Disposal |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

Use the expanded form when dispatching implementation work:

```markdown
| Task | Stack | Agent | Model | Reasoning | Mandatory skills loaded | Depends on | Write scope | Existing resources/interfaces | New resource justification | Red command | Green command | Prompt context | Worktree | Branch | Integration order | Disposal |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

Rules:

- Mark same files, migrations, shared contracts, routers, schemas, fixtures, and test harness changes as sequential.
- Split broad work until each subagent task covers one stack, one bounded behavior, one write scope, one red command, and one green command.
- If broad context is required, split first. If splitting is impossible or harmful, assign one fresh specialist/coordinator subagent and document the broad-context reason in `Prompt context`.
- For any approved broad-context task, explicitly set `Model` and `Reasoning` in the matrix. Use a stronger available model and high/xhigh reasoning when correctness depends on cross-cutting architecture, conflict-heavy reconciliation, security/data risk, concurrency, protocol contracts, or repeated failed correction.
- If the runtime cannot apply the selected model/reasoning to the chosen specialist role, document the limitation and choose the closest available specialist/model combination before dispatch.
- Keep the full plan in the main thread. The `Prompt context` column must name only the short excerpts, paths, or acceptance criteria the subagent needs.
- Do not pass full specs, full plans, full task files, full conversation history, or unrelated architecture notes to implementers.
- For every implementation task, name existing resources/interfaces to reuse: components, APIs, schemas, commands, helpers, fixtures, styles, storage patterns, test harnesses, or E2E flows.
- Set `New resource justification` to `none` unless creating a new resource/interface is explicitly justified.
- Record the stack and mandatory skill files for each implementation task before dispatch.
- Do not use generic fallback agents for coding work when a stack-specific agent exists.
- If no specialist exists for the stack, stop and ask whether to create one, unless the edit is tiny and demonstrably stack-neutral; tiny stack-neutral edits still require a fresh `worker` subagent.
- Dispatch only one wave of non-overlapping tasks at a time.
- Spawn a fresh subagent for each matrix row that requires an agent.
- Close/remove every subagent after its row reaches `done`, `blocked`, or `error`; do not reuse it for another row.
- Put shared setup, dependency installation, generated clients, migrations, and contract changes before dependent tasks.
- For any parallel write-capable wave, assign each task its own git worktree path and task branch.
- Record the reference branch for the wave. Use the current branch unless the plan explicitly names another reference branch.
- Integrate completed parallel worktrees sequentially: reconcile one task branch with the current reference branch, resolve conflicts, rerun validation, merge, then continue to the next worktree.
- Never resolve conflicts or merge two parallel worktrees at the same time.

## Implementer Prompt Shape

```text
You are the <agent-name> implementer for task <task-id>.

Lifecycle:
- You are a fresh, disposable subagent for this one task only.
- Do not ask to continue into another task.
- Do not retain responsibility after writing your final result.
- If follow-up work is required, report it as a new bounded task for the main coordinator.

Agent/skill gate:
- Assigned stack: <stack>
- Assigned model/reasoning: <model>, <reasoning effort>
- Mandatory skills/instructions to load before planning or editing:
  - <absolute path or skill name>
- If this task is outside your assigned stack, report blocked instead of implementing.
- If a mandatory skill/instruction file cannot be loaded, report blocked instead of continuing.

Workspace:
- Worktree path: <assigned worktree path>
- Task branch: <assigned task branch>
- Reference branch: <reference branch>
- Work only inside the assigned worktree. Do not edit the original checkout or another agent's worktree.

Context budget:
- Use only the context below plus files you read inside the assigned worktree.
- Do not request the full plan/spec/tasks unless the missing excerpt blocks this task.
- If this task needs broad project context to proceed safely, report blocked and explain the smallest split or excerpt needed, unless the prompt explicitly marks this as an approved broad-context task and explains why splitting would be harmful.

Existing resource rule:
- Prefer existing project resources and interfaces over creating new ones.
- Reuse or extend these when applicable:
  <components, APIs, schemas, commands, helpers, fixtures, styles, storage patterns, test harnesses, E2E flows>
- New resource/interface justification:
  <none or approved reason>
- If no existing resource/interface is listed, perform a bounded local search in the assigned worktree before implementing.
- Report blocked before creating a new public API, component, schema, command, helper, fixture, style, test harness, abstraction, storage shape, or E2E flow without justification.

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
12. in the final result, list reused existing resources/interfaces and justify every new resource/interface created.

Task:
<full bounded task text>

Task-local context:
<short excerpts, exact paths, API contracts, or acceptance criteria only>

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
- existing resources/interfaces were reused when available, and any new resource/interface has an approved justification;
- no unresolved blocked/error events remain;
- targeted and integration validation commands were run or clearly could not run.
- for frontend or full-stack work, a fresh manual/E2E validation subagent checked the running app/API, covering every user-facing flow and case of use named in the spec/tasks; if not, the blocker is explicit.

Return findings first, then validation summary, then remaining risks.
```
