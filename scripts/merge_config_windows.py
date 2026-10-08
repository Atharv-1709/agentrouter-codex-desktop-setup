#!/usr/bin/env python3
"""Windows-safe Codex config merge, backup, validation, and rollback helpers."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PureWindowsPath
import re
import shutil
import sys
import tempfile
import time
import tomllib


ENDPOINT = "https://co.agentrouter.org/v1"
PROVIDER_ID = "agentrouter"
TABLE_RE = re.compile(r"^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(?:#.*)?$")
ROOT_KEY_RE = re.compile(r"^\s*(model|model_provider)\s*=")


def _toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def parse_toml(text: str, label: str) -> None:
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise ValueError(f"Refusing to use invalid TOML in {label}: {exc}") from exc


def _table_name(line: str) -> str | None:
    match = TABLE_RE.match(line)
    return match.group(1).strip() if match else None


def provider_block(wire_api: str, resolver_path: str) -> list[str]:
    resolver_path = resolver_path.replace("/", "\\")
    return [
        f"[model_providers.{PROVIDER_ID}]",
        'name = "AgentRouter"',
        f"base_url = {_toml_string(ENDPOINT)}",
        f"wire_api = {_toml_string(wire_api)}",
        "",
        f"[model_providers.{PROVIDER_ID}.models]",
        '"gpt-6-astra" = { name = "GPT-6 Astra" }',
        '"gpt-5.5" = { name = "GPT-5.5" }',
        "",
        f"[model_providers.{PROVIDER_ID}.auth]",
        'command = "pwsh.exe"',
        "args = [\"-NoLogo\", \"-NoProfile\", \"-NonInteractive\", \"-File\", "
        f"{_toml_string(resolver_path)}, \"-Get\"]",
    ]


def merge_config(original: str, *, model: str, wire_api: str, resolver_path: str) -> str:
    if model not in {"gpt-6-astra", "gpt-5.5"}:
        raise ValueError("Model must be gpt-6-astra or gpt-5.5")
    if wire_api not in {"responses", "chat"}:
        raise ValueError("Wire API must be responses or chat")
    if original.strip():
        parse_toml(original, "the existing configuration")

    kept: list[str] = []
    current_table: str | None = None
    skipping_provider = False
    for line in original.splitlines():
        header = _table_name(line)
        if header is not None:
            current_table = header
            skipping_provider = (
                header == f"model_providers.{PROVIDER_ID}"
                or header.startswith(f"model_providers.{PROVIDER_ID}.")
            )
            if skipping_provider:
                continue
        if skipping_provider:
            continue
        if current_table is None and ROOT_KEY_RE.match(line):
            continue
        kept.append(line)

    while kept and not kept[-1].strip():
        kept.pop()
    first_table = next(
        (index for index, line in enumerate(kept) if _table_name(line) is not None),
        len(kept),
    )
    before, after = kept[:first_table], kept[first_table:]
    while before and not before[-1].strip():
        before.pop()

    lines = before[:]
    if lines:
        lines.append("")
    lines.extend([f"model = {_toml_string(model)}", f'model_provider = "{PROVIDER_ID}"'])
    if after:
        lines.append("")
        lines.extend(after)
    while lines and not lines[-1].strip():
        lines.pop()
    lines.extend(["", *provider_block(wire_api, resolver_path), ""])
    merged = "\n".join(lines)
    parse_toml(merged, "the generated configuration")
    return merged


def _stamp() -> str:
    return time.strftime("%Y-%m-%dT%H%M%S") + f".{time.time_ns() % 1_000_000_000:09d}"


def _metadata_path(backup: Path) -> Path:
    return backup.with_name(backup.name + ".meta.json")


def backup_config(config: Path) -> Path:
    config = config.resolve()
    backup_dir = config.parent / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / f"config.toml.pre-agentrouter.{_stamp()}"
    existed = config.is_file()
    if existed:
        shutil.copy2(config, backup)
    else:
        backup.write_text("", encoding="utf-8")
    _metadata_path(backup).write_text(
        json.dumps({"config_existed": existed}, indent=2) + "\n", encoding="utf-8"
    )
    return backup


def _write_atomic(config: Path, text: str) -> None:
    config.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{config.name}.", dir=config.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(temp_name, config)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def install_config(config: Path, merged: str) -> Path:
    backup = backup_config(config)
    _write_atomic(config, merged)
    return backup


def rollback_config(config: Path, backup: Path) -> Path | None:
    config, backup = config.resolve(), backup.resolve()
    if not backup.is_file():
        raise ValueError(f"Backup not found: {backup}")
    meta_path = _metadata_path(backup)
    if not meta_path.is_file():
        raise ValueError("Backup metadata is missing; refusing an ambiguous rollback")
    metadata = json.loads(meta_path.read_text(encoding="utf-8"))
    existed = metadata.get("config_existed")
    if not isinstance(existed, bool):
        raise ValueError("Backup metadata is invalid")
    if existed:
        previous = backup.read_text(encoding="utf-8")
        parse_toml(previous, "the selected backup")

    recovery = None
    if config.is_file():
        recovery = config.parent / "backups" / f"config.toml.agentrouter-state.{_stamp()}"
        recovery.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(config, recovery)
    if existed:
        _write_atomic(config, previous)
    elif config.exists():
        config.unlink()
    return recovery


def detect_config_path(explicit: str | None = None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    codex_home = os.environ.get("CODEX_HOME")
    if codex_home:
        return Path(codex_home).expanduser().resolve() / "config.toml"
    return Path.home() / ".codex" / "config.toml"


def is_windows_absolute(path: str) -> bool:
    return PureWindowsPath(path).is_absolute()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config")
    parser.add_argument("--resolver", default=str(Path(__file__).resolve().with_name("credential-windows.ps1")))
    parser.add_argument("--model", choices=("gpt-6-astra", "gpt-5.5"), default="gpt-6-astra")
    parser.add_argument("--wire-api", choices=("responses", "chat"), default="responses")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--rollback")
    args = parser.parse_args()
    config = detect_config_path(args.config)
    try:
        if args.rollback:
            recovery = rollback_config(config, Path(args.rollback))
            print(f"CONFIG={config}")
            print(f"RECOVERY={recovery or 'none'}")
            return 0
        if args.wire_api == "chat" and not args.dry_run:
            raise ValueError("chat is an experimental preview only; Codex 0.145.0 rejects it. No file was written.")
        original = config.read_text(encoding="utf-8") if config.is_file() else ""
        merged = merge_config(
            original,
            model=args.model,
            wire_api=args.wire_api,
            resolver_path=args.resolver,
        )
        if args.dry_run:
            print(merged, end="")
            return 0
        backup = install_config(config, merged)
        print(f"CONFIG={config}")
        print(f"BACKUP={backup}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
