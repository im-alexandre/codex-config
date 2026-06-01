1. Adicionar decisão obrigatória de Gate E2E

No fluxo do spec-flow, incluir uma etapa antes de finalizar spec.md:

- Classificar a feature como:
  - manual e2e required: yes
  - manual e2e required: no

Critério para yes:

- UI ou TUI;
- integração com terminal;
- janelas externas;
- automação desktop;
- filesystem persistido relevante;
- integração com processo externo;
- comportamento manual crítico;
- fluxo visual ou interativo que testes unitários não comprovam.

Critério para no:

- mudança interna pequena;
- refactor sem alteração comportamental;
- ajuste puramente documental;
- função isolada coberta por testes automatizados.

2. Atualizar template obrigatório de spec.md

Toda spec.md gerada pelo spec-flow deve conter:

- seção ## Validacao;
- seção ### Checklist E2E Obrigatorio quando manual e2e required: yes;
- critérios de aceite que mencionem explicitamente:
  - testes automatizados;
  - E2E manual, quando aplicável;
  - evidências;
  - revisão por subagent, quando aplicável.

Formato mínimo do checklist:

### Checklist E2E Obrigatorio

Cada item deve aparecer no `e2e-report.md` com status, esperado, observado e links para evidencias.

- `E2E-01`: ...
- `E2E-02`: ...

3. Atualizar template obrigatório de plan.md

Todo plan.md deve ter uma seção ## Plano De Validacao com:

- testes automatizados mínimos;
- comandos esperados;
- se há E2E manual obrigatório;
- fonte do checklist E2E;
- padrão do diretório de evidências;
- política de reprovação.

Exemplo:

Manual e2e required: yes
Evidence path pattern: `specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/`
E2E checklist source: `specs/<slug>/spec.md#checklist-e2e-obrigatorio`
Reviewer subagent required: yes
Failure policy: any inconsistency between evidence and acceptance criteria fails

4. Atualizar template obrigatório de tasks.md

Toda tasks.md deve incluir uma seção de validação com checklist executável:

## Validacao

- [ ] Rodar testes automatizados mínimos.
- [ ] Rodar suíte ampla quando contratos compartilhados mudarem.
- [ ] Criar diretório de evidências `specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/`.
- [ ] Criar `e2e-report.md`.
- [ ] Capturar logs relevantes.
- [ ] Capturar screenshots quando aplicável.
- [ ] Executar `E2E-01`.
- [ ] Executar `E2E-02`.
- [ ] Subagent revisor read-only revisa evidências.
- [ ] Se houver inconsistência, reprovar e repetir correção + testes + E2E + revisão.

5. Padronizar estrutura de evidências

Quando E2E for obrigatório, o spec-flow deve exigir:

specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/
e2e-report.md
logs/
app.log
daemon.log
cli.log
screenshots/
\*.png
state-before.json
state-after.json

Os nomes podem ser adaptados por feature, mas o padrão mínimo deve ser:

- e2e-report.md;
- logs/;
- screenshots/, quando houver UI/TUI/visual;
- snapshots de estado antes/depois, quando houver estado persistido ou externo.

6. Definir formato obrigatório do e2e-report.md

O relatório deve conter uma tabela assim:

┌────────┬───────────┬──────────┬───────────┬───────────────────────────┐
│ ID │ Status │ Esperado │ Observado │ Evidencias │
├────────┼───────────┼──────────┼───────────┼───────────────────────────┤
│ E2E-01 │ pass/fail │ ... │ ... │ screenshots/..., logs/... │
└────────┴───────────┴──────────┴───────────┴───────────────────────────┘

Regra: nenhum item E2E-\* pode ficar sem evidência.

Quando manual e2e required: yes:

- o revisor deve ser read-only;
- deve aprovar ou reprovar;
- qualquer inconsistência reprova.

8. Política de reprovação obrigatória

Adicionar à skill:

Failure policy: any inconsistency between evidence and acceptance criteria fails.

Exemplos de reprovação:

- screenshot não comprova o estado declarado;
- log contradiz o relatório;
- fallback exigido não demonstrado;
- comportamento crítico validado só por afirmação textual.

O contexto gerado por spec-flow deve sempre incluir:

- manual e2e required: yes/no
- evidence path pattern: specs/<slug>/evidence/<YYYYMMDD-HHMMSS>/
- e2e checklist source: <spec.md ou e2e-checklist.md>
- reviewer subagent required: yes/no
- failure policy: any inconsistency between evidence and acceptance criteria fails

10. Gate final do spec-flow

Antes de chamar $implement-tdd, o spec-flow deve verificar:

- spec.md tem critérios de aceite coerentes;
- plan.md tem plano de validação;
  Resultado esperado: nenhuma feature interativa/manual crítica sai do spec-flow sem contrato de evidência e revisão.
