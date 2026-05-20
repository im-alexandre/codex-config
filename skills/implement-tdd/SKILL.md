---
name: implement-tdd
description: Command-only skill for `$implement-tdd`. Use only when the user explicitly invokes `$implement-tdd` or `implement-tdd` to execute a Superpowers implementation plan, resume from `.codex/web-dev/implementation-context.md`, auto-pick the newest local plan when no argument is provided, archive implemented plans, or route a direct development/refactor/debug instruction to the best TDD subagent.
---

# Implement TDD

## Overview

Execute development work through an explicit TDD orchestration command instead of global subagent rules. The main thread coordinates, chooses agents, tracks events, and integrates; implementation slices go to specialized subagents that must prove red, green, and refactor discipline.

## Trigger Contract

Use this skill only for explicit command forms:

- `$implement-tdd`
- `$implement-tdd <plan-path>`
- `$implement-tdd "<direct development instruction>"`
- `implement-tdd <plan-path-or-instruction>`

Do not trigger implicitly for ordinary coding requests. If the user asks to brainstorm or write a plan, keep using the existing Superpowers flow first.

## Input Resolution

1. If an argument is an existing file path, treat it as implementation plan mode.
2. If no argument is provided, first look for `.codex/web-dev/implementation-context.md`.
   - If it exists, read it before reading any plan.
   - Extract the plan path from a line such as `plan path: <path>`, `plan: <path>`, or a clear Markdown bullet containing the plan path.
   - Confirm that the extracted plan path exists.
   - Treat that plan as implementation plan mode.
   - After reading the context and confirming the plan path, remove `.codex/web-dev/implementation-context.md` before dispatching implementation work so stale context cannot be reused accidentally.
   - If the context exists but the plan path is missing or invalid, stop and ask for the correct plan path.
3. If no argument is provided and there is no temporary context, find the newest plan under the current project:
   - Prefer `docs/superpowers/plans/*.md`.
   - Also scan `.codex/plans/*.md`, `specs/**/plan.md`, and `specs/**/tasks.md`.
   - Use `scripts/find_latest_plan.py --root <cwd>` and read the selected path.
   - If no plan is found, ask for a plan path or direct instruction.
4. If the argument is not a file path, treat it as direct instruction mode.

## Plan Mode

Use this when a Superpowers or Spec Kit implementation plan already exists.

1. Announce: `Vou usar $implement-tdd para executar este plano com orquestração TDD por agentes.`
2. Read the plan once in the main thread.
3. Classify tasks into:
   - blocking tasks;
   - parallel tasks;
   - sequential tasks because of shared files, migrations, API contracts, routing, schemas, fixtures, or test infrastructure;
   - tiny tasks that are safer to keep in the integration step.
4. Build a compact execution matrix with task id, agent, dependency, file scope, red command, green command, and integration order.
5. Before spawning any agent, build and share or log a full wave map for the entire plan, not only the first unblocked wave.
   - Label why the first wave is blocking when it has only one task.
   - Label which later waves are parallelizable after the blocker clears.
   - Identify shared-file integration steps separately from parallel implementation work.
   - If a single-task first wave is only a temporary model/schema/contract blocker, state that explicitly so it is not confused with a serial strategy.
6. Dispatch only the currently unblocked wave. Do not dispatch overlapping write scopes in parallel.
7. While a blocking wave runs, use read-only sidecar exploration only when it prepares later parallel waves without duplicating implementation work.
8. After each wave, inspect events and agent results before unlocking the next wave.
9. Run an aggregator/reviewer pass at the end.

## Worktree Isolation And Sequential Integration

When implementation work is dispatched to multiple agents, each write-capable agent must work in its own git worktree and on its own task branch. Use the installed `using-git-worktrees` skill rules when preparing those workspaces: detect existing isolation first, prefer native worktree tooling if available, and fall back to `git worktree` only when needed.

Before dispatching a parallel wave:

- Identify the reference branch explicitly. Use the current branch unless the plan names another reference branch.
- Assign a unique worktree path and branch name for each write-capable task.
- Pass the worktree path, task branch, and reference branch in the subagent prompt.
- Require the subagent to run all edits, tests, event writes, and result writes inside its assigned worktree only.
- Do not dispatch two write-capable agents into the same checkout, worktree path, or branch.

After a parallel wave finishes, integrate worktrees strictly one at a time:

1. Pick the next completed worktree according to the matrix's integration order.
2. Update or compare that task branch against the current reference branch before merging.
3. Resolve all conflicts between that worktree and the current reference branch inside that worktree or through a single assigned follow-up agent.
4. Rerun the task's green/integration validation after conflict resolution.
5. Merge that task branch into the reference branch only after conflicts are resolved and validation passes.
6. Move to the next completed worktree only after the previous merge is complete.

Never resolve conflicts or merge multiple parallel worktrees at the same time. If the reference branch advances after an earlier task is merged, every later task must reconcile against that updated reference before its own merge.

## Direct Instruction Mode

Use this as a lightweight proxy when the user wants a subagent for a development/refactor/debug task without writing a full plan first.

1. Inspect only enough local context to identify stack and task type.
2. Choose one best-fit subagent and pass a bounded instruction with minimal necessary context.
3. For feature, development, bugfix, or refactor work, require TDD even in direct mode.
4. If the instruction is too broad for one subagent, create a small execution matrix and dispatch waves as in plan mode.

Direct mode should avoid dragging the whole main-thread context into the worker. Pass explicit paths, commands, constraints, and success criteria instead.

## Agent Selection

- Django/DRF backend: `backend-django-drf-tdd`
- React/Vite frontend: `frontend-react-vite-tdd`
- final TDD/code review: `tdd-quality-reviewer`
- stack-neutral implementation: `worker` with the TDD contract copied into the prompt
- exploration-only tasks: `explorer`
- integration/reconciliation: main thread, unless a read-only reviewer is useful

Do not use a stronger model for workers unless the user explicitly requested it or the task is blocked by reasoning complexity.

## TDD Contract For Implementers

Every implementation subagent must:

1. write or update tests first;
2. cover the happy path and error paths for incorrect calls, invalid input, permission/validation failures, or other negative cases relevant to the slice;
3. run the smallest targeted test command and record the red failure;
4. implement the minimum production change;
5. run the targeted command and record green;
6. refactor only when it generalizes or removes real duplication without broadening scope;
7. run any integration command assigned by the matrix;
8. write a final result to `.codex/agent-events/results/<task-id>.md`.

Implementation subagents must not stop to ask for approval on an already-approved plan. If the task scope, write scope, commands, and acceptance criteria are clear, they execute the TDD loop. They report `blocked` only when the task conflicts with scope, safety, missing information, unavailable tooling, or an impossible test/runtime condition.

## Event Protocol

Before dispatching agents, ensure these paths exist:

- `.codex/agent-events/events.jsonl`
- `.codex/agent-events/results/`

Each subagent must append JSONL events with this schema:

```json
{
  "agent": "<agent-name-or-nickname>",
  "task": "<short task id>",
  "status": "started|running|blocked|done|error",
  "summary": "<short update>",
  "files": ["<relevant paths>"],
  "next": "<next action or empty>",
  "ts": "<ISO-8601 timestamp>"
}
```

Each subagent emits at least `started` and `done` or `error`; use `running` or `blocked` for useful checkpoints.

## Aggregator Pass

After all implementation waves finish:

1. Prefer lifecycle results from subagents first; read result files as supporting evidence.
2. Inspect the event log for blocked/error statuses.
3. Run the relevant targeted tests, then the broader project validation that the matrix selected.
4. Dispatch `tdd-quality-reviewer` for a read-only review when the change is non-trivial.
5. Integrate or resolve conflicts in the main thread.
6. If implementation is complete and validations have run, move the implemented plan out of the active plan directory:
   - For `docs/superpowers/plans/<name>.md`, move to `docs/superpowers/plans/implemented/<name>.md`.
   - For `.codex/plans/<name>.md`, move to `.codex/plans/implemented/<name>.md`.
   - Create the destination directory if needed.
   - If the destination exists, append a timestamp before `.md` instead of overwriting.
   - Do not move `specs/**/plan.md` or `specs/**/tasks.md`; instead mention that Spec Kit plans remain in place.
7. Return changed files, tests run, TDD evidence, archived plan path, conflicts resolved, and remaining risks.

## Superpowers Integration

This command replaces the final execution handoff after `superpowers:writing-plans` saves a plan. Keep the current flow through `brainstorming` and `writing-plans`; when the plan is complete, run `$implement-tdd` with no arguments. If `.codex/web-dev/implementation-context.md` exists, use it first; otherwise auto-pick the newest plan. A plan path can still be passed explicitly.

Do not use `superpowers:executing-plans` or `superpowers:subagent-driven-development` as the primary executor unless the user asks for the original Superpowers execution behavior. This skill incorporates their useful ideas while adding stack-aware agent routing, waves, TDD red/green/refactor evidence, and a final aggregator.

For prompt templates and checklist wording, read `references/prompt-contracts.md` only when preparing dispatch prompts.
