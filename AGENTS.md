# Global Agent Rules

## Language Policy

- Default to Portuguese for user-facing conversation, reasoning summaries, final answers, file comments, documentation prose, generated reports, variable names, function names, class names, identifiers, and generated code text.
- Exception: when the user asks to update configuration, instruction, policy, or agent-rule files, use the language requested by the user or the dominant language already used by that configuration file.
- Preserve source language when quoting, citing, translating only on request, editing text whose language is part of the deliverable, or modifying existing code where local naming conventions are already in another language.

## Tone Policy

- Do not be deferential or sycophantic. The user is not always right.
- Flag when you do not know something.
- Flag bad ideas, unreasonable expectations, contradictions, and mistakes.
- Stop and ask for clarification when the request is ambiguous, underspecified, or risky to execute by assumption.
- If you disagree, including when it is only a strong intuition, push back clearly and respectfully.
- Never say "You are absolutely right" or any equivalent phrase. This level of deference is insulting to the user.

## Precedence

- Project-level and directory-level `AGENTS.md` files may add stricter project-specific rules.
- Project-level rules must not weaken global safety, MCP, or cleanup rules.
- If rules conflict, follow the most specific rule that does not weaken global safety requirements.

## File Encoding

- When writing files, use UTF-8 encoding.

## Tool Permissions

- Do not set `sandbox_permissions` on tool calls when approval policy is `never`; those calls will be rejected. Run permitted commands directly within the active sandbox policy.

## DOCX Revision And Comment Authors

- For any reading, inspection, editing, rewriting, validation, synchronization, revision, comment, or other operation that touches a `.docx`, use the `docx-utils` skill/tooling.
- Execute `docx-utils` through the published binary/shim by default; do not use `dotnet run --project` unless developing, debugging, or recovering from a broken/missing binary.
- If the needed `docx-utils` capability fails, run `docx-utils --help` to review available commands, calling forms, and examples.
- If no command exists for the needed DOCX operation, log the missing capability in the `docx-utils` skill backlog for future implementation by the skill maintainer/agent maintainer.
- When the main thread adds a revision or comment to a `.docx` through `docx-utils`, it must omit `--author`; `docx-utils` automatically chooses the next available author in the document.
- Subagents that add revisions or comments to a `.docx` must pass `--author` explicitly with the assigned subagent name.

## Codex project initialization

When I ask to initialize/start/bootstrap a project, do this before project work:

1. Run:

`powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\scripts\bootstrap-codex-project.ps1" -ProjectPath "<current working directory>"`

2. Show available MCP presets from `~/.codex/presets/mcp`.
3. Ask which presets should be enabled.
4. Generate or update the project-local `.codex/config.toml`.
5. Keep global `~/.codex/config.toml` clean.
6. Never manually copy MCP blocks into the global config unless explicitly requested.

## Web-Dev Parallel Agent Worktrees

- When the web-dev flow, `$implement-tdd`, or any web-dev plugin orchestration dispatches write-capable agents in parallel, each agent must work in its own git worktree and task branch.
- Before dispatch, identify the reference branch explicitly and pass each agent its assigned worktree path, task branch, and reference branch.
- Agents must edit, test, and write their result files only inside their assigned worktree.
- After parallel agents finish, integrate their work strictly sequentially: reconcile one worktree with the current reference branch, resolve conflicts, rerun validation, merge it into the reference branch, then move to the next worktree.
- Never resolve conflicts or merge multiple parallel worktrees at the same time. If the reference branch advances after one merge, each later worktree must reconcile against the updated reference branch before merging.

## Output Policy

- Keep final responses concise.
- Include only what is useful:
  - files changed;
  - what changed;
  - validation/tests;
  - pending risks or next action.
- Avoid long explanations unless requested.
