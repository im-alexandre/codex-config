from __future__ import annotations

import argparse
import contextlib
import io
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

import pdf_pgvector
import scopus_pgvector

DEFAULT_POSTGRES_DSN = "postgresql://rag:rag@localhost:5432/ragdb"
DEFAULT_OLLAMA_URL = "http://localhost:11434"
DEFAULT_MODEL = "nomic-embed-text:latest"
DEFAULT_TIMEOUT = 180
DEFAULT_WORKERS = 10
DEFAULT_TOP_K = 5


def _json_print(payload: Any) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2, default=str))


def _clean(value: Any) -> str:
    return str(value or "").strip()


def _require_collection(args: argparse.Namespace) -> str:
    collection = _clean(getattr(args, "collection", None))
    if not collection:
        raise ValueError("Informe --collection explicitamente.")
    return collection


def _pdf_collection(collection: str) -> str:
    return collection if collection.casefold().endswith("_pdf") else f"{collection}_pdf"


def _related_collection(collection: str) -> str | None:
    return None if collection.casefold().endswith("_pdf") else collection


def _pg_parts(dsn: str) -> dict[str, Any]:
    parsed = urlparse(dsn)
    if parsed.scheme not in {"postgresql", "postgres"}:
        raise ValueError(f"DSN PostgreSQL invalido: {dsn}")
    return {
        "pg_user": unquote(parsed.username or "rag"),
        "pg_password": unquote(parsed.password or "rag"),
        "pg_host": parsed.hostname or "localhost",
        "pg_port": parsed.port or 5432,
        "pg_database": unquote((parsed.path or "/ragdb").lstrip("/") or "ragdb"),
    }


def _pdf_common_args(args: argparse.Namespace) -> list[str]:
    pg = _pg_parts(args.postgres_dsn)
    return [
        "--backend",
        "pgvector",
        "--ollama-url",
        args.ollama_url,
        "--model",
        DEFAULT_MODEL,
        "--timeout",
        str(args.timeout),
        "--workers",
        str(args.workers),
        "--pg-user",
        pg["pg_user"],
        "--pg-password",
        pg["pg_password"],
        "--pg-host",
        pg["pg_host"],
        "--pg-port",
        str(pg["pg_port"]),
        "--pg-database",
        pg["pg_database"],
    ]


def _invoke_json(func, argv: list[str]) -> tuple[int, dict[str, Any]]:
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        code = int(func(argv) or 0)
    text = stream.getvalue().strip()
    if not text:
        return code, {}
    try:
        return code, json.loads(text)
    except json.JSONDecodeError:
        return code, {"raw_output": text}


def _register_collection(
    args: argparse.Namespace,
    name: str,
    kind: str,
    related_collection: str | None,
    metadata: dict[str, Any],
) -> None:
    parts = _pg_parts(args.postgres_dsn)
    ns = argparse.Namespace(
        pg_user=parts["pg_user"],
        pg_password=parts["pg_password"],
        pg_host=parts["pg_host"],
        pg_port=parts["pg_port"],
        pg_database=parts["pg_database"],
    )
    conn, _ = pdf_pgvector._connect_pg(ns, {})
    try:
        pdf_pgvector._ensure_pg_schema(conn)
        pdf_pgvector._ensure_collection_registration(
            conn,
            name,
            kind,
            related_collection,
            metadata,
        )
        conn.commit()
    finally:
        conn.close()


def _run_pdf(args: argparse.Namespace, command: str, extra: list[str]) -> tuple[int, dict[str, Any]]:
    return _invoke_json(pdf_pgvector.main, [command, *_pdf_common_args(args), *extra])


def _run_scopus(args: argparse.Namespace, command: str, extra: list[str]) -> tuple[int, dict[str, Any]]:
    return _invoke_json(
        scopus_pgvector.main,
        [
            "--postgres-dsn",
            args.postgres_dsn,
            "--ollama-url",
            args.ollama_url,
            "--model",
            DEFAULT_MODEL,
            "--timeout",
            str(args.timeout),
            command,
            *extra,
        ],
    )


def _handle_index_file(args: argparse.Namespace, raw_path: str | Path | None = None) -> dict[str, Any]:
    collection = _require_collection(args)
    path = Path(raw_path or args.path).resolve()
    if not path.is_file():
        return {"file": str(path), "error": "Arquivo nao encontrado"}
    suffix = path.suffix.casefold()
    if suffix in {".ris", ".csv"}:
        code, payload = _run_scopus(
            args,
            "index-files",
            ["--collection", collection, str(path)],
        )
        if code == 0:
            _register_collection(
                args,
                collection,
                "scopus",
                None,
                {"source": "index-kit", "last_indexed_file": str(path)},
            )
        payload["exit_code"] = code
        payload["file_type"] = suffix.lstrip(".")
        return payload
    if suffix == ".pdf":
        target = _pdf_collection(collection)
        related = _related_collection(collection)
        extra = ["--collection", target, str(path), "--method", args.method]
        if args.store_pdf is not None:
            extra.extend(["--store-pdf", args.store_pdf])
        code, payload = _run_pdf(args, "index-pdf", extra)
        if code == 0:
            _register_collection(
                args,
                target,
                "pdf",
                related,
                {
                    "source": "index-kit",
                    "requested_collection": collection,
                    "effective_collection": target,
                    "last_indexed_file": str(path),
                },
            )
        payload["exit_code"] = code
        payload["file_type"] = "pdf"
        payload["requested_collection"] = collection
        payload["effective_collection"] = target
        return payload
    return {"file": str(path), "error": "Tipo nao suportado; use .ris, .csv ou .pdf"}


def _handle_index_dir(args: argparse.Namespace) -> dict[str, Any]:
    _require_collection(args)
    directory = Path(args.dir).resolve()
    if not directory.is_dir():
        return {"directory": str(directory), "error": "Diretorio nao encontrado"}
    groups = [
        ("ris", sorted(directory.rglob("*.ris"), key=lambda item: str(item).casefold())),
        ("csv", sorted(directory.rglob("*.csv"), key=lambda item: str(item).casefold())),
        ("pdf", sorted(directory.rglob("*.pdf"), key=lambda item: str(item).casefold())),
    ]
    results: list[dict[str, Any]] = []
    for group, paths in groups:
        for path in paths:
            result = _handle_index_file(args, path)
            result.setdefault("order_group", group)
            results.append(result)
    return {
        "directory": str(directory),
        "order": ["ris", "csv", "pdf"],
        "matched_files": sum(len(paths) for _, paths in groups),
        "matched_by_type": {group: len(paths) for group, paths in groups},
        "results": results,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Index and search local RIS, CSV and PDF files with PostgreSQL/pgvector."
    )
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--collection")
    common.add_argument("--postgres-dsn", default=DEFAULT_POSTGRES_DSN)
    common.add_argument("--ollama-url", default=DEFAULT_OLLAMA_URL)
    common.add_argument("--model", default=DEFAULT_MODEL)
    common.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    common.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    common.add_argument("--store-pdf", dest="store_pdf", default=None)

    subparsers = parser.add_subparsers(dest="command")
    subparsers.add_parser("help", help="Show commands and examples.", parents=[common])
    subparsers.add_parser("list-collections", help="List pgvector collections.", parents=[common])

    stats = subparsers.add_parser("stats", help="Show collection stats.", parents=[common])

    search = subparsers.add_parser("search", help="Run semantic search.", parents=[common])
    search.add_argument("--query", required=True)
    search.add_argument("--original-query")
    search.add_argument("--top-k", type=int, default=DEFAULT_TOP_K)

    index_file = subparsers.add_parser("index-file", help="Index one .ris, .csv or .pdf file.", parents=[common])
    index_file.add_argument("path")
    index_file.add_argument("--method", choices=["header", "s2"], default="header")

    index_dir = subparsers.add_parser("index-dir", help="Recursively index .ris, .csv and .pdf files.", parents=[common])
    index_dir.add_argument("--dir", required=True)
    index_dir.add_argument("--method", choices=["header", "s2"], default="header")

    download = subparsers.add_parser("download", help="Download a PDF to a local directory.", parents=[common])
    download.add_argument("url")
    download.add_argument("--dir", required=True)

    chunk = subparsers.add_parser("chunk", help="Preview PDF chunks without indexing.", parents=[common])
    chunk.add_argument("pdf_path")
    chunk.add_argument("--method", choices=["header", "s2"], default="header")

    structure = subparsers.add_parser("structure", help="Show indexed PDF structure.", parents=[common])
    structure.add_argument("document")

    section = subparsers.add_parser("section", help="Fetch an indexed PDF section or page range.", parents=[common])
    section.add_argument("document")
    section.add_argument("--header-path")
    section.add_argument("--pages")

    return parser


def _help_payload(parser: argparse.ArgumentParser) -> dict[str, Any]:
    return {
        "skill": "index-kit",
        "backend": "pgvector",
        "default_model": DEFAULT_MODEL,
        "commands": [
            "list-collections",
            "stats",
            "search",
            "index-file",
            "index-dir",
            "download",
            "chunk",
            "structure",
            "section",
        ],
        "index_dir_order": ["ris", "csv", "pdf"],
        "usage": parser.format_help(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.model = DEFAULT_MODEL
    try:
        if not args.command or args.command == "help":
            _json_print(_help_payload(parser))
            return 0
        if args.command == "list-collections":
            code, payload = _run_pdf(args, "list-collections", [])
            _json_print(payload)
            return code
        if args.command == "stats":
            collection = _require_collection(args)
            code, payload = _run_pdf(args, "stats", ["--collection", collection])
            _json_print(payload)
            return code
        if args.command == "search":
            collection = _require_collection(args)
            code, payload = _run_pdf(
                args,
                "search",
                ["--collection", collection, "--query", args.query, "--top-k", str(args.top_k)],
            )
            if args.original_query:
                payload["original_query"] = args.original_query
                payload["english_query_used"] = args.query
            _json_print(payload)
            return code
        if args.command == "index-file":
            _json_print(_handle_index_file(args))
            return 0
        if args.command == "index-dir":
            _json_print(_handle_index_dir(args))
            return 0
        if args.command == "download":
            code, payload = _run_pdf(args, "download", [args.url, "--dir", args.dir])
            _json_print(payload)
            return code
        if args.command == "chunk":
            code, payload = _run_pdf(args, "chunk", [args.pdf_path, "--method", args.method])
            _json_print(payload)
            return code
        if args.command == "structure":
            collection = _require_collection(args)
            code, payload = _run_pdf(args, "structure", ["--collection", collection, args.document])
            _json_print(payload)
            return code
        if args.command == "section":
            collection = _require_collection(args)
            extra = ["--collection", collection, args.document]
            if args.header_path:
                extra.extend(["--header-path", args.header_path])
            if args.pages:
                extra.extend(["--pages", args.pages])
            code, payload = _run_pdf(args, "section", extra)
            _json_print(payload)
            return code
        parser.error(f"Unknown command: {args.command}")
        return 2
    except ValueError as exc:
        _json_print({"error": str(exc), "collections_hint": "Use list-collections para ver collections disponiveis."})
        return 2
    except Exception as exc:
        _json_print({"error": str(exc), "type": exc.__class__.__name__})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
