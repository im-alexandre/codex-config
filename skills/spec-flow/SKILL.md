---
name: spec-flow
description: Orquestra um fluxo guiado de mudança de software desde brainstorming, spec, plano e tasks até handoff para implementação TDD. Use quando o usuário invocar explicitamente `$spec-flow` ou `spec-flow`, pedir para conduzir uma feature/refatoração/correção por etapas aprovadas, ou quiser usar Spec Kit/Superpowers/`$implement-tdd` sem lembrar os comandos intermediários.
---

# Spec Flow

Conduza mudanças de software em fases, mantendo decisões interativas na thread principal e iniciando implementação somente depois de spec, plano e tasks aprovados.

## Fluxo

1. Leia o contexto do projeto: `AGENTS.md`, README, estrutura, branch, estado do git e artefatos existentes de spec/plano/tasks.
2. Identifique o modo disponível:
   - Spec Kit: `.specify/`, `specs/**/spec.md`, `plan.md`, `tasks.md` ou skills/comandos `speckit-*`.
   - Superpowers: `docs/superpowers/specs/` ou `docs/superpowers/plans/`.
   - Fallback: `.codex/spec-flow/<yyyy-mm-dd>-<slug>/`.
3. Faça brainstorming quando houver feature nova, refatoração comportamental ou decisão de produto/arquitetura.
4. Crie ou atualize a spec e peça aprovação do usuário.
5. Gere plano e tasks depois da aprovação da spec.
6. Peça validação das tasks antes de implementar.
7. Após aprovação explícita, crie `.codex/web-dev/implementation-context.md` com `plan path: <caminho>` e invoque `$implement-tdd`.

## Gates

- Não escreva código de produção antes da aprovação das tasks.
- Não despache agentes write-capable diretamente por este skill; use `$implement-tdd` para matriz, worktrees, TDD, revisão e integração.
- Se já houver artefatos relevantes, retome do próximo gate incompleto em vez de duplicar.
- Se houver ambiguidade real ou risco de sobrescrever trabalho, pare e pergunte.

## Artefatos

Prefira os caminhos do projeto. Quando não houver convenção local, use:

- `.codex/spec-flow/<yyyy-mm-dd>-<slug>/spec.md`
- `.codex/spec-flow/<yyyy-mm-dd>-<slug>/plan.md`
- `.codex/spec-flow/<yyyy-mm-dd>-<slug>/tasks.md`

O handoff para `$implement-tdd` deve ficar em:

```markdown
# Implementation Context

plan path: <caminho-do-plano-ou-tasks>
task source: <caminho-das-tasks-separado-se-houver>
feature: <slug>
approved for implementation: yes

Notes:

- <restricoes importantes>
- <comandos de validacao principais>
```
