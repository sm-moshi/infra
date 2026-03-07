#!/usr/bin/env python3
"""Generate private Paperless metadata suggestions via Ollama.

This script reads documents from Paperless-ngx, asks Ollama for bounded
classification suggestions, and writes review files outside the repository by
default. It never writes back to Paperless.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_EXCLUDED_TAGS = [r"^ai-", r"^FolderBatch$"]


def _env_default(name: str, fallback: str | None = None) -> str | None:
    value = os.getenv(name)
    if value is None or not value.strip():
        return fallback
    return value.strip()


def _build_default_output_paths() -> tuple[Path, Path]:
    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    downloads = Path.home() / "Downloads"
    stem = downloads / f"paperless-review-{timestamp}"
    return stem.with_suffix(".csv"), stem.with_suffix(".json")


class HttpJsonClient:
    def __init__(self, base_url: str, *, token: str | None = None) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token

    def _request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, Any] | None = None,
        payload: dict[str, Any] | None = None,
        accept: str = "application/json",
    ) -> Any:
        url = self.base_url + path
        if query:
            encoded = urllib.parse.urlencode(
                {
                    key: value
                    for key, value in query.items()
                    if value is not None and value != ""
                },
                doseq=True,
            )
            if encoded:
                url = f"{url}?{encoded}"

        headers = {
            "Accept": accept,
            "Content-Type": "application/json",
        }
        if self.token:
            headers["Authorization"] = f"Token {self.token}"

        data = None
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {url} failed with {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"{method} {url} failed: {exc}") from exc

        if not raw:
            return None
        return json.loads(raw)

    def get_json(self, path: str, *, query: dict[str, Any] | None = None) -> Any:
        return self._request("GET", path, query=query)

    def post_json(self, path: str, payload: dict[str, Any]) -> Any:
        return self._request("POST", path, payload=payload)


class PaperlessClient:
    def __init__(self, base_url: str, token: str) -> None:
        normalized = base_url.rstrip("/")
        if normalized.endswith("/api"):
            normalized = normalized[: -len("/api")]
        self.client = HttpJsonClient(f"{normalized}/api", token=token)

    def _paginate(self, path: str, *, query: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        query = dict(query or {})
        query.setdefault("page_size", 100)
        results: list[dict[str, Any]] = []
        next_query = query
        while True:
            payload = self.client.get_json(path, query=next_query)
            if isinstance(payload, dict) and "results" in payload:
                results.extend(payload.get("results") or [])
                next_url = payload.get("next")
                if not next_url:
                    return results
                parsed = urllib.parse.urlparse(next_url)
                next_query = {
                    key: values if len(values) > 1 else values[0]
                    for key, values in urllib.parse.parse_qs(parsed.query).items()
                }
                continue
            if isinstance(payload, list):
                results.extend(payload)
            return results

    def list_documents(
        self,
        *,
        query: str | None,
        ids: list[int] | None,
        all_documents: bool,
        limit: int | None,
    ) -> list[dict[str, Any]]:
        if ids:
            documents = [self.get_document(doc_id) for doc_id in ids]
        else:
            query_params: dict[str, Any] = {}
            if query:
                query_params["query"] = query
            documents = self._paginate("/documents/", query=query_params)
            if not all_documents:
                documents = [doc for doc in documents if doc.get("document_type") is None]
        documents.sort(key=lambda item: item.get("added") or "", reverse=True)
        if limit is not None:
            documents = documents[:limit]
        return documents

    def get_document(self, document_id: int) -> dict[str, Any]:
        payload = self.client.get_json(f"/documents/{document_id}/")
        if not isinstance(payload, dict):
            raise RuntimeError(f"Paperless returned unexpected document payload for {document_id}")
        return payload

    def list_tags(self) -> list[dict[str, Any]]:
        return self._paginate("/tags/")

    def list_document_types(self) -> list[dict[str, Any]]:
        return self._paginate("/document_types/")


class OllamaClient:
    def __init__(self, base_url: str, model: str, *, num_ctx: int, num_predict: int) -> None:
        self.client = HttpJsonClient(base_url.rstrip("/"))
        self.model = model
        self.num_ctx = num_ctx
        self.num_predict = num_predict

    def suggest(
        self,
        *,
        document: dict[str, Any],
        allowed_document_types: list[str],
        allowed_tags: list[str],
        content_chars: int,
    ) -> dict[str, Any]:
        title = (document.get("title") or "").strip()
        original_file_name = (document.get("original_file_name") or "").strip()
        content = (document.get("content") or "").strip()
        excerpt = content[:content_chars]
        user_prompt = {
            "document": {
                "id": document.get("id"),
                "current_title": title,
                "original_file_name": original_file_name,
                "created": document.get("created"),
                "added": document.get("added"),
                "content_excerpt": excerpt,
            },
            "allowed_document_types": allowed_document_types,
            "allowed_tags": allowed_tags,
            "instructions": [
                "Return JSON only.",
                "This is suggestion mode. Do not assume your output will be auto-applied.",
                "Only use allowed_document_types or null.",
                "Only use allowed_tags.",
                "Never suggest correspondents, custom fields, or dates.",
                "Keep suggested_title in the document's dominant source language.",
                "If the filename is garbage, prefer the document heading or obvious subject matter.",
                "If title confidence is low, use null for suggested_title.",
            ],
            "output_schema": {
                "suggested_title": "string|null",
                "suggested_document_type": "string|null",
                "suggested_tags": ["string"],
                "confidence": "number between 0 and 1",
                "reasoning": "short string",
            },
        }
        system_prompt = (
            "You classify Paperless documents conservatively. "
            "Do not invent metadata outside the allowed lists. "
            "If unsure, return null for the document type and title and an empty tag list."
        )
        payload = {
            "model": self.model,
            "stream": False,
            "format": "json",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": json.dumps(user_prompt, ensure_ascii=False)},
            ],
            "options": {
                "temperature": 0.1,
                "num_ctx": self.num_ctx,
                "num_predict": self.num_predict,
            },
        }
        response = self.client.post_json("/api/chat", payload)
        message = ((response or {}).get("message") or {}).get("content", "")
        if not message:
            raise RuntimeError("Ollama returned an empty response")
        try:
            return json.loads(message)
        except json.JSONDecodeError:
            match = re.search(r"\{.*\}", message, re.DOTALL)
            if not match:
                raise RuntimeError(f"Ollama returned non-JSON content: {message}")
            return json.loads(match.group(0))


def _compile_exclusions(patterns: list[str]) -> list[re.Pattern[str]]:
    return [re.compile(pattern) for pattern in patterns]


def _filter_allowed_tags(
    tags: list[dict[str, Any]],
    exclusions: list[re.Pattern[str]],
) -> list[str]:
    allowed: list[str] = []
    for item in tags:
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        if any(pattern.search(name) for pattern in exclusions):
            continue
        allowed.append(name)
    return sorted(set(allowed), key=str.casefold)


def _filter_allowed_document_types(document_types: list[dict[str, Any]]) -> list[str]:
    names = [str(item.get("name") or "").strip() for item in document_types]
    return sorted({name for name in names if name}, key=str.casefold)


def _normalize_suggestion(
    raw: dict[str, Any],
    *,
    allowed_document_types: set[str],
    allowed_tags: set[str],
) -> dict[str, Any]:
    suggested_title = raw.get("suggested_title")
    if not isinstance(suggested_title, str) or not suggested_title.strip():
        suggested_title = None
    else:
        suggested_title = suggested_title.strip()

    suggested_document_type = raw.get("suggested_document_type")
    if not isinstance(suggested_document_type, str) or suggested_document_type.strip() not in allowed_document_types:
        suggested_document_type = None
    else:
        suggested_document_type = suggested_document_type.strip()

    tags_value = raw.get("suggested_tags")
    if not isinstance(tags_value, list):
        tags_value = []
    normalized_tags = []
    for item in tags_value:
        if not isinstance(item, str):
            continue
        tag = item.strip()
        if not tag or tag not in allowed_tags or tag in normalized_tags:
            continue
        normalized_tags.append(tag)

    try:
        confidence = float(raw.get("confidence", 0.0))
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = max(0.0, min(1.0, confidence))

    reasoning = raw.get("reasoning")
    if not isinstance(reasoning, str):
        reasoning = ""
    reasoning = reasoning.strip()

    return {
        "suggested_title": suggested_title,
        "suggested_document_type": suggested_document_type,
        "suggested_tags": normalized_tags,
        "confidence": confidence,
        "reasoning": reasoning,
    }


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "document_id",
                "current_title",
                "original_file_name",
                "created",
                "current_document_type",
                "current_tags",
                "suggested_title",
                "suggested_document_type",
                "suggested_tags",
                "confidence",
                "reasoning",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    csv_default, json_default = _build_default_output_paths()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paperless-url", default=_env_default("PAPERLESS_URL"))
    parser.add_argument("--paperless-token", default=_env_default("PAPERLESS_TOKEN"))
    parser.add_argument("--ollama-url", default=_env_default("OLLAMA_URL", "http://localhost:11434"))
    parser.add_argument("--ollama-model", default=_env_default("OLLAMA_MODEL", "lfm2.5-thinking:1.2b"))
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--ids", help="Comma-separated Paperless document IDs to process.")
    parser.add_argument("--query", help="Paperless full-text query to select documents.")
    parser.add_argument("--all-documents", action="store_true", help="Process all matching documents, not just those without a document type.")
    parser.add_argument("--content-chars", type=int, default=12000)
    parser.add_argument("--num-ctx", type=int, default=8192)
    parser.add_argument("--num-predict", type=int, default=384)
    parser.add_argument("--csv-output", type=Path, default=csv_default)
    parser.add_argument("--json-output", type=Path, default=json_default)
    parser.add_argument(
        "--exclude-tag-regex",
        action="append",
        default=[],
        help="Regex for tags to exclude from AI suggestions. Can be repeated.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.paperless_url:
        print("Missing --paperless-url or PAPERLESS_URL", file=sys.stderr)
        return 2
    if not args.paperless_token:
        print("Missing --paperless-token or PAPERLESS_TOKEN", file=sys.stderr)
        return 2

    ids = None
    if args.ids:
        ids = [int(item.strip()) for item in args.ids.split(",") if item.strip()]

    exclusions = _compile_exclusions(DEFAULT_EXCLUDED_TAGS + list(args.exclude_tag_regex))

    paperless = PaperlessClient(args.paperless_url, args.paperless_token)
    allowed_tags = _filter_allowed_tags(paperless.list_tags(), exclusions)
    allowed_document_types = _filter_allowed_document_types(paperless.list_document_types())
    documents = paperless.list_documents(
        query=args.query,
        ids=ids,
        all_documents=args.all_documents,
        limit=args.limit,
    )
    ollama = OllamaClient(
        args.ollama_url,
        args.ollama_model,
        num_ctx=args.num_ctx,
        num_predict=args.num_predict,
    )

    rows: list[dict[str, Any]] = []
    normalized_payload: list[dict[str, Any]] = []
    allowed_doc_type_set = set(allowed_document_types)
    allowed_tag_set = set(allowed_tags)

    for index, document in enumerate(documents, start=1):
        document_id = int(document["id"])
        print(f"[{index}/{len(documents)}] Suggesting metadata for document {document_id}", file=sys.stderr)
        raw = ollama.suggest(
            document=document,
            allowed_document_types=allowed_document_types,
            allowed_tags=allowed_tags,
            content_chars=args.content_chars,
        )
        normalized = _normalize_suggestion(
            raw,
            allowed_document_types=allowed_doc_type_set,
            allowed_tags=allowed_tag_set,
        )
        current_tags = document.get("tags") or []
        row = {
            "document_id": document_id,
            "current_title": document.get("title") or "",
            "original_file_name": document.get("original_file_name") or "",
            "created": document.get("created_date") or document.get("created") or "",
            "current_document_type": document.get("document_type") or "",
            "current_tags": ",".join(str(tag) for tag in current_tags),
            "suggested_title": normalized["suggested_title"] or "",
            "suggested_document_type": normalized["suggested_document_type"] or "",
            "suggested_tags": ",".join(normalized["suggested_tags"]),
            "confidence": f"{normalized['confidence']:.2f}",
            "reasoning": normalized["reasoning"],
        }
        rows.append(row)
        normalized_payload.append(
            {
                "document_id": document_id,
                "current": {
                    "title": document.get("title"),
                    "original_file_name": document.get("original_file_name"),
                    "created": document.get("created_date") or document.get("created"),
                    "document_type": document.get("document_type"),
                    "tags": current_tags,
                },
                "suggestion": normalized,
            }
        )

    _write_csv(args.csv_output, rows)
    _write_json(
        args.json_output,
        {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "paperless_url": args.paperless_url,
            "ollama_url": args.ollama_url,
            "ollama_model": args.ollama_model,
            "allowed_document_types": allowed_document_types,
            "allowed_tags": allowed_tags,
            "documents": normalized_payload,
        },
    )

    print(f"Wrote CSV suggestions to {args.csv_output}", file=sys.stderr)
    print(f"Wrote JSON suggestions to {args.json_output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
