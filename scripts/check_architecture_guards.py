#!/usr/bin/env python3
"""Deterministic architecture & security boundary guards for Moaiy.

Encodes high-risk AGENTS.md invariants into executable static checks with
actionable remediation messages. Zero third-party dependencies.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Violation:
    rule_id: str
    path: str
    line: int
    snippet: str
    remediation: str


NONEMPTY_CLI_PASSPHRASE_RE = re.compile(
    r"""--passphrase(?:=(?!["']["'])\S+|["']\s*,\s*(?!\s*""\s*(?:,|\s|$))[^,\]]+)"""
)
SEC_ITEM_API_RE = re.compile(r"\bSecItem(?:Add|CopyMatching|Update|Delete)\s*\(")
PROCESS_INIT_RE = re.compile(r"\bProcess\s*\(\s*\)")
EXTERNAL_GPG_PATH_RE = re.compile(r"""["']/(?:opt/homebrew|usr/local)/bin/gpg["']""")
FORCE_TRY_OR_CAST_RE = re.compile(r"(?:^|[^A-Za-z0-9_])(?:try!|as!)(?:\s|$)")

# Explicit legacy exemption for existing ditto ZIP archival in BackupManagerView.swift
# until moved into a dedicated ArchiveService.
PROCESS_UI_EXEMPTIONS = {
    "Moaiy/Views/Backup/BackupManagerView.swift",
}

EXTERNAL_GPG_PATH_ALLOWED = {
    "Moaiy/Services/GPGService.swift",
    "MoaiyCLI/main.swift",
}


def strip_comment_only_line(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*")


def iter_swift_files(root: Path, subdirs: tuple[str, ...]) -> list[Path]:
    files: list[Path] = []
    for subdir in subdirs:
        base = root / subdir
        if not base.exists():
            continue
        files.extend(sorted(base.rglob("*.swift")))
    return files


def scan_repository(root: Path) -> list[Violation]:
    violations: list[Violation] = []

    prod_files = iter_swift_files(
        root,
        ("Moaiy/App", "Moaiy/Models", "Moaiy/Services", "Moaiy/Theme", "Moaiy/Utils", "Moaiy/ViewModels", "Moaiy/Views", "MoaiyCLI"),
    )
    ui_layer_prefixes = ("Moaiy/App/", "Moaiy/Views/", "Moaiy/ViewModels/")
    ui_and_model_prefixes = ui_layer_prefixes + ("Moaiy/Models/",)
    services_and_cli_prefixes = ("Moaiy/Services/", "MoaiyCLI/")

    for file_path in prod_files:
        rel_path = file_path.relative_to(root).as_posix()
        lines = file_path.read_text(encoding="utf-8", errors="replace").splitlines()

        for lineno, raw_line in enumerate(lines, start=1):
            if strip_comment_only_line(raw_line):
                continue

            # Rule 1: Never pass non-empty passphrases on the command line
            if NONEMPTY_CLI_PASSPHRASE_RE.search(raw_line):
                violations.append(
                    Violation(
                        rule_id="no-nonempty-cli-passphrase",
                        path=rel_path,
                        line=lineno,
                        snippet=raw_line.strip(),
                        remediation="Use StreamingCryptoPipeline 0600 token file (--passphrase-file) or --passphrase-fd 0 instead of passing non-empty passphrases on the command line.",
                    )
                )

            # Rule 2: Keep raw Security.framework SecItem* calls inside Moaiy/Services/
            if rel_path.startswith(ui_and_model_prefixes) and SEC_ITEM_API_RE.search(raw_line):
                violations.append(
                    Violation(
                        rule_id="no-secitem-outside-services",
                        path=rel_path,
                        line=lineno,
                        snippet=raw_line.strip(),
                        remediation="Use KeychainService in Moaiy/Services/ instead of calling raw SecItem* APIs from UI or Model layers.",
                    )
                )

            # Rule 3: Keep Process() subprocess spawning out of App/Views/ViewModels
            if (
                rel_path.startswith(ui_layer_prefixes)
                and rel_path not in PROCESS_UI_EXEMPTIONS
                and PROCESS_INIT_RE.search(raw_line)
            ):
                violations.append(
                    Violation(
                        rule_id="no-process-in-ui-layers",
                        path=rel_path,
                        line=lineno,
                        snippet=raw_line.strip(),
                        remediation="Delegate subprocess execution to GPGService or StreamingCryptoPipeline in Moaiy/Services/ instead of spawning Process() in App/Views/ViewModels.",
                    )
                )

            # Rule 4: Do not hardcode external gpg paths outside GPGService/MoaiyCLI
            if rel_path not in EXTERNAL_GPG_PATH_ALLOWED and EXTERNAL_GPG_PATH_RE.search(raw_line):
                violations.append(
                    Violation(
                        rule_id="no-hardcoded-external-gpg-path",
                        path=rel_path,
                        line=lineno,
                        snippet=raw_line.strip(),
                        remediation="Resolve bundled gpg.bundle via GPGService instead of hardcoding /opt/homebrew/bin/gpg or /usr/local/bin/gpg.",
                    )
                )

            # Rule 5: Disallow force try! and as! in Services and CLI
            if rel_path.startswith(services_and_cli_prefixes) and FORCE_TRY_OR_CAST_RE.search(raw_line):
                violations.append(
                    Violation(
                        rule_id="no-force-try-or-cast-in-services",
                        path=rel_path,
                        line=lineno,
                        snippet=raw_line.strip(),
                        remediation="Replace `try!` or `as!` with explicit error propagation or safe conditional binding.",
                    )
                )

    return violations


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Moaiy architecture and security boundary guards.")
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root directory to scan (default: current directory).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    violations = scan_repository(root)

    if violations:
        print(f"Architecture guards failed with {len(violations)} violation(s):")
        for v in violations:
            print(f"  [{v.rule_id}] {v.path}:{v.line}")
            print(f"    Code: {v.snippet}")
            print(f"    Fix:  {v.remediation}")
        return 1

    print("Architecture guards passed: 0 violations across App/Models/Services/Utils/ViewModels/Views/MoaiyCLI.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
