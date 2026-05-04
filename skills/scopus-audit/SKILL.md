---
name: scopus-audit
description: Use only when the user explicitly includes the exact command `$scopus-audit`. Export evidence, review, and writing matrices from local Scopus/PDF pgvector collections; do not trigger for generic audit, diagnostics, matrix, debug, or evidence-report requests without `$scopus-audit`.
---

# Scopus Audit

Use this skill only when the user explicitly invokes `$scopus-audit`.

This skill exports audit matrices. It does not write final prose and does not replace the internal quality checks of `scopus-writer`, `scopus-review`, or `scopus-academic-pipeline`.

## Required Inputs

Require:

- explicit base collection;
- text, claim list, writing task, outline, or generated draft to audit;
- audit target: review matrix, writing evidence matrix, or pipeline evidence matrix.

If the collection is missing, list collections with:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py list-collections
```

## Retrieval

Use only `index-kit`:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py search --collection <collection> --query "<english query>" --original-query "<claim or need>" --top-k 5
```

Search `<collection>` first, then `<collection>_pdf` when available. For audit mode, search both collections when the claim or writing need requires full-text support.

## Matrix Contract

Return a concise Markdown table or JSON-like matrix with:

- claim, paragraph, or writing need;
- generated English queries;
- searched collections;
- selected evidence;
- evidence classification: `core`, `applied`, `adjacent`, or `reject`;
- support judgment: `supported`, `partially supported`, `weak support`, or `unsupported`;
- revised or proposed wording;
- cited reference metadata.

Do not dump raw chunks unless the user explicitly requests raw evidence.
