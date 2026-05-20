# Plano por arquivos-alvo do docx-utils

Data: 2026-05-15
Branch: `fix/docx-utils-tabelauerj-test-baseline`

## Pacote 1: `src/DocxOpenXmlTools/Cli/CliOptions.cs`

- Origem: funcoes compartilhadas de `Program.cs`.
- Conteudo: `IsHelpArgument`, `Parse`, `IsTrue`, `JsonOptions`, `JsonOptionsIndented`.
- Testes de caracterizacao: testes existentes de help, plan-contracts, validate-plan e comments.
- Validacao alvo: `dotnet test src\DocxOpenXmlTools.Tests\DocxOpenXmlTools.Tests.csproj --configuration Release`.
- Dependencias: nenhuma.
- Risco de conflito: baixo; altera chamadas pontuais em `Program.cs`.
- Criterio de pronto: suite completa verde e contrato externo inalterado.

## Pacote 2: `src/DocxOpenXmlTools/Mutation/MutationAuthorResolver.cs`

- Origem: `DefaultMutationAuthors` e `ResolveMutationAuthor`.
- Conteudo: selecao automatica de autor para comandos mutadores.
- Testes de caracterizacao: `Mutating_command_without_author_uses_next_available_default_author` e `Mutating_command_with_explicit_author_preserves_author_even_when_existing`.
- Validacao alvo: filtro desses dois testes e suite completa.
- Dependencias: Pacote 1 opcional.
- Risco de conflito: medio, porque muitos comandos chamam o resolvedor.
- Criterio de pronto: autoria automatica e explicita preservadas.

## Pacote 3: `src/DocxOpenXmlTools/PlanContracts/PlanContractCommands.cs`

- Origem: roteamento especial de `plan-contracts` e `ValidatePlan`.
- Conteudo: comandos sem DOCX, validacao de plano e impressao de contratos.
- Testes obrigatorios antes da extracao: formato invalido, contrato desconhecido, `--plan` ausente e arquivo de plano inexistente.
- Validacao alvo: testes `Plan_contracts*` e `Validate_plan*`.
- Dependencias: Pacote 1.
- Risco de conflito: baixo a medio.
- Criterio de pronto: stdout/stderr/exit code preservados.

## Pacote 4: `src/DocxOpenXmlTools/Comments/CommentCommands.cs`

- Origem: listagem e mutacoes de comentarios em `Program.cs`.
- Conteudo: `comments`, `comment-anchors`, `insert-comments`, `reanchor-comments`, `answer-comments`, `reply-comments`, `remove-comments`.
- Testes obrigatorios antes da extracao: formato invalido, `comment-anchors` happy path, erro de plano ausente em uma mutacao.
- Validacao alvo: todos os testes de comments e autoria.
- Dependencias: Pacotes 1 e 2.
- Risco de conflito: medio, por usar modelos e helpers Open XML compartilhados.
- Criterio de pronto: formatos `json`, `markdown`, `raw`, `auto` e autoria preservados.

## Pacote 5: `src/DocxOpenXmlTools/Blocks/BlockMutationCommands.cs`

- Origem: `insert-tracked`, `insert-blocks`, `replace-blocks`, `edit-paragraphs`, `append-paragraphs`.
- Conteudo: mutacoes por blocos e paragrafos.
- Testes obrigatorios antes da extracao: mutacao `insert-blocks` happy path e erro de ancora ausente/ordem invalida.
- Validacao alvo: `ReplaceBlocks_between_anchors_removes_old_content_and_inserts_table`, `validate-plan insert-blocks`, `validate-plan replace-blocks`.
- Dependencias: Pacotes 1 e 2.
- Risco de conflito: alto; integrar em fila.
- Criterio de pronto: DOCX, relatorio e stdout preservados.

## Pacote 6: `src/DocxOpenXmlTools/Tables/TableCommands.cs`

- Origem: `replace-table`, `apply-table-design-style` e helpers de tabela.
- Conteudo: seletores, substituicao de linhas e preservacao de estilos.
- Testes obrigatorios antes da extracao: seletor nao encontrado e seletor ambiguo.
- Validacao alvo: `ReplaceTable_by_ordinal_preserves_table_and_cell_styles`, `validate-plan replace-table`.
- Dependencias: Pacotes 1 e 2; pode depender de helpers extraidos do Pacote 5.
- Risco de conflito: alto; integrar em fila.
- Criterio de pronto: estilo `tabelauerj`, estilos de celulas, relatorio e stdout preservados.

## Pacotes posteriores

- `src/DocxOpenXmlTools/Figures/FigureCommands.cs`: requer caracterizacao de `insert-figures` e `replace-figures-from-plan`.
- `src/DocxOpenXmlTools/Math/FormulaCommands.cs`: requer caracterizacao de auditorias math, LaTeX, MathML e alias legado.
- `src/DocxOpenXmlTools/Styles/StyleCommands.cs`: requer caracterizacao de estilos canonicos e sincronizacao.
- `src/DocxOpenXmlTools/Layout/LayoutRepairCommands.cs`: requer caracterizacao de reparos ABNT/layout.
- `src/DocxOpenXmlTools/Crossrefs/CrossrefCommands.cs`: requer caracterizacao de bookmarks, REF fields e reparos de referencias.

