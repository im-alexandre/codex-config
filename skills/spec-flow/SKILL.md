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
   - Superpowers: prompts/skills de brainstorming, spec e plano podem ser usados como método, mas os artefatos gerados devem ficar no mesmo diretório de feature usado pelo Spec Kit.
   - Fallback: quando não houver diretório existente, crie `specs/<slug>/`.
3. Faça brainstorming quando houver feature nova, refatoração comportamental ou decisão de produto/arquitetura.
4. Crie ou atualize a spec e peça aprovação do usuário.
5. Gere plano e tasks depois da aprovação da spec.
6. Peça validação das tasks antes de implementar.
7. Após aprovação explícita, crie `.codex/web-dev/implementation-context.md` com `plan path: <caminho>` e invoque `$implement-tdd`.

## Handoff TDD

- O handoff para implementação deve preservar a separação entre Spec Kit/Superpowers e execução: `spec-flow` decide produto/arquitetura com o usuário; `$implement-tdd` escolhe especialistas, habilidades obrigatórias, worktrees e validação.
- Antes do handoff, registre no plano ou nas tasks qualquer pista de stack envolvida (ex.: Django/DRF, React/Vite, .NET/TUI, Go, Node, DOCX/PPTX) para impedir despacho por agente genérico.
- Se a mudança envolver uma stack sem especialista configurado, marque isso como risco no handoff em vez de deixar `$implement-tdd` reaproveitar `worker` automaticamente.
- Antes de criar `.codex/web-dev/implementation-context.md`, confirme que as tasks carregam um checklist de handoff com: stacks detectadas, agente esperado por stack, especialista ausente quando aplicável, fluxos manuais obrigatórios, validação mínima por stack, e se o harness mecânico de skills deve ser ativado por `$implement-tdd`.

## Gates

- Não escreva código de produção antes da aprovação das tasks.
- Não despache agentes write-capable diretamente por este skill; use `$implement-tdd` para matriz, worktrees, TDD, revisão e integração.
- Se já houver artefatos relevantes, retome do próximo gate incompleto em vez de duplicar.
- Se houver ambiguidade real ou risco de sobrescrever trabalho, pare e pergunte.

## Artefatos

Use um único diretório de feature para todos os artefatos do fluxo, independente de o raciocínio vir de Spec Kit, Superpowers ou fallback local. Prefira um diretório Spec Kit existente; quando não houver, crie:

- `specs/<slug>/brainstorm.md`
- `specs/<slug>/spec.md`
- `specs/<slug>/plan.md`
- `specs/<slug>/tasks.md`

Se o projeto já tiver uma feature em `specs/<numero>-<slug>/`, `specs/<slug>/` ou outro padrão sob `specs/`, continue nesse diretório em vez de criar outro. Não grave novos artefatos de `spec-flow` em `docs/superpowers/specs/`, `docs/superpowers/plans/` ou `.codex/spec-flow/`; trate esses caminhos apenas como legado para leitura/retomada.

O handoff para `$implement-tdd` deve ficar em:

```markdown
# Implementation Context

plan path: <caminho-do-plano-ou-tasks>
task source: <caminho-das-tasks-separado-se-houver>
feature: <slug>
approved for implementation: yes

Notes:

- <restricoes importantes>
- stacks detected: <pilhas envolvidas>
- specialist expected by stack: <pilha -> agente esperado>
- missing specialist risks: <pilhas sem agente especializado, se houver>
- skill harness required: <sim/não; sim para implementação/revisão especialista via $implement-tdd>
- manual e2e required: <sim/não; obrigatório para frontend ou full-stack>
- user-facing flows to verify manually: <fluxos/casos de uso que devem ser testados no navegador>
- minimum validation by stack: <pilha -> comando(s) de validação>
- <outras restrições importantes>
```
