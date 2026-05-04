---
name: scopus-writer-plan
description: Plan academic writing from local Scopus/PDF pgvector evidence without drafting the final text. Use when the user invokes `$scopus-writer-plan` or asks for an evidence-backed plan, outline, query plan, or source-use plan before writing.
---

# Scopus Writer Plan

Use this skill to create only the writing plan. Do not draft the final academic text.

Unless the user requests another language, write the plan in Brazilian Portuguese.

## Required Inputs

Require:

- explicit base collection;
- writing task, such as paragraph, section, introduction, theoretical background, discussion, literature review, justification, objective, or subsection;
- topic, problem, claim, or outline.

If the collection is missing, list collections with:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py list-collections
```

## Workflow

1. Decompose the writing task into 2 to 5 evidence needs.
2. Propose a concise structure for the requested text.
3. Generate English semantic queries for each evidence need.
4. Search `<collection>` first and `<collection>_pdf` when full-text support is needed.
5. Classify candidate evidence as `core`, `applied`, `adjacent`, or `reject`.
6. Return a plan that maps evidence needs to sources and intended claims.

Use only:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py search --collection <collection> --query "<english query>" --original-query "<writing need>" --top-k 5
```

## Output

Return only:

- proposed structure;
- evidence needs;
- English query plan;
- searched collections;
- candidate sources with compact evidence notes;
- source-use plan for each paragraph or subsection;
- gaps or cautions.

Do not write the final text and do not format final references.
