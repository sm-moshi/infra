#!/usr/bin/env python3
"""Collect Git-managed internal DNS records from wrapper values files.

Scans apps/**/values.yaml for opt-in internalDns blocks and emits the desired
Unbound host overrides as JSON for the OPNsense Ansible role.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import yaml


SUPPORTED_RECORD_TYPES = {"A", "AAAA"}


def _normalize_hostnames(ingress: dict[str, Any]) -> list[str]:
    hosts: list[str] = []
    if "hosts" in ingress:
        for item in ingress.get("hosts") or []:
            if isinstance(item, dict) and item.get("host"):
                hosts.append(str(item["host"]))
            elif isinstance(item, str) and item:
                hosts.append(item)
    elif ingress.get("host"):
        hosts.append(str(ingress["host"]))
    return hosts


def _resolve_target(
    target: str,
    record_type: str,
    traefik_vip_ipv4: str,
    traefik_vip_ipv6: str,
) -> str:
    if target != "traefik-vip":
        raise ValueError(f"unsupported internalDns target '{target}'")
    if record_type == "A":
        if not traefik_vip_ipv4:
            raise ValueError("missing Traefik IPv4 VIP for A record generation")
        return traefik_vip_ipv4
    if record_type == "AAAA":
        if not traefik_vip_ipv6:
            raise ValueError("missing Traefik IPv6 VIP for AAAA record generation")
        return traefik_vip_ipv6
    raise ValueError(f"unsupported record type '{record_type}'")


def _build_description(prefix: str, relpath: str, component: str) -> str:
    suffix = f"{relpath}::{component}"
    description = f"{prefix} | {suffix}"
    if len(description) > 255:
        description = f"{prefix} | {suffix[-(255 - len(prefix) - 3) :]}"
    return description


def _collect_component(
    *,
    node: dict[str, Any],
    component_path: list[str],
    relpath: str,
    domain: str,
    description_prefix: str,
    traefik_vip_ipv4: str,
    traefik_vip_ipv6: str,
    seen_keys: set[str],
    records: list[dict[str, Any]],
    errors: list[str],
) -> None:
    internal_dns = node.get("internalDns")
    if not isinstance(internal_dns, dict) or not internal_dns.get("enabled", False):
        return

    source = internal_dns.get("source", "ingress")
    if source != "ingress":
        errors.append(f"{relpath}::{'.'.join(component_path) or 'root'} uses unsupported source '{source}'")
        return

    ingress = node.get("ingress")
    if not isinstance(ingress, dict):
        errors.append(f"{relpath}::{'.'.join(component_path) or 'root'} is missing ingress config")
        return
    if not ingress.get("enabled", False):
        errors.append(f"{relpath}::{'.'.join(component_path) or 'root'} has internalDns enabled but ingress disabled")
        return

    hosts = _normalize_hostnames(ingress)
    if not hosts:
        errors.append(f"{relpath}::{'.'.join(component_path) or 'root'} has no ingress hostnames")
        return

    record_types = internal_dns.get("recordTypes", ["A", "AAAA"])
    if not isinstance(record_types, list) or not record_types:
        errors.append(f"{relpath}::{'.'.join(component_path) or 'root'} has invalid recordTypes")
        return

    target = str(internal_dns.get("target", "traefik-vip"))
    component_name = ".".join(component_path) if component_path else "root"

    for host in hosts:
        fqdn = host.strip().rstrip(".").lower()
        suffix = f".{domain}"
        if not fqdn.endswith(suffix) or fqdn == domain:
            errors.append(f"{relpath}::{component_name} hostname '{fqdn}' is outside managed domain '{domain}'")
            continue
        hostname = fqdn[: -len(suffix)]
        for record_type in record_types:
            rr = str(record_type).upper()
            if rr not in SUPPORTED_RECORD_TYPES:
                errors.append(f"{relpath}::{component_name} uses unsupported record type '{record_type}'")
                continue
            key = f"{fqdn}|{rr}"
            if key in seen_keys:
                errors.append(f"duplicate internal DNS record '{key}' declared more than once")
                continue
            seen_keys.add(key)
            try:
                server = _resolve_target(target, rr, traefik_vip_ipv4, traefik_vip_ipv6)
            except ValueError as exc:
                errors.append(f"{relpath}::{component_name} {exc}")
                continue
            records.append({
                "key": key,
                "fqdn": fqdn,
                "hostname": hostname,
                "domain": domain,
                "rr": rr,
                "server": server,
                "target": target,
                "component": component_name,
                "source_values_file": relpath,
                "description": _build_description(description_prefix, relpath, component_name),
            })


def _walk_values(
    *,
    node: Any,
    component_path: list[str],
    relpath: str,
    domain: str,
    description_prefix: str,
    traefik_vip_ipv4: str,
    traefik_vip_ipv6: str,
    seen_keys: set[str],
    records: list[dict[str, Any]],
    errors: list[str],
) -> None:
    if not isinstance(node, dict):
        return

    _collect_component(
        node=node,
        component_path=component_path,
        relpath=relpath,
        domain=domain,
        description_prefix=description_prefix,
        traefik_vip_ipv4=traefik_vip_ipv4,
        traefik_vip_ipv6=traefik_vip_ipv6,
        seen_keys=seen_keys,
        records=records,
        errors=errors,
    )

    for key, value in node.items():
        if isinstance(value, dict):
            _walk_values(
                node=value,
                component_path=component_path + [key],
                relpath=relpath,
                domain=domain,
                description_prefix=description_prefix,
                traefik_vip_ipv4=traefik_vip_ipv4,
                traefik_vip_ipv6=traefik_vip_ipv6,
                seen_keys=seen_keys,
                records=records,
                errors=errors,
            )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--domain", required=True)
    parser.add_argument("--managed-description-prefix", required=True)
    parser.add_argument("--traefik-vip-ipv4", default="")
    parser.add_argument("--traefik-vip-ipv6", default="")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    values_files = sorted(repo_root.glob("apps/**/values.yaml"))

    records: list[dict[str, Any]] = []
    errors: list[str] = []
    seen_keys: set[str] = set()

    for values_file in values_files:
        relpath = values_file.relative_to(repo_root).as_posix()
        try:
            content = yaml.safe_load(values_file.read_text()) or {}
        except Exception as exc:  # pragma: no cover - surfaced in CLI output
            errors.append(f"{relpath} could not be parsed: {exc}")
            continue
        _walk_values(
            node=content,
            component_path=[],
            relpath=relpath,
            domain=args.domain,
            description_prefix=args.managed_description_prefix,
            traefik_vip_ipv4=args.traefik_vip_ipv4,
            traefik_vip_ipv6=args.traefik_vip_ipv6,
            seen_keys=seen_keys,
            records=records,
            errors=errors,
        )

    payload = {
        "records": sorted(records, key=lambda item: item["key"]),
        "errors": errors,
        "scanned_values_files": len(values_files),
    }
    if args.pretty:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(json.dumps(payload, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
