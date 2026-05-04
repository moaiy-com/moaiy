#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/render_release_notes.sh --version X.Y.Z --manifest <path> --output <path> [--changelog <path>]

Description:
  Renders bilingual (EN + ZH-Hans) release notes from release manifest metadata
  and detailed version changes extracted from CHANGELOG.md.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
MANIFEST_PATH=""
OUTPUT_PATH=""
CHANGELOG_PATH="$ROOT_DIR/CHANGELOG.md"
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
    --changelog)
      CHANGELOG_PATH="${2:-}"
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
if [[ ! -f "$CHANGELOG_PATH" ]]; then
  echo "ERROR: changelog not found: $CHANGELOG_PATH"
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

asset_table_en="$(cat <<EOF
| Asset | Arch | SHA-256 | Size (bytes) |
| --- | --- | --- | ---: |
$asset_rows
EOF
)"
asset_table_zh="$(cat <<EOF
| 文件 | 架构 | SHA-256 | 大小（字节） |
| --- | --- | --- | ---: |
$asset_rows
EOF
)"

known_issues_en="- Unsigned distribution track is active when signing mode is \`unsigned\`."
known_issues_zh="- 当签名模式为 \`unsigned\` 时，当前为未签名分发轨道。"
if [[ "$signing_mode" == "signed" ]]; then
  known_issues_en="- Signed distribution track is active. Verify notarization status before public rollout."
  known_issues_zh="- 当前为已签名分发轨道。对外发布前请先确认公证（notarization）状态。"
fi

if [[ "$gate_mode" == "balanced" ]]; then
  known_issues_en="$known_issues_en
- Balanced gate: x86_64 uses build + smoke fallback when Intel physical hardware is unavailable."
  known_issues_zh="$known_issues_zh
- 在平衡校验策略下，无 Intel 实机时，x86_64 采用 build + smoke 回退验证。"
fi

changelog_section="$(
  awk -v version="$VERSION" '
    $0 ~ "^## \\[" version "\\]" { in_section=1; next }
    in_section && $0 ~ "^## \\[" { exit }
    in_section { print }
  ' "$CHANGELOG_PATH"
)"

if [[ -z "${changelog_section//[[:space:]]/}" ]]; then
  echo "ERROR: changelog section content is empty for version $VERSION"
  exit 1
fi

detailed_updates_en="$(printf '%s\n' "$changelog_section" | sed '/./,$!d')"
#
# CHANGELOG supports optional bilingual sections using heading suffix "(zh-Hans)",
# for example:
#   ### Added
#   - ...
#   ### Added (zh-Hans)
#   - ...
# If zh-Hans blocks exist, English notes exclude them and Chinese notes consume them.
#
detailed_updates_en="$(
  printf '%s\n' "$changelog_section" \
    | awk '
      /^### .* \(zh-Hans\)$/ { in_zh=1; next }
      /^### / { if (in_zh == 1) in_zh=0 }
      in_zh == 0 { print }
    ' \
    | sed '/./,$!d'
)"

if [[ -z "${detailed_updates_en//[[:space:]]/}" ]]; then
  echo "ERROR: no English changelog details found for version $VERSION"
  exit 1
fi

if printf '%s\n' "$changelog_section" | grep -Eq '^### .+ \(zh-Hans\)$'; then
  detailed_updates_zh="$(
    printf '%s\n' "$changelog_section" \
      | awk '
        /^### .* \(zh-Hans\)$/ { in_zh=1; print; next }
        /^### / { in_zh=0 }
        in_zh == 1 { print }
      ' \
      | sed \
        -e 's/^### \(.*\) (zh-Hans)$/### \1/' \
        -e 's/^### Added$/### 新增/' \
        -e 's/^### Changed$/### 变更/' \
        -e 's/^### Fixed$/### 修复/' \
        -e 's/^### Removed$/### 移除/' \
        -e 's/^### Security$/### 安全/' \
        -e 's/^### Deprecated$/### 弃用/' \
      | sed '/./,$!d'
  )"
else
  echo "ERROR: no zh-Hans changelog sections found for version $VERSION."
  echo "Add bilingual blocks in CHANGELOG using headings like '### Added (zh-Hans)'."
  exit 1
fi

if [[ -z "${detailed_updates_zh//[[:space:]]/}" ]]; then
  echo "ERROR: no Chinese changelog details found for version $VERSION"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    *"{{ASSET_TABLE_EN}}"*)
      printf '%s\n' "$asset_table_en"
      ;;
    *"{{ASSET_TABLE_ZH}}"*)
      printf '%s\n' "$asset_table_zh"
      ;;
    *"{{ASSET_TABLE}}"*)
      # Backward compatibility for templates that still use a shared key.
      printf '%s\n' "$asset_table_en"
      ;;
    *"{{KNOWN_ISSUES_EN}}"*)
      printf '%s\n' "$known_issues_en"
      ;;
    *"{{KNOWN_ISSUES_ZH}}"*)
      printf '%s\n' "$known_issues_zh"
      ;;
    *"{{KNOWN_ISSUES}}"*)
      # Backward compatibility for templates that still use a shared key.
      printf '%s\n' "$known_issues_en"
      ;;
    *"{{DETAILED_UPDATES_EN}}"*)
      printf '%s\n' "$detailed_updates_en"
      ;;
    *"{{DETAILED_UPDATES_ZH}}"*)
      printf '%s\n' "$detailed_updates_zh"
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
