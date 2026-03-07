#!/usr/bin/env python3
"""Apply explicitly approved Paperless review suggestions from a CSV file."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


TRUTHY = {"1", "true", "yes", "y", "apply", "x"}
APPROVAL_COLUMNS = {"apply", "apply_title", "apply_document_type", "apply_tags"}


def _env_default(name: str, fallback: str | None = None) -> str | None:
    value = os.getenv(name)
    if value is None or not value.strip():
        return fallback
    return value.strip()


class HttpJsonClient:
    def __init__(self, base_url: str, *, token: str | None = None, auth_scheme: str = "Token") -> None:
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
    ) -> Any:
        url = self.base_url + path
        if query:
            encoded = urllib.parse.urlencode(
                {key: value for key, value in query.items() if value is not None and value != ""},
                doseq=True,
            )
            if encoded:
                url = f"{url}?{encoded}"

        headers = {
            "Accept": "application/json",
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

        return json.loads(raw) if raw else None

    def get_json(self, path: str, *, query: dict[str, Any] | None = None) -> Any:
        return self._request("GET", path, query=query)

    def patch_json(self, path: str, payload: dict[str, Any]) -> Any:
        return self._request("PATCH", path, payload=payload)


class PaperlessClient:
    def __init__(self, base_url: str, token: str) -> None:
        normalized = base_url.rstrip("/")
        if normalized.endswith("/api"):
            normalized = normalized[: -len("/api")]
        self.client = HttpJsonClient(f"{normalized}/api", token=token)

    def _paginate(self, path: str) -> list[dict[str, Any]]:
        page = 1
        results: list[dict[str, Any]] = []
        while True:
            payload = self.client.get_json(path, query={"page_size": 100, "page": page})
            if not isinstance(payload, dict):
                break
            results.extend(payload.get("results") or [])
            if not payload.get("next"):
                break
            page += 1
        return results

    def list_tags(self) -> list[dict[str, Any]]:
        return self._paginate("/tags/")

    def list_document_types(self) -> list[dict[str, Any]]:
        return self._paginate("/document_types/")

    def get_document(self, document_id: int) -> dict[str, Any]:
        payload = self.client.get_json(f"/documents/{document_id}/")
        if not isinstance(payload, dict):
            raise RuntimeError(f"Unexpected Paperless payload for document {document_id}")
        return payload

    def update_document(self, document_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        result = self.client.patch_json(f"/documents/{document_id}/", payload)
        if not isinstance(result, dict):
            raise RuntimeError(f"Unexpected update response for document {document_id}")
        return result


def _as_bool(value: str | None) -> bool:
    if value is None:
        return False
    return value.strip().casefold() in TRUTHY


def _parse_ids(value: str | None) -> set[int] | None:
    if not value:
        return None
    return {int(item.strip()) for item in value.split(",") if item.strip()}


def _approved(row: dict[str, str], field: str) -> bool:
    overall = _as_bool(row.get("apply"))
    specific_key = {
        "title": "apply_title",
        "document_type": "apply_document_type",
        "tags": "apply_tags",
    }[field]
    specific_value = row.get(specific_key, "")
    if specific_value.strip():
        return _as_bool(specific_value)
    return overall


def _load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise RuntimeError(f"No rows found in {path}")
    if not APPROVAL_COLUMNS.intersection(rows[0].keys()):
        raise RuntimeError(
            "CSV has no approval columns. Re-run the suggestion tool to get blank apply columns "
            "or add apply/apply_title/apply_document_type/apply_tags manually."
        )
    return rows


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paperless-url", default=_env_default("PAPERLESS_URL"))
    parser.add_argument("--paperless-token", default=_env_default("PAPERLESS_TOKEN"))
    parser.add_argument("--csv", required=True, type=Path, help="Reviewed CSV with apply columns.")
    parser.add_argument("--ids", help="Optional comma-separated document IDs to apply.")
    parser.add_argument("--dry-run", action="store_true", help="Show updates without writing to Paperless.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.paperless_url:
        print("Missing --paperless-url or PAPERLESS_URL", file=sys.stderr)
        return 2
    if not args.paperless_token:
        print("Missing --paperless-token or PAPERLESS_TOKEN", file=sys.stderr)
        return 2

    selected_ids = _parse_ids(args.ids)
    rows = _load_rows(args.csv)
    paperless = PaperlessClient(args.paperless_url, args.paperless_token)

    tag_name_to_id = {
        str(item.get("name") or "").strip(): int(item["id"])
        for item in paperless.list_tags()
        if item.get("name") and item.get("id") is not None
    }
    doc_type_name_to_id = {
        str(item.get("name") or "").strip(): int(item["id"])
        for item in paperless.list_document_types()
        if item.get("name") and item.get("id") is not None
    }

    applied = 0
    considered = 0
    for row in rows:
        document_id = int(row["document_id"])
        if selected_ids and document_id not in selected_ids:
            continue
        considered += 1

        payload: dict[str, Any] = {}
        if _approved(row, "title"):
            suggested_title = row.get("suggested_title", "").strip()
            if suggested_title:
                payload["title"] = suggested_title

        if _approved(row, "document_type"):
            suggested_type = row.get("suggested_document_type", "").strip()
            if suggested_type:
                doc_type_id = doc_type_name_to_id.get(suggested_type)
                if doc_type_id is None:
                    print(
                        f"[skip] document {document_id}: unknown document type {suggested_type!r}",
                        file=sys.stderr,
                    )
                else:
                    payload["document_type"] = doc_type_id

        if _approved(row, "tags"):
            suggested_tags = [item.strip() for item in row.get("suggested_tags", "").split(",") if item.strip()]
            if suggested_tags:
                live = paperless.get_document(document_id)
                existing_tags = live.get("tags") or []
                merged_tags: list[int] = []
                for item in existing_tags:
                    if isinstance(item, int) and item not in merged_tags:
                        merged_tags.append(item)
                for name in suggested_tags:
                    tag_id = tag_name_to_id.get(name)
                    if tag_id is None:
                        print(f"[skip] document {document_id}: unknown tag {name!r}", file=sys.stderr)
                        continue
                    if tag_id not in merged_tags:
                        merged_tags.append(tag_id)
                if merged_tags:
                    payload["tags"] = merged_tags

        if not payload:
            print(f"[skip] document {document_id}: no approved fields", file=sys.stderr)
            continue

        if args.dry_run:
            print(f"[dry-run] document {document_id}: {json.dumps(payload, ensure_ascii=False)}", file=sys.stderr)
        else:
            paperless.update_document(document_id, payload)
            print(f"[apply] document {document_id}: {json.dumps(payload, ensure_ascii=False)}", file=sys.stderr)
        applied += 1

    print(
        f"{'Would apply' if args.dry_run else 'Applied'} updates to {applied} of {considered} considered documents",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
