#!/usr/bin/env python3
"""Safely merge the AgentRouter provider into a user-level Codex config."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import tomllib


PROVIDER_BLOCK = """[model_providers.agentrouter]
name = \"AgentRouter\"
base_url = \"https://agentrouter.org/v1\"
wire_api = \"responses\"

[model_providers.agentrouter.models]
\"gpt-6-astra\" = { name = \"GPT-6 Astra\" }

[model_providers.agentrouter.auth]
command = \"/usr/bin/security\"
args = [\"find-generic-password\", \"-s\", \"agentrouter-codex\", \"-a\", \"codex\", \"-w\"]
"""

ROOT_BLOCK = 'model = "gpt-6-astra"\nmodel_provider = "agentrouter"\n'
TABLE_RE = re.compile(r"^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(?:#.*)?$")
ROOT_KEY_RE = re.compile(r"^\s*(model|model_provider)\s*=")


def parse_toml(text: str, label: str) -> None:
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"Refusing to modify invalid TOML in {label}: {exc}") from exc


def table_name(line: str) -> str | None:
    match = TABLE_RE.match(line)
    return match.group(1).strip() if match else None


def merge_config(original: str) -> str:
    if original.strip():
        parse_toml(original, "the existing configuration")

    kept: list[str] = []
    current_table: str | None = None
    skipping_agentrouter = False

    for line in original.splitlines():
        header = table_name(line)
        if header is not None:
            current_table = header
            skipping_agentrouter = (
                header == "model_providers.agentrouter"
                or header.startswith("model_providers.agentrouter.")
            )
            if skipping_agentrouter:
                continue

        if skipping_agentrouter:
            continue

        if current_table is None and ROOT_KEY_RE.match(line):
            continue

        kept.append(line)

    while kept and not kept[-1].strip():
        kept.pop()

    first_table = next(
        (index for index, line in enumerate(kept) if table_name(line) is not None),
        len(kept),
    )

    before = kept[:first_table]
    after = kept[first_table:]
    while before and not before[-1].strip():
        before.pop()

    merged_lines = before[:]
    if merged_lines:
        merged_lines.append("")
    merged_lines.extend(ROOT_BLOCK.rstrip().splitlines())
    if after:
        merged_lines.append("")
        merged_lines.extend(after)

    while merged_lines and not merged_lines[-1].strip():
        merged_lines.pop()
    merged_lines.extend(["", *PROVIDER_BLOCK.rstrip().splitlines(), ""])

    result = "\n".join(merged_lines)
    parse_toml(result, "the generated configuration")
    return result


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as handle:
        handle.write(text)
        temporary = Path(handle.name)
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=Path.home() / ".codex" / "config.toml",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    config = args.config.expanduser().resolve()
    original = config.read_text(encoding="utf-8") if config.exists() else ""
    merged = merge_config(original)

    if args.dry_run:
        print(merged, end="")
        return 0

    backup = None
    if config.exists():
        backup_dir = config.parent / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        timestamp = time.strftime("%Y-%m-%dT%H%M%S")
        backup = backup_dir / f"config.toml.pre-agentrouter.{timestamp}"
        shutil.copy2(config, backup)
        os.chmod(backup, 0o600)

    write_atomic(config, merged)
    print(f"CONFIG={config}")
    print(f"BACKUP={backup if backup else 'none (new configuration)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
