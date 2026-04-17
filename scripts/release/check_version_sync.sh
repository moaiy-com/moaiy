#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/check_version_sync.sh --version X.Y.Z [--allow-existing-tag]

Description:
  Verifies release version consistency across source of truth files.

Checks:
  - MARKETING_VERSION in project file must be a single value and equal --version
  - CHANGELOG must contain a heading: ## [X.Y.Z]
  - release notes template and renderer must exist with required metadata tokens
  - git tag vX.Y.Z must not already exist (unless --allow-existing-tag)
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
ALLOW_EXISTING_TAG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --allow-existing-tag)
      ALLOW_EXISTING_TAG=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option '$1'"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "ERROR: --version is required"
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: --version must match X.Y.Z"
  exit 1
fi

TAG="v$VERSION"
PROJECT_FILE="$ROOT_DIR/Moaiy/Moaiy.xcodeproj/project.pbxproj"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
RENDER_SCRIPT="$ROOT_DIR/scripts/release/render_release_notes.sh"
TEMPLATE_FILE="$ROOT_DIR/scripts/release/templates/release-notes.md.tmpl"

for path in "$PROJECT_FILE" "$CHANGELOG_FILE" "$RENDER_SCRIPT" "$TEMPLATE_FILE"; do
  if [[ ! -f "$path" ]]; then
    echo "ERROR: required file missing: $path"
    exit 1
  fi
done

marketing_versions=()
if command -v rg >/dev/null 2>&1; then
  while IFS= read -r version_line; do
    if [[ -n "$version_line" ]]; then
      marketing_versions+=("$version_line")
    fi
  done < <(
    rg --no-heading -o 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+' "$PROJECT_FILE" \
      | awk '{print $3}' \
      | sort -u
  )
else
  while IFS= read -r version_line; do
    if [[ -n "$version_line" ]]; then
      marketing_versions+=("$version_line")
    fi
  done < <(
    grep -Eo 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+' "$PROJECT_FILE" \
      | awk '{print $3}' \
      | sort -u
  )
fi

if [[ "${#marketing_versions[@]}" -eq 0 ]]; then
  echo "ERROR: no MARKETING_VERSION found in $PROJECT_FILE"
  exit 1
fi

if [[ "${#marketing_versions[@]}" -ne 1 ]]; then
  echo "ERROR: multiple MARKETING_VERSION values found: ${marketing_versions[*]}"
  exit 1
fi

if [[ "${marketing_versions[0]}" != "$VERSION" ]]; then
  echo "ERROR: MARKETING_VERSION mismatch (expected=$VERSION actual=${marketing_versions[0]})"
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  if ! rg -q "^## \\[$VERSION\\]" "$CHANGELOG_FILE"; then
    echo "ERROR: CHANGELOG missing heading for $VERSION (expected: ## [$VERSION])"
    exit 1
  fi
else
  if ! grep -q "^## \\[$VERSION\\]" "$CHANGELOG_FILE"; then
    echo "ERROR: CHANGELOG missing heading for $VERSION (expected: ## [$VERSION])"
    exit 1
  fi
fi

required_tokens=(
  "{{VERSION}}"
  "{{TAG}}"
  "{{TARGET_COMMIT}}"
  "{{GATE_MODE}}"
  "{{SIGNING_MODE}}"
  "{{ASSET_TABLE_EN}}"
  "{{ASSET_TABLE_ZH}}"
  "{{KNOWN_ISSUES_EN}}"
  "{{KNOWN_ISSUES_ZH}}"
  "{{DETAILED_UPDATES_EN}}"
  "{{DETAILED_UPDATES_ZH}}"
)

for token in "${required_tokens[@]}"; do
  if ! grep -Fq "$token" "$TEMPLATE_FILE"; then
    echo "ERROR: release notes template missing token: $token"
    exit 1
  fi
done

if [[ ! -x "$RENDER_SCRIPT" ]]; then
  echo "ERROR: render script must be executable: $RENDER_SCRIPT"
  exit 1
fi

if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  if [[ "$ALLOW_EXISTING_TAG" == false ]]; then
    echo "ERROR: tag already exists locally: $TAG"
    echo "Use --allow-existing-tag only for controlled reruns."
    exit 1
  fi
fi

echo "Version sync check passed:"
echo "  version: $VERSION"
echo "  tag: $TAG"
echo "  MARKETING_VERSION: ${marketing_versions[0]}"
