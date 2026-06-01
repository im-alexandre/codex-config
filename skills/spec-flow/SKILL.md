---
name: spec-flow
description: Orquestra um fluxo guiado de mudança de software desde constitution, brainstorming, spec, plano e tasks até handoff para implementação TDD. Use quando o usuário invocar explicitamente `$spec-flow`, `spec-flow`, `$constitution-input`, pedir uma entrevista para gerar input de constitution, pedir para conduzir uma feature/refatoração/correção por etapas aprovadas, ou quiser usar Spec Kit/Superpowers/`$implement-tdd` sem lembrar os comandos intermediários.
---

# Spec Flow

Conduza mudanças de software em fases, mantendo decisões interativas na thread principal e iniciando implementação somente depois de spec, plano e tasks aprovados.

## Comandos

- `$constitution-input`: entreviste o usuário sem exigir argumentos, gere `.specify/memory/input_constitution.md` e use esse arquivo como entrada para o constitution do Spec Kit.
- `$spec-flow` ou `spec-flow`: conduza o fluxo completo de mudança, retomando do próximo gate incompleto.
- `$spec-flow constitution-input`: trate como alias de `$constitution-input`.

## Workflow Canônico

Quando o usuário invocar `$spec-flow` para uma feature, refatoração, correção ou mudança comportamental, execute os comandos nesta ordem e respeite os gates de aprovação. Retome do primeiro comando incompleto quando artefatos anteriores já existirem.

```text
$constitution-input
-> speckit-specify
-> speckit-clarify
-> speckit-plan
-> speckit-analyze
-> speckit-plan
-> speckit-tasks
-> speckit-analyze
-> speckit-checklist
-> $implement-tdd
```

Regras do workflow:

- Execute `$constitution-input` antes da primeira feature do projeto ou quando `.specify/memory/constitution.md` estiver ausente, incompleta, com placeholders ou desalinhada do projeto.
- Não pule `speckit-clarify`; se nenhuma pergunta for necessária, registre que a spec já está clara e avance.
- Use o primeiro `speckit-plan` para materializar arquitetura, contratos, riscos e validação logo após a spec aprovada.
- Use o primeiro `speckit-analyze` para encontrar conflitos entre constitution, spec e plan antes de gerar tasks.
- Reexecute `speckit-plan` depois do primeiro `speckit-analyze` sempre que houver achados que alterem arquitetura, gates, riscos, contratos, dados, testes ou validação.
- Use `speckit-tasks` somente depois de plan aprovado e sem achados críticos pendentes.
- Use o segundo `speckit-analyze` para auditar spec, plan e tasks juntos.
- Use o checklist final para validar qualidade e completude conjunta de spec, plan e tasks antes do readiness gate.
- Invoque `$implement-tdd` somente depois de aprovação explícita das tasks e do readiness gate.
- Não implemente, edite código de produção, despache agentes write-capable ou crie worktrees antes de `$implement-tdd`.
- Se qualquer comando do Spec Kit estiver indisponível, pare no gate atual e trate como bloqueio de dependência do Spec Kit.

## Preferência Por Recursos Existentes

Durante constitution, spec, plan e tasks, dê preferência estrita a recursos, interfaces e padrões já presentes no projeto.

- Antes de propor API, UI, componente, schema, comando, hook, serviço, helper, fixture, estilo, fluxo E2E ou abstração nova, inventarie o que já existe no escopo do projeto.
- Prefira reutilizar, adaptar ou estender interfaces públicas, componentes, design system, contratos, rotas, schemas, comandos, helpers de teste, fixtures e padrões de persistência já existentes.
- Só proponha recurso/interface nova quando não houver equivalente adequado ou quando reaproveitar o existente criaria prejuízo claro de compatibilidade, segurança, manutenção, UX ou arquitetura.
- Registre na spec, no plan ou nas tasks quais recursos/interfaces existentes devem ser reutilizados e a justificativa de qualquer criação nova.
- Se houver dúvida entre criar algo novo ou reutilizar algo existente, pare e pergunte antes de consolidar plan/tasks.

## Dependência do Spec Kit

O `spec-flow` depende do Spec Kit para constitution, specify, clarify, plan, analyze, tasks e checklist. Não execute o fluxo completo sem Spec Kit inicializado no diretório atual.

1. Detecte Spec Kit por `.specify/`, `.specify/memory/constitution.md`, `.specify/templates/`, `.specify/init-options.json`, artefatos `specs/**` ou skills/comandos `speckit-*`.
2. Se não houver `.specify/` nem `specs/`, não trate isso como bloqueio estrutural adicional: apenas peça confirmação explícita para inicializar o Specify no projeto com integração Codex, skills e PowerShell usando `specify init --here --integration codex --integration-options="--skills" --force`.
3. Se houver sinais parciais de Spec Kit mas a estrutura estiver incompleta para constitution, informe o bloqueio e peça aprovação explícita antes de inicializar ou reinicializar.
4. Com aprovação, prefira `specify init --here --integration codex --integration-options="--skills" --force`.
5. Se `specify` não estiver disponível, peça aprovação explícita para usar `uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration codex --integration-options="--skills" --force`.
6. Sem aprovação para inicializar ou instalar, pare. Não crie artefatos fallback fora do Spec Kit.

## `$constitution-input`

Use este fluxo quando o usuário invocar `$constitution-input` ou `$spec-flow constitution-input`.

1. Confirme a dependência do Spec Kit seguindo a seção anterior.
2. Leia o contexto do projeto antes da entrevista: `AGENTS.md`, README, manifests de stack, `.specify/`, specs existentes, documentação arquitetural e estado do git.
3. Entreviste o usuário em blocos rigorosos e guiados:
   - identidade do projeto, objetivo, público e não objetivos;
   - stack, limites de arquitetura, dependências e integrações;
   - padrões de código, nomenclatura, documentação e compatibilidade;
   - TDD, tipos de teste obrigatórios, comandos mínimos de validação e critérios de cobertura;
   - segurança, privacidade, dados sensíveis, permissões e compliance;
   - UX, acessibilidade, internacionalização e evidência E2E quando houver interface;
   - observabilidade, deploy, rollback, migrações e operações;
   - governança da constitution, versionamento e processo para emendas.
4. Para cada bloco, apresente inferências do repositório como hipóteses e peça confirmação quando a decisão afetar princípios, gates ou obrigações futuras.
5. Gere `.specify/memory/input_constitution.md` em Markdown com seções explícitas para respostas, decisões confirmadas, inferências aceitas, `TODO` de decisões pendentes, comandos de validação e princípios propostos.
6. Carregue o comando/template de constitution do Spec Kit do projeto quando disponível. Se não houver cópia no projeto, use o comando `speckit-constitution` disponível na sessão. Como último recurso, use o template local de Spec Kit apenas se ele existir e informe a origem.
7. Execute o fluxo do constitution usando o conteúdo completo de `.specify/memory/input_constitution.md` como `$ARGUMENTS`. O constitution, não o entrevistador, deve atualizar `.specify/memory/constitution.md` e sincronizar templates dependentes.
8. Ao terminar, reporte o caminho do input gerado, o caminho da constitution atualizada, o resumo do Sync Impact Report e qualquer `TODO` que ainda exija decisão humana.

## Fluxo

1. Leia o contexto do projeto: `AGENTS.md`, README, estrutura, branch, estado do git e artefatos existentes de spec/plano/tasks.
2. Identifique o modo disponível:
   - Spec Kit: `.specify/`, `specs/**/spec.md`, `plan.md`, `tasks.md` ou skills/comandos `speckit-*`.
   - Superpowers: prompts/skills de brainstorming, spec e plano podem ser usados como método, mas os artefatos gerados devem ficar no mesmo diretório de feature usado pelo Spec Kit.
   - Brainstorming vendorizado: quando este fluxo exigir brainstorming, carregue e siga `C:\Users\imale\.codex\vendor_imports\.agents\skills\brainstorming\SKILL.md`; não dependa de `brainstorming` como skill global.
   - Bloqueio: quando não houver Spec Kit inicializado, siga `Dependência do Spec Kit`; não crie fallback local.
3. Execute o `Workflow Canônico` na ordem, usando brainstorming vendorizado apenas como técnica auxiliar antes ou durante `speckit-specify`/`speckit-plan`, sem substituir os comandos do Spec Kit.
4. Peça aprovação do usuário nos gates de spec, plan, tasks e readiness antes de avançar para a próxima fase relevante.
5. Após aprovação explícita do readiness gate, crie `.codex/web-dev/implementation-context.md` com `plan path: <caminho>` e invoque `$implement-tdd`.

## Handoff TDD

- O handoff para implementação deve preservar a separação entre Spec Kit/Superpowers e execução: `spec-flow` decide produto/arquitetura com o usuário; `$implement-tdd` escolhe especialistas, habilidades obrigatórias, worktrees e validação.
- Antes do handoff, registre no plano ou nas tasks qualquer pista de stack envolvida (ex.: Django/DRF, React/Vite, .NET/TUI, Go, Node, DOCX/PPTX) para impedir despacho por agente genérico.
- Se a mudança envolver uma stack sem especialista configurado, marque isso como risco no handoff em vez de deixar `$implement-tdd` reaproveitar `worker` automaticamente.
- Antes de criar `.codex/web-dev/implementation-context.md`, confirme que as tasks carregam um checklist de handoff com: stacks detectadas, agente esperado por stack, especialista ausente quando aplicável, fluxos manuais obrigatórios, validação mínima por stack, se o harness mecânico de skills deve ser ativado por `$implement-tdd`, `manual e2e required: <sim/não>`, `evidence path pattern`, `e2e checklist source`, `reviewer subagent required: <sim/não>` e `failure policy: any inconsistency between evidence and acceptance criteria fails`.

## E2E Evidence Gates

Quando a feature envolver UI/TUI, integração com terminal, janelas externas, automação desktop, filesystem persistido ou comportamento manual crítico, `spec-flow` deve exigir um gate E2E explícito. Esse gate não é obrigatório para mudanças triviais sem comportamento visual, interativo ou operacional relevante.

Antes de finalizar `spec.md`, classifique explicitamente a feature:

- `manual e2e required: yes`
- `manual e2e required: no`

Use `yes` quando houver UI ou TUI, integração com terminal, janelas externas, automação desktop, filesystem persistido relevante, integração com processo externo, comportamento manual crítico, fluxo visual/interativo ou qualquer comportamento que testes unitários/integrados não comprovem por si. Use `no` somente para mudança interna pequena, refactor sem alteração comportamental, ajuste documental ou função isolada coberta por testes automatizados.

Para features com gate E2E, a spec, o plano e as tasks devem conter:

- checklist E2E canônico com IDs estáveis, por exemplo `E2E-01`, `E2E-02`;
- diretório de evidências padronizado em `specs/<slug>/evidence/<run-id>/`;
- `e2e-report.md` com status, esperado, observado e links para evidências de cada item;
- screenshots, logs e snapshots quando aplicáveis ao comportamento validado;
- critério explícito de reprovação;
- revisão final por subagent revisor read-only;
- ciclo obrigatório de correção, testes automatizados, E2E manual executado por subagente no `$implement-tdd` e nova revisão quando a revisão reprovar.

Qualquer inconsistência entre critério de aceite e evidência reprova a implementação. Exemplos: evidência ausente, screenshot que não comprova o estado declarado, log contraditório, estado visual errado, metadados persistidos divergentes, comportamento manual crítico não demonstrado ou fluxo fallback não validado quando era requisito.

## Artefatos De Validação

Toda `spec.md` gerada ou atualizada pelo fluxo deve conter:

- `## Validacao`;
- `manual e2e required: yes/no`;
- critérios de aceite que mencionem testes automatizados, evidências, E2E por subagente quando aplicável, e revisão por subagente quando aplicável;
- `### Checklist E2E Obrigatorio` quando `manual e2e required: yes`.

Formato mínimo do checklist E2E:

```markdown
### Checklist E2E Obrigatorio

Cada item deve aparecer no `e2e-report.md` com status, esperado, observado e links para evidencias.

- `E2E-01`: <fluxo/estado crítico>
- `E2E-02`: <fluxo/estado crítico>
```

Todo `plan.md` deve conter `## Plano De Validacao` com:

- testes automatizados mínimos;
- comandos esperados;
- `manual e2e required: yes/no`;
- fonte do checklist E2E;
- padrão do diretório de evidências;
- política de reprovação;
- recursos/interfaces existentes que serão reutilizados;
- justificativa de qualquer recurso/interface nova.

Campos mínimos:

```markdown
Manual e2e required: yes/no
Evidence path pattern: `specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/`
E2E checklist source: `specs/<slug>/spec.md#checklist-e2e-obrigatorio` ou `specs/<slug>/e2e-checklist.md`
Reviewer subagent required: yes/no
Failure policy: any inconsistency between evidence and acceptance criteria fails
Existing resources/interfaces to reuse: <lista>
New resources/interfaces allowed only if justified: <justificativa ou `none`>
```

Toda `tasks.md` deve conter `## Validacao` com checklist executável. Inclua itens para testes automatizados mínimos, suíte ampla quando contratos compartilhados mudarem, criação do diretório de evidências, `e2e-report.md`, logs, screenshots quando aplicável, execução de cada `E2E-*`, revisão read-only por subagente, e ciclo de correção quando houver inconsistência.

Quando E2E for obrigatório, use este padrão mínimo de evidências:

```text
specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/
  e2e-report.md
  logs/
  screenshots/
  state-before.json
  state-after.json
```

Os nomes de logs e snapshots podem variar por feature, mas `e2e-report.md` é obrigatório; `logs/` é obrigatório; `screenshots/` é obrigatório quando houver UI/TUI/visual; snapshots antes/depois são obrigatórios quando houver estado persistido ou externo relevante.

O `e2e-report.md` deve usar tabela Markdown:

```markdown
| ID | Status | Esperado | Observado | Evidencias |
| --- | --- | --- | --- | --- |
| E2E-01 | pass/fail | ... | ... | screenshots/..., logs/... |
```

Nenhum item `E2E-*` pode ficar sem evidência.

## Readiness Gate

Antes de criar `.codex/web-dev/implementation-context.md` e invocar `$implement-tdd`, confirme:

- `spec.md` tem `## Validacao`, classificação `manual e2e required: yes/no`, critérios de aceite coerentes e checklist E2E quando obrigatório;
- `plan.md` tem `## Plano De Validacao`, comandos, fonte do checklist E2E, evidências, reviewer subagent, failure policy e preferência por recursos/interfaces existentes;
- `tasks.md` tem `## Validacao` com checklist executável e cada item E2E obrigatório;
- o handoff contém `manual e2e required`, `evidence path pattern`, `e2e checklist source`, `reviewer subagent required`, `failure policy`, recursos/interfaces existentes a reutilizar e justificativa de qualquer criação nova;
- nenhuma feature interativa, visual, operacional ou manual crítica sai do `spec-flow` sem contrato de evidência e revisão.

## Gates

- Não escreva código de produção antes da aprovação das tasks.
- Tasks não podem ser consideradas concluídas sem aprovação explícita das tasks.
- Não despache agentes write-capable diretamente por este skill; use `$implement-tdd` para matriz, worktrees, TDD, revisão e integração.
- Implementação não pode ser considerada concluída sem testes automatizados, E2E obrigatório e revisão de evidências aprovada quando a feature exigir gate E2E.
- Se já houver artefatos relevantes, retome do próximo gate incompleto em vez de duplicar.
- Se houver ambiguidade real ou risco de sobrescrever trabalho, pare e pergunte.

## Artefatos

Use um único diretório de feature para todos os artefatos do fluxo, independente de o raciocínio vir de Spec Kit ou Superpowers. Prefira sempre o diretório da feature criado pelo Spec Kit.

- `.specify/memory/input_constitution.md`, gerado por `$constitution-input`
- `.specify/memory/constitution.md`, atualizado pelo constitution do Spec Kit
- `specs/<slug>/brainstorm.md`
- `specs/<slug>/spec.md`
- `specs/<slug>/plan.md`
- `specs/<slug>/tasks.md`
- `specs/<slug>/e2e-checklist.md`, opcional quando o checklist E2E for extenso demais para ficar legível dentro da spec
- `specs/<slug>/evidence/<run-id>/`, saída de validação E2E; não trate como spec editável

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
- manual e2e required: <sim/não; obrigatório para frontend, full-stack, UI/TUI, integração com terminal, janelas externas, automação desktop, filesystem persistido ou comportamento manual crítico>
- evidence path pattern: <ex.: specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/>
- e2e checklist source: <spec.md#... ou e2e-checklist.md>
- reviewer subagent required: <sim/não; sim quando `manual e2e required` for `sim`>
- failure policy: any inconsistency between evidence and acceptance criteria fails
- user-facing flows to verify manually: <fluxos/casos de uso que devem ser testados no navegador>
- minimum validation by stack: <pilha -> comando(s) de validação>
- existing resources/interfaces to reuse: <componentes, APIs, schemas, helpers, fixtures, estilos, comandos e padrões existentes>
- new resources/interfaces allowed only if justified: <justificativas aprovadas ou `none`>
- <outras restrições importantes>
```
