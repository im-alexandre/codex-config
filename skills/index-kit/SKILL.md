---
name: index-kit
description: List, inspect, preview, retrieve, and semantically search local Scopus/PDF PostgreSQL/pgvector collections. Use when the user invokes `$index-kit`, wants to search a collection, inspect collection stats, list collections, preview PDF chunks, or retrieve indexed PDF sections. For direct indexing commands, use `$index-file` or `$index-dir`.
---

# Index Kit

Use this skill as the canonical local pgvector interface for collection search, inspection, preview, and retrieval.

Run the deterministic wrapper:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py <subcommand> ...
```

## Commands

List collections:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py list-collections
```

Search:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py search --collection revisao --query "hierarchical forecasting" --top-k 5
```

When the user asks in another language, translate the retrieval intent to English and pass the original text:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py search --collection revisao --query "hierarchical forecasting" --original-query "previsao hierarquica" --top-k 5
```

Index one file:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.ris
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.csv
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-file --collection revisao D:\fontes\a.pdf
```

`index-file` selects behavior by suffix:

- `.ris`: index RIS records into `<collection>`.
- `.csv`: index Scopus CSV records into `<collection>`.
- `.pdf`: index PDF chunks into `<collection>_pdf`, unless the provided collection already ends with `_pdf`.

Index a directory:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py index-dir --collection revisao --dir D:\fontes
```

`index-dir` is recursive and always indexes in this order:

1. all `.ris` files;
2. all `.csv` files;
3. all `.pdf` files.

Inspect a collection:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py stats --collection revisao
```

Preview PDF chunks:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py chunk D:\fontes\a.pdf --method header
```

Retrieve indexed PDF structure or section:

```powershell
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py structure "a.pdf" --collection revisao_pdf
python C:\Users\imale\.codex\skills\index-kit\scripts\index_kit.py section "a.pdf" --collection revisao_pdf --pages 3-5
```

## Rules

- There is no default collection. Ask for one when missing.
- Use only PostgreSQL/pgvector.
- Do not use Chroma.
- Keep Scopus records in `<collection>` and PDFs in `<collection>_pdf`.
- Prefer Scopus metadata for references and PDF chunks for deeper textual support.
- For searches, show the English query actually used when it differs from the user's original wording.

## Runtime Defaults

- `--postgres-dsn postgresql://rag:rag@localhost:5432/ragdb`
- `--ollama-url http://localhost:11434`
- `--model nomic-embed-text:latest`
- `--workers 10`
