# Smoke operacional docx-utils

Data: 2026-05-15

## Artefatos

- DOCX principal: `artifacts/manual-smoke/smoke-main.docx`
- DOCX de artigo: `artifacts/manual-smoke/smoke-article.docx`
- Planos JSON: `artifacts/manual-smoke/plans/`
- Relatorios gerados por comandos: `artifacts/manual-smoke/reports/`

## Fluxo executado

O smoke usou chamadas diretas ao binario publicado `bin/docx-utils/docx-utils.exe`.

1. Criou um DOCX real do zero com `create-docx --plan`.
2. Validou o DOCX com `validate`.
3. Consultou contratos com `plan-contracts`.
4. Validou planos com `validate-plan`.
5. Testou autoria com `next-author`.
6. Inseriu, listou, reancorou, respondeu e removeu comentarios.
7. Inseriu revisao rastreada com `insert-tracked`.
8. Inseriu blocos e tabela com `insert-blocks`.
9. Substituiu intervalo com `replace-blocks`.
10. Acrescentou paragrafo com `append-paragraphs`.
11. Editou paragrafo com `edit-paragraphs`.
12. Aplicou estilo de tabela e substituiu tabela com `apply-table-design-style` e `replace-table`.
13. Inseriu, substituiu e normalizou figura com `insert-figures`, `replace-figures-from-plan` e `normalize-figure-indent`.
14. Gerou preview de equacao e converteu formulas com `linear-equation-plan-preview`, `replace-formulas-with-linear-equations` e `convert-text-formulas-to-omath`.
15. Reescreveu bloco de equacao e formatou equacoes.
16. Criou bookmarks e crossrefs.
17. Rodou comandos de estilo/layout e comandos academicos.
18. Rodou auditorias estruturais, layout, equacoes, math e revisoes.
19. Removeu comentarios e aceitou revisoes.

## Passou com exit code 0

- `create-docx --plan`
- `validate` inicial
- `plan-contracts --format markdown`
- `plan-contracts create-docx --format json`
- `validate-plan create-docx`
- `validate-plan insert-blocks`
- `validate-plan replace-blocks`
- `validate-plan replace-table`
- `next-author`
- `insert-comments`
- `comments --format json`
- `comments --format markdown`
- `comment-anchors`
- `reanchor-comments` depois de ajustar o plano para `commentId=1`
- `answer-comments` depois de ajustar o plano para `commentId=1`
- `insert-tracked`
- `insert-blocks`
- `replace-blocks`
- `append-paragraphs`
- `edit-paragraphs`
- `ensure-canonical-styles`
- `apply-table-design-style`
- `replace-table`
- `insert-figures`
- `replace-figures-from-plan`
- `normalize-figure-indent`
- `linear-equation-plan-preview`
- `replace-formulas-with-linear-equations`
- `convert-text-formulas-to-omath`
- `rewrite-equation-blocks`
- `format-equation-paragraphs`
- `create-article`
- `create-docx` para documento fonte de estilos
- `sync-styles-from-docx`
- `enable-update-fields-on-open`
- `disable-update-fields-on-open`
- `repair-layout-pendencies`
- `structure-audit`
- `layout-audit`
- `equations-audit`
- `math-audit`
- `revisions`
- `remove-comments`
- `accept-revisions`
- `comments --format json` final

## Passou com skips operacionais

- `reply-comments`: retornou exit code 0, mas `SKIP reply-1: parent comment id=1 has no paraId`.
- `repair-style-captions`: retornou exit code 0, mas `SKIP caption-1: style numbering not found after repair`.

## Falhou ou expôs erro real

- `style-running-text`: retornou exit code 8 depois de aplicar mudancas; reportou `VALIDATION_ERRORS 8`.
- `ensure-style-fonts`: retornou exit code 6 com `Document has no style definitions part`.
- `repair-article-abnt-layout`: retornou exit code 9 em documento sintetico, com varios skips de tabelas/captions esperadas do artigo alvo.
- `format-abnt-reference-titles`: retornou exit code 9 em documento sintetico, com referencias alvo nao encontradas.
- `math-text-audit`: encerrou com excecao nao tratada `RegexParseException` no padrao de letras gregas.
- `export-used-styles`: encerrou com excecao nao tratada `InvalidOperationException: StyleDefinitionsPart not found`.

## Validacao final

`validate` final retornou exit code 0, sem revisoes pendentes, mas com 3 erros Open XML acionaveis:

- `w:pPr` com filho inesperado `w:tabs`.
- atributo `w15:paraId` nao declarado em um paragrafo.
- atributo `w15:textId` nao declarado em um paragrafo.

O DOCX final ficou sem comentarios (`comments --format json` retornou lista vazia) e sem `InsertedRuns`/`DeletedRuns` apos `accept-revisions`.

