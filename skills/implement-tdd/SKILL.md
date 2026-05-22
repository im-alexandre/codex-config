---
name: implement-tdd
description: Command-only skill for `$implement-tdd`. Use only when the user explicitly invokes `$implement-tdd` or `implement-tdd` to execute a Superpowers implementation plan, resume from `.codex/web-dev/implementation-context.md`, auto-pick the newest local plan when no argument is provided, archive implemented plans, or route a direct development/refactor/debug instruction to the best TDD subagent.
---

# Implement TDD

## Overview

Execute development work through an explicit TDD orchestration command instead of global subagent rules. The main thread only coordinates: it reads plans, builds the execution matrix, starts and ends waves, creates and closes subagents, inspects evidence, decides integration order, and reports status. All implementation, test writing, test execution, validation, review, tiny edits, conflict-resolution edits, and manual/E2E execution must be assigned to fresh disposable subagents.

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
   - Prefer `specs/**/plan.md` and `specs/**/tasks.md`, including plans produced by `spec-flow` through Superpowers-style brainstorming/planning.
   - Also scan legacy `docs/superpowers/plans/*.md` and `.codex/plans/*.md`.
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
   - tiny tasks that still require a subagent, but may use `worker` only when demonstrably stack-neutral and no specialist is appropriate.
4. Split any broad task until each agent task has the smallest practical execution scope: one stack, one bounded behavior, one write scope, one red command, one green command, and the smallest task-local context that can be extracted safely.
   - If a task needs broad context, split it first.
   - If splitting is impossible or would create clear correctness, architecture, safety, or integration harm, assign the broad task to a fresh specialist or coordinator subagent with the required context budget, model, and reasoning effort documented in the matrix.
   - Do not move context-heavy implementation or validation into the main thread.
5. Build a compact execution matrix with task id, agent, model, reasoning effort, dependency, file scope, red command, green command, integration order, prompt context, worktree path, task branch, and disposal point.
   - Include existing resources/interfaces to reuse for each task.
   - Include any approved justification for creating new resources/interfaces.
6. Before spawning any agent, build and share or log a full wave map for the entire plan, not only the first unblocked wave.
   - Label why the first wave is blocking when it has only one task.
   - Label which later waves are parallelizable after the blocker clears.
   - Identify shared-file integration steps separately from parallel implementation work.
   - If a single-task first wave is only a temporary model/schema/contract blocker, state that explicitly so it is not confused with a serial strategy.
7. Dispatch only the currently unblocked wave. Do not dispatch overlapping write scopes in parallel.
8. While a blocking wave runs, use fresh read-only sidecar subagents only when they prepare later parallel waves without duplicating implementation work.
9. After each wave, inspect events and agent results, close every spawned subagent from that wave, then unlock the next wave.
10. Run an aggregator/reviewer pass at the end.

## Disposable Subagent Lifecycle

Each subagent is disposable and task-scoped. Never reuse a subagent thread, conversation, or agent instance for another task, another wave, or a later correction pass.

Lifecycle:

1. Spawn a fresh subagent for exactly one bounded task.
2. Pass only the task-local context needed for that task: task id, assigned stack, relevant paths, minimal acceptance criteria, allowed write scope, red/green commands, worktree path, task branch, reference branch, mandatory skill paths, and event/result paths.
3. Do not pass the full implementation plan, full spec, full tasks file, unrelated architecture notes, full conversation history, or other agents' results unless a short excerpt is directly required by the task.
4. Wait only when that agent's result is needed to continue the current wave or integration.
5. When the agent reaches `done`, `blocked`, or `error`, read its result and event files, then close/remove that subagent immediately.
6. If follow-up work is needed, create a new task or correction slice and spawn a new subagent with fresh minimal context. Do not resume or message the closed/completed agent for implementation work.
7. Keep coordination decisions in the main thread. Any concrete execution step, including editing, testing, validating, reviewing, conflict-resolution edits, or manual/E2E operation, must go to a fresh subagent with a bounded prompt.

If a task cannot be described without giving the agent broad project context, the task is too large. Split it first. If splitting is impossible or harmful, create one fresh specialist/coordinator subagent for that larger task and explicitly document why the broader context is necessary, which model is required, and which reasoning effort is required.

## Worktree Isolation And Sequential Integration

When implementation work is dispatched to multiple agents, each write-capable agent must work in its own git worktree and on its own task branch. Use the installed `using-git-worktrees` skill rules when preparing those workspaces: detect existing isolation first, prefer native worktree tooling if available, and fall back to `git worktree` only when needed.

Before dispatching any write-capable subagent:

- Identify the reference branch explicitly. Use the current branch unless the plan names another reference branch.
- Assign a unique worktree path and branch name for the task.
- Pass the worktree path, task branch, and reference branch in the subagent prompt.
- Require the subagent to run all edits, tests, event writes, and result writes inside its assigned worktree only.
- Do not dispatch two write-capable agents into the same checkout, worktree path, or branch.
- Do not assign one worktree to more than one subagent lifecycle. A follow-up correction gets a new subagent and may reuse the same task branch only after the previous subagent has been closed and the main thread has decided that reuse is safer than creating a new correction branch.

After a parallel wave finishes, integrate worktrees strictly one at a time:

1. Pick the next completed worktree according to the matrix's integration order.
2. Update or compare that task branch against the current reference branch before merging.
3. Resolve all conflicts between that worktree and the current reference branch through a fresh reconciliation subagent assigned to that one conflict set.
4. Rerun the task's green/integration validation through a fresh validation subagent after conflict resolution.
5. Merge that task branch into the reference branch only after conflicts are resolved and validation passes.
6. Move to the next completed worktree only after the previous merge is complete.

Never resolve conflicts or merge multiple parallel worktrees at the same time. If the reference branch advances after an earlier task is merged, every later task must reconcile against that updated reference before its own merge.

## Direct Instruction Mode

Use this as a lightweight proxy when the user wants a subagent for a development/refactor/debug task without writing a full plan first.

1. Inspect only enough local context to identify stack and task type.
2. Choose one best-fit subagent and pass a bounded instruction with minimal necessary context.
3. For feature, development, bugfix, or refactor work, require TDD even in direct mode.
4. If the instruction is too broad for one subagent, create a small execution matrix and dispatch waves as in plan mode.
5. Close/remove the subagent after it reports `done`, `blocked`, or `error`; any follow-up uses a new subagent with a new bounded prompt.

Direct mode should avoid dragging the whole main-thread context into the worker. Pass explicit paths, commands, constraints, and success criteria instead.

## Agent Selection

- Django/DRF backend: `backend-django-drf-tdd`
- React/Vite frontend: `frontend-react-vite-tdd`
- final TDD/code review: `tdd-quality-reviewer`
- stack-neutral tiny implementation: `worker` only when no stack-specific agent applies and the prompt includes the full TDD contract
- exploration-only tasks: `explorer`
- integration/reconciliation execution: fresh bounded specialist, reviewer, or worker subagent; the main thread only chooses order and inspects results

Do not use a stronger model for workers unless the user explicitly requested it or the task is blocked by reasoning complexity.

Do not route code changes through a generic fallback agent when a stack-specific agent exists. If no suitable specialist exists, stop and either ask for a specialist to be created or use `worker` only for a tiny, clearly stack-neutral edit with the full TDD contract, mandatory skill/load checklist, write scope, and validation command copied into the prompt. The main thread must not perform the edit itself.

## Model And Reasoning Selection

Default to the configured specialist agent role and its normal model for small and medium bounded tasks. Escalate model and reasoning only when the matrix documents why the task cannot be safely split further or why it is blocked by reasoning complexity.

Use these defaults:

- small bounded slice: configured specialist role, default reasoning;
- medium slice with normal TDD complexity: configured specialist role, default or medium reasoning;
- broad unsplittable implementation, cross-cutting refactor, migration strategy, conflict-heavy reconciliation, or architecture-sensitive change: fresh specialist/coordinator subagent with stronger available model and high reasoning;
- high-risk review, security-sensitive behavior, data-loss risk, concurrency, protocol/contracts across stacks, or repeated failed correction: fresh reviewer/specialist subagent with strongest appropriate available model and high or xhigh reasoning.

When escalating, record in the matrix:

- why the task could not be split safely;
- selected agent role;
- selected model;
- selected reasoning effort;
- exact context budget and excerpts provided;
- stop condition for reporting `blocked` instead of improvising.

If the runtime does not permit changing model/reasoning for the chosen specialist role, use the closest available specialist role and document the limitation in the matrix and final report.

## Existing Resource Preference

Every dispatched subagent must prefer resources and interfaces already present in the project.

- Before creating a new public API, route, component, hook, service, schema, command, helper, fixture, style, test harness, abstraction, storage shape, or E2E flow, the subagent must inspect the assigned scope for existing equivalents.
- Reuse, adapt, or extend existing project interfaces and patterns whenever they satisfy the task without clear harm.
- Create new resources/interfaces only when the matrix explicitly allows it. If reuse appears harmful and the matrix does not approve a new resource/interface, report `blocked` with evidence and do not create it; the coordinator must decide whether to approve a new bounded task.
- If a task's `Prompt context` omits existing resources/interfaces to reuse, the subagent must do a bounded local search inside its worktree before implementing.
- Final results must state which existing resources/interfaces were reused, and justify any new resource/interface created.

## TDD Contract For Implementers

Every implementation subagent must:

0. confirm the assigned stack is in scope for that agent and load every mandatory skill/instruction file before planning or editing;
0.1. treat those mandatory skills/instructions as an active harness, not a summarized hint: if context was compacted, summarized, reset, or the exact loaded skill text is no longer available, reload the mandatory skill files before continuing;
0.2. write structured skill-harness evidence to `.codex/agent-events/skill-harness/<task-id>-<agent-name>.md` before tests, code edits, or review findings. The evidence must use `task:`, `agent:`, `loaded:`, `rules:`, and `constraints:` fields; `loaded:` lists skill paths plus availability/checksum or timestamp when practical, `rules:` lists 3-7 non-negotiable rules from those skills, and `constraints:` explains how each rule constrains the current task;
0.3. identify existing resources/interfaces in the write scope and prefer reuse before creating anything new;
1. write or update tests first;
2. cover the happy path and error paths for incorrect calls, invalid input, permission/validation failures, or other negative cases relevant to the slice;
3. run the smallest targeted test command and record the red failure;
4. implement the minimum production change;
5. run the targeted command and record green;
6. refactor only when it generalizes or removes real duplication without broadening scope;
7. run any integration command assigned by the matrix;
8. write a final result to `.codex/agent-events/results/<task-id>.md`.

Implementation subagents must not stop to ask for approval on an already-approved plan. If the task scope, write scope, commands, and acceptance criteria are clear, they execute the TDD loop. They report `blocked` only when the task conflicts with scope, safety, missing information, unavailable tooling, missing skill-harness evidence, or an impossible test/runtime condition.

Implementation subagents must reject out-of-scope work instead of improvising. A specialist agent must not silently switch stacks, load unrelated language skills, or reuse its role for another technology. If the coordinator selected the wrong agent, the subagent reports `blocked` and names the correct specialist or the missing specialist that should be created.

## Event Protocol

Before dispatching agents, ensure these paths exist:

- `.codex/agent-events/events.jsonl`
- `.codex/agent-events/results/`
- `.codex/agent-events/skill-harness/`
- `.codex/agent-events/skill-harness-required`

Create `skill-harness-required` only for `$implement-tdd` specialist implementation/review runs. Its presence activates the mechanical hook guard; remove it after the implementation plan is fully integrated or clearly abandoned so ordinary project sessions are not blocked.

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

Skill-harness evidence format:

```markdown
# Skill Harness Evidence

task: <task-id>
agent: <agent-name>

loaded:
- path: <absolute path or skill name>
  status: loaded
  checksum-or-timestamp: <sha256 or mtime when practical>

rules:
- <non-negotiable rule from the loaded skill>

constraints:
- <how the rule changes this task's implementation, tests, or review>
```

## Aggregator Pass

After all implementation waves finish:

1. Prefer lifecycle results from subagents first; read result files as supporting evidence.
2. Inspect the event log for blocked/error statuses.
3. Inspect every `.codex/agent-events/skill-harness/*.md` file for implementation/review tasks and verify the structured `task:`, `agent:`, `loaded:`, `rules:`, and `constraints:` fields name the mandatory skill paths and task-specific rules. If evidence is missing, malformed, stale, or only says the skill was summarized, treat the task as blocked and create a fresh correction task for a new subagent with the same specialist role.
4. Dispatch fresh validation subagents to run the relevant targeted tests and the broader project validation selected by the matrix.
5. Dispatch a fresh `tdd-quality-reviewer` subagent for read-only review when the change is non-trivial.
6. Coordinate integration order in the main thread, but perform merge preparation, conflict-resolution edits, and post-merge validation through fresh bounded subagents.
7. For frontend or full-stack work, dispatch a fresh manual/E2E validation subagent before closing the plan:
   - start the backend, frontend, database, and required services locally when practical;
   - open the UI in a browser and exercise every user-facing flow and case of use named in the spec/tasks, including happy path, validation/error states, empty/loading states, and at least one regression path per changed feature;
   - verify the frontend is actually wired to the backend/API when the feature is full-stack, not only mocked unit behavior;
   - record exact commands, URLs, browser/tool used, flows checked, failures found, and fixes or remaining manual-validation gaps;
   - do not mark the plan complete if manual E2E could not run unless the final answer clearly labels the blocker and why automated validation was the only possible evidence.
8. If implementation is complete and validations have run, move the implemented plan out of the active plan directory:
   - For legacy `docs/superpowers/plans/<name>.md`, move to `docs/superpowers/plans/implemented/<name>.md`.
   - For legacy `.codex/plans/<name>.md`, move to `.codex/plans/implemented/<name>.md`.
   - Create the destination directory if needed.
   - If the destination exists, append a timestamp before `.md` instead of overwriting.
   - Do not move `specs/**/plan.md` or `specs/**/tasks.md`; Spec Kit and `spec-flow` artifacts remain in the feature directory.
9. Remove `.codex/agent-events/skill-harness-required` after all implementation and review evidence has been inspected and the plan is either integrated or explicitly abandoned.
10. Return changed files, tests run, TDD evidence, skill-harness evidence reviewed, manual E2E flows checked, archived plan path, conflicts resolved, and remaining risks.

## Superpowers Integration

This command replaces the final execution handoff after `superpowers:writing-plans` saves a plan. Keep the current reasoning flow through `brainstorming` and `writing-plans`, but when invoked through `spec-flow` the resulting artifacts should live in the Spec Kit feature directory (`specs/<slug>/brainstorm.md`, `spec.md`, `plan.md`, `tasks.md`). When the plan is complete, run `$implement-tdd` with no arguments. If `.codex/web-dev/implementation-context.md` exists, use it first; otherwise auto-pick the newest plan. A plan path can still be passed explicitly.

Do not use `superpowers:executing-plans` or `superpowers:subagent-driven-development` as the primary executor unless the user asks for the original Superpowers execution behavior. This skill incorporates their useful ideas while adding stack-aware agent routing, waves, TDD red/green/refactor evidence, and a final aggregator.

For prompt templates and checklist wording, read `references/prompt-contracts.md` only when preparing dispatch prompts.
