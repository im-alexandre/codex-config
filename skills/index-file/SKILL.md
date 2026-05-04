---
name: index-file
description: Index one local Scopus RIS/CSV export or PDF file into PostgreSQL/pgvector. Use when the user invokes `$index-file` or asks to index a single `.ris`, `.csv`, or `.pdf` file into a local collection.
---

# Index File

Use this skill for single-file indexing requests.

Run the deterministic Index Kit wrapper:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.ris
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.csv
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.pdf
```

## Behavior

- `.ris`: index RIS records into `<collection>`.
- `.csv`: index Scopus CSV records into `<collection>`.
- `.pdf`: index PDF chunks into `<collection>_pdf`, unless the provided collection already ends with `_pdf`.

## Rules

- There is no default collection. Ask for one when missing.
- There is no default file path. Ask for one when missing.
- Use only PostgreSQL/pgvector.
- Do not use Chroma.
- Keep Scopus records in `<collection>` and PDFs in `<collection>_pdf`.

## Runtime Defaults

- `--postgres-dsn postgresql://rag:rag@localhost:5432/ragdb`
- `--ollama-url http://localhost:11434`
- `--model nomic-embed-text:latest`
- `--workers 10`
