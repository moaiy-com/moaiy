#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/render_release_notes.sh --version X.Y.Z --manifest <path> --output <path>

Description:
  Renders bilingual (EN + ZH-Hans) release notes from release manifest metadata.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
MANIFEST_PATH=""
OUTPUT_PATH=""
TEMPLATE_PATH="$ROOT_DIR/scripts/release/templates/release-notes.md.tmpl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
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

if [[ -z "$VERSION" || -z "$MANIFEST_PATH" || -z "$OUTPUT_PATH" ]]; then
  echo "ERROR: --version, --manifest, and --output are required"
  usage
  exit 1
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "ERROR: manifest not found: $MANIFEST_PATH"
  exit 1
fi

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "ERROR: template not found: $TEMPLATE_PATH"
  exit 1
fi

manifest_version="$(jq -r '.version' "$MANIFEST_PATH")"
if [[ "$manifest_version" != "$VERSION" ]]; then
  echo "ERROR: manifest version mismatch (expected=$VERSION actual=$manifest_version)"
  exit 1
fi

tag="$(jq -r '.tag' "$MANIFEST_PATH")"
target_commit="$(jq -r '.target_commit' "$MANIFEST_PATH")"
gate_mode="$(jq -r '.gate_mode' "$MANIFEST_PATH")"
signing_mode="$(jq -r '.signing_mode' "$MANIFEST_PATH")"
built_at_utc="$(jq -r '.built_at_utc' "$MANIFEST_PATH")"

asset_rows="$(jq -r '.artifacts[] | "| `\(.name)` | `\(.arch)` | `\(.sha256)` | \(.size_bytes) |"' "$MANIFEST_PATH")"

if [[ -z "$asset_rows" ]]; then
  echo "ERROR: manifest contains no artifacts"
  exit 1
fi

asset_table="$(cat <<EOF
| Asset | Arch | SHA-256 | Size (bytes) |
| --- | --- | --- | ---: |
$asset_rows
EOF
)"

known_issues="- Unsigned distribution track is active when signing mode is \`unsigned\`."
if [[ "$signing_mode" == "signed" ]]; then
  known_issues="- Signed distribution track is active. Verify notarization status before public rollout."
fi

if [[ "$gate_mode" == "balanced" ]]; then
  known_issues="$known_issues
- Balanced gate: x86_64 uses build + smoke fallback when Intel physical hardware is unavailable."
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    *"{{ASSET_TABLE}}"*)
      printf '%s\n' "$asset_table"
      ;;
    *"{{KNOWN_ISSUES}}"*)
      printf '%s\n' "$known_issues"
      ;;
    *)
      line="${line//\{\{VERSION\}\}/$VERSION}"
      line="${line//\{\{TAG\}\}/$tag}"
      line="${line//\{\{TARGET_COMMIT\}\}/$target_commit}"
      line="${line//\{\{GATE_MODE\}\}/$gate_mode}"
      line="${line//\{\{SIGNING_MODE\}\}/$signing_mode}"
      line="${line//\{\{BUILT_AT_UTC\}\}/$built_at_utc}"
      printf '%s\n' "$line"
      ;;
  esac
done < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "Release notes rendered: $OUTPUT_PATH"
