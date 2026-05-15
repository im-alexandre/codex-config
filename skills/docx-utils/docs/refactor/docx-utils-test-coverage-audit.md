# Auditoria de cobertura dos testes do docx-utils

Data: 2026-05-15
Branch: `fix/docx-utils-tabelauerj-test-baseline`

## Resumo

A suite atual em `src/DocxOpenXmlTools.Tests/DocxOpenXmlToolsCliTests.cs` cobre mais do que happy path. Ha caracterizacao de `help`, `plan-contracts`, `validate-plan`, autoria automatica, formatos de `comments`, `replace-table`, `replace-blocks`, `create-article`, `create-docx` e `validate`.

A lacuna principal e que muitos comandos expostos no `switch` de `Program.cs` nao possuem teste de contrato dedicado. Para esses comandos, a decisao desta auditoria e nao bloquear a primeira extracao de infraestrutura CLI, mas exigir caracterizacao antes de extrair o dominio funcional correspondente.

O baseline vermelho observado antes da auditoria era `ReplaceTable_by_ordinal_preserves_table_and_cell_styles`: o teste esperava `TabelaOriginal`, enquanto o comportamento atual usa `tabelauerj`. A decisao aplicada nesta branch foi alinhar fixture e expectativa para `tabelauerj`, mantendo o teste como verificacao de preservacao de estilo de tabela.

## Matriz por comando

| comando | testes atuais | cobre happy path | cobre erro | cobre contrato externo | lacuna | decisao |
| --- | --- | --- | --- | --- | --- | --- |
| `help`, `--help`, `-h`, `/?` | `Help_and_dashdashhelp_emit_the_same_usage_text_with_plan_examples` | sim | parcial | stdout e exemplos | aliases `-h` e `/?` nao comparados diretamente | suficiente para extracao CLI inicial |
| comando desconhecido | `ListAuthors_is_not_exposed_in_cli_usage` | nao | sim | exit code 3, stderr/stdout | nao ha teste generico para comando arbitrario | suficiente para extracao CLI inicial |
| docx inexistente | nenhum dedicado | nao | nao | exit code 2 e stderr | contrato sem teste | adicionar antes de refatorar roteamento completo |
| argumento ausente | testes indiretos por help/create-docx | parcial | parcial | exit code 1 | faltam casos por comando | adicionar quando extrair dispatcher |
| `plan-contracts` | `Plan_contracts_command_exposes_markdown_and_json_without_docx` | sim | nao | markdown/json stdout | formato invalido e contrato desconhecido sem teste | caracterizar antes de mover comandos de planos |
| `validate-plan` | `Validate_plan_reports_actionable_errors_for_invalid_contracts`, `Validate_plan_accepts_minimal_supported_contracts` | sim | sim | exit code, stderr, stdout | falta `--plan` ausente e arquivo inexistente | bom candidato inicial depois de CLI |
| `create-article` | `Create_article_command_matches_article_builder_behavior` | sim | nao | delegacao e conteudo DOCX | erros do builder nao cobertos | manter sem extrair ate precisar |
| `create-docx` | `Create_docx_without_plan_creates_empty_valid_document`, `Create_docx_with_plan_renders_title_paragraphs_and_sections`, `validate-plan create-docx` | sim | sim por contrato | DOCX gerado e validacao | plano inexistente nao testado | ja esta parcialmente extraido em `CreateDocxSupport` |
| `validate` | `Validate_reports_no_openxml_errors_for_minimal_generated_docx` | sim | nao | stdout de validacao | DOCX invalido/inexistente so pelo roteador | suficiente para nao tocar agora |
| `paragraphs` | nenhum dedicado | nao | nao | stdout | sem cobertura | caracterizar antes de extrair inspecao |
| `paragraph-detail` | nenhum dedicado | nao | nao | stdout/stderr | sem cobertura | caracterizar antes de extrair inspecao |
| `structure-audit` | nenhum dedicado | nao | nao | JSON/stdout/arquivo | sem cobertura | caracterizar antes de extrair auditorias |
| `layout-audit` | nenhum dedicado | nao | nao | JSON/Markdown | sem cobertura | caracterizar antes de extrair auditorias |
| `equations-audit` | nenhum dedicado | nao | nao | JSON | sem cobertura | caracterizar antes de extrair math |
| `math-audit` | nenhum dedicado | nao | nao | JSON | sem cobertura | caracterizar antes de extrair math |
| `math-text-audit` | nenhum dedicado | nao | nao | JSON | sem cobertura | caracterizar antes de extrair math |
| `linear-equation-plan-preview` | nenhum dedicado | nao | nao | HTML/arquivo | sem cobertura | caracterizar antes de extrair math |
| `revisions` | nenhum dedicado | nao | nao | stdout | sem cobertura | caracterizar antes de extrair revisoes |
| `comments` | cinco testes de formatos e filtro | sim | parcial | json, markdown, raw, table, auto | formato invalido sem teste | bom candidato para extracao apos CLI/planos |
| `comment-anchors` | nenhum dedicado | nao | nao | stdout | sem cobertura | adicionar antes de extrair comentarios completo |
| `insert-comments` | testes indiretos por autoria automatica/explicita | sim | nao | mutacao DOCX e autor | plano ausente/invalido sem teste | caracterizar antes de extrair mutacoes de comentarios |
| `reanchor-comments` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair comentarios completo |
| `answer-comments` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair comentarios completo |
| `reply-comments` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair comentarios completo |
| `remove-comments` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair comentarios completo |
| `insert-tracked` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair blocos |
| `insert-blocks` | `validate-plan` cobre contrato; sem mutacao direta | parcial | sim por contrato | contrato JSON | mutacao DOCX nao testada diretamente | adicionar antes de extrair blocos |
| `replace-blocks` | `ReplaceBlocks_between_anchors_removes_old_content_and_inserts_table`, `validate-plan` | sim | sim por contrato | DOCX, stdout, relatorio | erro de ancora ausente sem teste | candidato depois de CLI/planos |
| `edit-paragraphs` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair blocos |
| `append-paragraphs` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair blocos |
| `replace-table` | `ReplaceTable_by_ordinal_preserves_table_and_cell_styles`, `validate-plan` | sim | sim por contrato | DOCX, stdout, relatorio, estilos | seletores ambiguos/nao encontrados sem teste | candidato depois de blocos |
| `apply-table-design-style` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | caracterizar antes de extrair tabelas |
| `rewrite-equation-blocks` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase math |
| `format-equation-paragraphs` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase math |
| `replace-formulas-with-linear-equations` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase math |
| `replace-formulas-with-mathml-omml` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase math |
| `convert-text-formulas-to-omath` | nenhum dedicado | nao | nao | alias legado/stderr | sem cobertura | caracterizar antes de extrair math |
| `replace-figures-from-plan` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase figuras |
| `insert-figures` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase figuras |
| `export-used-styles` | nenhum dedicado | nao | nao | arquivos exportados | sem cobertura | deixar para fase estilos |
| `ensure-canonical-styles` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase estilos |
| `sync-styles-from-docx` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase estilos |
| `style-running-text` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase estilos |
| `ensure-style-fonts` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase estilos |
| `normalize-figure-indent` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase layout/figuras |
| `enable-update-fields-on-open` | nenhum dedicado | nao | nao | settings DOCX/relatorio | sem cobertura | caracterizar antes de extrair settings |
| `disable-update-fields-on-open` | nenhum dedicado | nao | nao | settings DOCX/relatorio | sem cobertura | caracterizar antes de extrair settings |
| `repair-article-abnt-layout` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase layout/ABNT |
| `format-abnt-reference-titles` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase layout/ABNT |
| `apply-crossrefs` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase crossrefs |
| `add-bookmarks` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase crossrefs |
| `rewrite-ref-fields` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase crossrefs |
| `repair-style-captions` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase layout/crossrefs |
| `repair-layout-pendencies` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase layout |
| `repair-ref-number-only` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio | sem cobertura | deixar para fase crossrefs |
| `accept-revisions` | nenhum dedicado | nao | nao | mutacao DOCX/relatorio/stdout | sem cobertura | caracterizar antes de extrair finalizacao |

## Decisao para a primeira extracao

A primeira extracao deve ser pequena e de baixo risco: criar `src/DocxOpenXmlTools/Cli/CliOptions.cs` para centralizar:

- reconhecimento de argumentos de ajuda;
- parsing de opcoes `--chave valor`;
- leitura de flags booleanas;
- opcoes JSON compartilhadas.

Essa extracao fica coberta por testes existentes de `help`, `plan-contracts`, `validate-plan`, `comments --format auto` e comandos que desserializam planos. Ela nao muda contrato externo e prepara o `Program.cs` para extracoes posteriores.
