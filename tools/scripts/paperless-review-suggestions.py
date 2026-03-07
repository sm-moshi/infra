#!/usr/bin/env python3
"""Generate private Paperless metadata suggestions via local LLM backends.

This script reads documents from Paperless-ngx, asks a local LLM backend for
bounded classification suggestions, and writes review files outside the
repository by default. It never writes back to Paperless.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_EXCLUDED_TAGS = [r"^ai-", r"^FolderBatch$"]
TITLE_PREFIX_DATE_RE = re.compile(r"^(?P<date>\d{8})(?:\d{6})?[_ -]+")
CAMEL_CASE_RE = re.compile(r"(?<=[a-zäöüß])(?=[A-ZÄÖÜ])")
WHITESPACE_RE = re.compile(r"\s+")
TITLE_TRAILING_DATE_RE = re.compile(r"\s+vom\s+(?P<date>\d{2}\.\d{2}\.\d{4})$", re.IGNORECASE)
MEDICAL_NAME_PHRASE_RE = re.compile(
    r"\s+für\s+(?:Herrn|Frau|Patient(?:in)?|Patient)\s+"
    r"[A-ZÄÖÜ][\wÄÖÜäöüß-]+(?:\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+){0,3}",
    re.IGNORECASE,
)
MEDICAL_BARE_NAME_PHRASE_RE = re.compile(
    r"\s+für\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+(?:\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+){1,3}",
)
MEDICAL_INVERTED_NAME_PHRASE_RE = re.compile(
    r"\s+für\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+,\s*[A-ZÄÖÜ][\wÄÖÜäöüß-]+(?:\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+){0,2}",
)
TITLE_RECIPIENT_PHRASE_RE = re.compile(
    r"\s+an\s+(?:Herrn|Frau|Patient(?:in)?|Patient)\s+"
    r"[A-ZÄÖÜ][\wÄÖÜäöüß-]+(?:\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+){0,3}",
    re.IGNORECASE,
)
TITLE_TRAILING_NAME_FRAGMENT_RE = re.compile(
    r",\s*[A-ZÄÖÜ][\wÄÖÜäöüß-]+(?:\s+[A-ZÄÖÜ][\wÄÖÜäöüß-]+){0,3}$"
)
DOCUMENT_NOUNS = {
    "rechnung",
    "blutbild",
    "berufsausbildungsvertrag",
    "arbeitsvertrag",
    "vertrag",
    "arztbrief",
    "epikrise",
    "bericht",
    "schreiben",
}
PREFIX_NOUNS = {"rechnung", "blutbild"}
SUFFIX_PREFIX_NOUNS = {"entwurf"}


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


def _normalize_spaces(value: str) -> str:
    return WHITESPACE_RE.sub(" ", value).strip()


def _split_filename_words(value: str) -> str:
    value = value.replace("_", " ").replace("-", " ")
    value = CAMEL_CASE_RE.sub(" ", value)
    return _normalize_spaces(value)


def _format_iso_date(value: str | None) -> str | None:
    if not value:
        return None
    try:
        parsed = dt.date.fromisoformat(value[:10])
    except ValueError:
        return None
    return parsed.strftime("%d.%m.%Y")


def _parse_ddmmyyyy(value: str | None) -> dt.date | None:
    if not value:
        return None
    try:
        return dt.datetime.strptime(value, "%d.%m.%Y").date()
    except ValueError:
        return None


def _extract_filename_title_parts(
    original_file_name: str,
    current_title: str,
) -> tuple[str, str | None]:
    source = original_file_name.strip() or current_title.strip()
    stem = Path(source).stem
    date_match = TITLE_PREFIX_DATE_RE.match(stem)
    leading_date: str | None = None
    if date_match:
        raw_date = date_match.group("date")
        try:
            leading_date = dt.datetime.strptime(raw_date, "%Y%m%d").strftime("%d.%m.%Y")
        except ValueError:
            leading_date = None
        stem = stem[date_match.end():]
    return _split_filename_words(stem), leading_date


def _build_filename_title_hint(
    original_file_name: str,
    current_title: str,
    created: str | None,
) -> str | None:
    words, leading_date = _extract_filename_title_parts(original_file_name, current_title)
    if not words:
        return None
    tokens = words.split()
    if not tokens:
        return None
    normalized_tokens = [token.strip() for token in tokens if token.strip()]
    if not normalized_tokens:
        return None
    first = normalized_tokens[0].casefold()
    last = normalized_tokens[-1].casefold()
    if last in DOCUMENT_NOUNS and len(normalized_tokens) > 1:
        normalized_tokens = [normalized_tokens[-1], *normalized_tokens[:-1]]
        first = normalized_tokens[0].casefold()
    elif last in SUFFIX_PREFIX_NOUNS and len(normalized_tokens) > 1:
        normalized_tokens = [normalized_tokens[-1], *normalized_tokens[:-1]]
        first = normalized_tokens[0].casefold()
    title = " ".join(normalized_tokens)
    best_date = leading_date or _format_iso_date(created)
    if best_date and first in PREFIX_NOUNS:
        title = f"{title} vom {best_date}"
    return title


def _title_looks_filename_like(title: str | None) -> bool:
    if not isinstance(title, str):
        return False
    stripped = title.strip()
    if not stripped:
        return False
    if "_" in stripped:
        return True
    if TITLE_PREFIX_DATE_RE.match(stripped):
        return True
    return False


def _sanitize_suggested_title(
    suggested_title: str | None,
    *,
    document: dict[str, Any],
    suggested_document_type: str | None,
) -> str | None:
    if suggested_title is None:
        return None
    title = _normalize_spaces(suggested_title)
    if not title:
        return None

    if suggested_document_type in {"Medical / Clinical", "Lab Results"}:
        title = MEDICAL_NAME_PHRASE_RE.sub("", title)
        title = MEDICAL_BARE_NAME_PHRASE_RE.sub("", title)
        title = MEDICAL_INVERTED_NAME_PHRASE_RE.sub("", title)
        title = _normalize_spaces(title)
    else:
        title = TITLE_RECIPIENT_PHRASE_RE.sub("", title)
        title = _normalize_spaces(title)

    title = TITLE_TRAILING_NAME_FRAGMENT_RE.sub("", title)
    title = _normalize_spaces(title.rstrip(" -,:;"))

    date_match = TITLE_TRAILING_DATE_RE.search(title)
    current_created = _format_iso_date(str(document.get("created") or "")[:10])
    if date_match and current_created:
        title_date = _parse_ddmmyyyy(date_match.group("date"))
        created_date = _parse_ddmmyyyy(current_created)
        if title_date and created_date and title_date != created_date:
            title = title[: date_match.start()]
            title = _normalize_spaces(title.rstrip(" -,:;"))

    return title or None


class HttpJsonClient:
    def __init__(
        self,
        base_url: str,
        *,
        token: str | None = None,
        auth_scheme: str = "Token",
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.auth_scheme = auth_scheme

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
            headers["Authorization"] = f"{self.auth_scheme} {self.token}"

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
        prompt_payload = _build_suggestion_payload(
            document=document,
            allowed_document_types=allowed_document_types,
            allowed_tags=allowed_tags,
            content_chars=content_chars,
        )
        payload = {
            "model": self.model,
            "stream": False,
            "format": "json",
            "messages": [
                {"role": "system", "content": prompt_payload["system_prompt"]},
                {"role": "user", "content": json.dumps(prompt_payload["user_prompt"], ensure_ascii=False)},
            ],
            "options": {
                "temperature": 0.1,
                "num_ctx": self.num_ctx,
                "num_predict": self.num_predict,
            },
        }
        response = self.client.post_json("/api/chat", payload)
        for candidate in self._response_candidates(response):
            parsed = self._parse_json_candidate(candidate)
            if parsed is not None:
                return parsed
        raise RuntimeError(
            "Ollama returned no usable JSON payload. Raw response: "
            f"{json.dumps(response, ensure_ascii=False)}"
        )

    @staticmethod
    def _response_candidates(response: Any) -> list[str]:
        if not isinstance(response, dict):
            return []
        message = response.get("message")
        candidates: list[str] = []
        if isinstance(message, dict):
            for key in ("content", "thinking"):
                value = message.get(key)
                if isinstance(value, str) and value.strip():
                    candidates.append(value.strip())
        for key in ("response",):
            value = response.get(key)
            if isinstance(value, str) and value.strip():
                candidates.append(value.strip())
        return candidates

    @staticmethod
    def _parse_json_candidate(candidate: str) -> dict[str, Any] | None:
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            match = re.search(r"\{.*\}", candidate, re.DOTALL)
            if not match:
                return None
            try:
                parsed = json.loads(match.group(0))
            except json.JSONDecodeError:
                return None
        return parsed if isinstance(parsed, dict) else None


def _build_suggestion_payload(
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
    filename_title_hint = _build_filename_title_hint(
        original_file_name,
        title,
        document.get("created"),
    )
    user_prompt = {
        "document": {
            "id": document.get("id"),
            "current_title": title,
            "original_file_name": original_file_name,
            "created": document.get("created"),
            "added": document.get("added"),
            "content_excerpt": excerpt,
            "filename_title_hint": filename_title_hint,
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
            "Never return a raw filename as the title.",
            "Never include underscores, file extensions, or a leading YYYYMMDD filename prefix in the title.",
            "If the current title looks like a filename, rewrite it into readable German or English prose based on the document language.",
            "Do not include private personal names in the title unless the name is essential to distinguish the document.",
            "For medical and lab documents, prefer neutral titles such as 'Vorläufiger Arztbrief', 'Epikrise', 'Laborbefund', or 'Blutbild'.",
            "Only include a date in the title when the date is clearly stated and unambiguous in the document text.",
            "Use filename_title_hint as a fallback only when the OCR text does not provide a better heading.",
            "Prefer short subject titles such as 'Rechnung Hotel Maximilian', 'Blutbild vom 09.07.2025', or 'Entwurf Berufsausbildungsvertrag'.",
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
        "If unsure, return null for the document type and title and an empty tag list. "
        "Titles must be human-readable and must not look like filenames. "
        "Avoid full personal names in titles by default."
    )
    return {
        "user_prompt": user_prompt,
        "system_prompt": system_prompt,
    }


class OpenAICompatibleClient:
    def __init__(
        self,
        base_url: str,
        model: str,
        *,
        api_key: str | None,
        num_ctx: int,
        num_predict: int,
    ) -> None:
        self.client = HttpJsonClient(base_url.rstrip("/"), token=api_key, auth_scheme="Bearer")
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
        prompt_payload = _build_suggestion_payload(
            document=document,
            allowed_document_types=allowed_document_types,
            allowed_tags=allowed_tags,
            content_chars=content_chars,
        )
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": prompt_payload["system_prompt"]},
                {"role": "user", "content": json.dumps(prompt_payload["user_prompt"], ensure_ascii=False)},
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "paperless_review_suggestion",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "suggested_title": {"type": ["string", "null"]},
                            "suggested_document_type": {"type": ["string", "null"]},
                            "suggested_tags": {
                                "type": "array",
                                "items": {"type": "string"},
                            },
                            "confidence": {"type": "number"},
                            "reasoning": {"type": "string"},
                        },
                        "required": [
                            "suggested_title",
                            "suggested_document_type",
                            "suggested_tags",
                            "confidence",
                            "reasoning",
                        ],
                        "additionalProperties": False,
                    },
                },
            },
            "temperature": 0.1,
            "max_tokens": self.num_predict,
        }
        response = self.client.post_json("/chat/completions", payload)
        choices = (response or {}).get("choices")
        if not isinstance(choices, list) or not choices:
            raise RuntimeError(
                "OpenAI-compatible backend returned no choices. Raw response: "
                f"{json.dumps(response, ensure_ascii=False)}"
            )
        message = (choices[0] or {}).get("message") or {}
        candidates: list[str] = []
        for key in ("content", "reasoning_content"):
            candidate = message.get(key)
            if isinstance(candidate, list):
                text_parts = []
                for item in candidate:
                    if isinstance(item, dict) and item.get("type") == "text" and isinstance(item.get("text"), str):
                        text_parts.append(item["text"])
                candidate = "".join(text_parts)
            if isinstance(candidate, str) and candidate.strip():
                candidates.append(candidate.strip())
        for candidate in candidates:
            parsed = OllamaClient._parse_json_candidate(candidate)
            if parsed is not None:
                return parsed
        raise RuntimeError(
            "OpenAI-compatible backend returned no usable JSON content. Raw response: "
            f"{json.dumps(response, ensure_ascii=False)}"
        )


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
    document: dict[str, Any],
    allowed_document_types: set[str],
    allowed_tags: set[str],
) -> dict[str, Any]:
    current_title = str(document.get("title") or "").strip()
    fallback_title = _build_filename_title_hint(
        str(document.get("original_file_name") or ""),
        current_title,
        document.get("created"),
    )
    suggested_title = raw.get("suggested_title")
    if not isinstance(suggested_title, str) or not suggested_title.strip():
        suggested_title = None
    else:
        suggested_title = suggested_title.strip()
    if suggested_title and _title_looks_filename_like(suggested_title):
        suggested_title = None
    if suggested_title and current_title and suggested_title == current_title and _title_looks_filename_like(current_title):
        suggested_title = None
    if suggested_title is None and fallback_title and fallback_title != current_title:
        suggested_title = fallback_title

    suggested_document_type = raw.get("suggested_document_type")
    if not isinstance(suggested_document_type, str) or suggested_document_type.strip() not in allowed_document_types:
        suggested_document_type = None
    else:
        suggested_document_type = suggested_document_type.strip()

    suggested_title = _sanitize_suggested_title(
        suggested_title,
        document=document,
        suggested_document_type=suggested_document_type,
    )

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


def _is_context_overflow_error(exc: RuntimeError) -> bool:
    message = str(exc)
    indicators = (
        "n_keep",
        "n_ctx",
        "context length",
        "maximum context length",
        "prompt is too long",
        "context window",
        "Cannot truncate prompt",
    )
    return any(indicator in message for indicator in indicators)


def _is_transient_backend_error(exc: RuntimeError) -> bool:
    message = str(exc)
    indicators = (
        "Model reloaded.",
        "temporarily unavailable",
        "server overloaded",
        "connection reset by peer",
    )
    return any(indicator in message for indicator in indicators)


def _suggest_with_retries(
    llm_client: Any,
    *,
    document: dict[str, Any],
    allowed_document_types: list[str],
    allowed_tags: list[str],
    content_chars: int,
) -> tuple[dict[str, Any], int]:
    effective_chars = content_chars
    min_chars = 1200
    transient_retries = 2
    while True:
        try:
            return (
                llm_client.suggest(
                    document=document,
                    allowed_document_types=allowed_document_types,
                    allowed_tags=allowed_tags,
                    content_chars=effective_chars,
                ),
                effective_chars,
            )
        except RuntimeError as exc:
            if _is_transient_backend_error(exc) and transient_retries > 0:
                transient_retries -= 1
                print(
                    (
                        f"Transient backend error for document {document.get('id')}, "
                        f"retrying ({2 - transient_retries}/2)"
                    ),
                    file=sys.stderr,
                )
                time.sleep(1.0)
                continue
            if not _is_context_overflow_error(exc) or effective_chars <= min_chars:
                raise
            next_chars = max(min_chars, effective_chars // 2)
            if next_chars == effective_chars:
                raise
            print(
                (
                    f"Context overflow for document {document.get('id')}, "
                    f"retrying with --content-chars {next_chars}"
                ),
                file=sys.stderr,
            )
            effective_chars = next_chars


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
                "apply",
                "apply_title",
                "apply_document_type",
                "apply_tags",
                "notes",
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
    parser.add_argument(
        "--provider",
        choices=("ollama", "openai-compatible"),
        default=_env_default("PAPERLESS_REVIEW_PROVIDER", "ollama"),
    )
    parser.add_argument("--ollama-url", default=_env_default("OLLAMA_URL", "http://localhost:11434"))
    parser.add_argument("--ollama-model", default=_env_default("OLLAMA_MODEL", "lfm2.5-thinking:1.2b"))
    parser.add_argument(
        "--openai-base-url",
        default=_env_default("OPENAI_BASE_URL", "http://127.0.0.1:1234/v1"),
    )
    parser.add_argument("--openai-model", default=_env_default("OPENAI_MODEL"))
    parser.add_argument("--openai-api-key", default=_env_default("OPENAI_API_KEY", "lm-studio"))
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
    if args.provider == "ollama":
        llm_client: Any = OllamaClient(
            args.ollama_url,
            args.ollama_model,
            num_ctx=args.num_ctx,
            num_predict=args.num_predict,
        )
        provider_info = {
            "provider": "ollama",
            "url": args.ollama_url,
            "model": args.ollama_model,
        }
    else:
        if not args.openai_model:
            print("Missing --openai-model or OPENAI_MODEL for openai-compatible provider", file=sys.stderr)
            return 2
        llm_client = OpenAICompatibleClient(
            args.openai_base_url,
            args.openai_model,
            api_key=args.openai_api_key,
            num_ctx=args.num_ctx,
            num_predict=args.num_predict,
        )
        provider_info = {
            "provider": "openai-compatible",
            "url": args.openai_base_url,
            "model": args.openai_model,
        }

    rows: list[dict[str, Any]] = []
    normalized_payload: list[dict[str, Any]] = []
    allowed_doc_type_set = set(allowed_document_types)
    allowed_tag_set = set(allowed_tags)

    for index, document in enumerate(documents, start=1):
        document_id = int(document["id"])
        print(f"[{index}/{len(documents)}] Suggesting metadata for document {document_id}", file=sys.stderr)
        raw, used_content_chars = _suggest_with_retries(
            llm_client,
            document=document,
            allowed_document_types=allowed_document_types,
            allowed_tags=allowed_tags,
            content_chars=args.content_chars,
        )
        normalized = _normalize_suggestion(
            raw,
            document=document,
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
            "apply": "",
            "apply_title": "",
            "apply_document_type": "",
            "apply_tags": "",
            "notes": "",
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
                "used_content_chars": used_content_chars,
            }
        )

    _write_csv(args.csv_output, rows)
    _write_json(
        args.json_output,
        {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "paperless_url": args.paperless_url,
            "llm": provider_info,
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
