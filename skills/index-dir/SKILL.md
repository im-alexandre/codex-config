---
name: index-dir
description: Recursively index a directory of local Scopus RIS/CSV exports and PDF files into PostgreSQL/pgvector. Use when the user invokes `$index-dir` or asks to index a folder/directory into a local collection.
---

# Index Dir

Use this skill for directory indexing requests.

Run the deterministic Index Kit wrapper:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-dir --collection revisao --dir D:\fontes
```

## Behavior

`index-dir` is recursive and always indexes in this order:

1. all `.ris` files;
2. all `.csv` files;
3. all `.pdf` files.

## Rules

- There is no default collection. Ask for one when missing.
- There is no default directory path. Ask for one when missing.
- Use only PostgreSQL/pgvector.
- Do not use Chroma.
- Keep Scopus records in `<collection>` and PDFs in `<collection>_pdf`.

## Runtime Defaults

- `--postgres-dsn postgresql://rag:rag@localhost:5432/ragdb`
- `--ollama-url http://localhost:11434`
- `--model nomic-embed-text:latest`
- `--workers 10`
