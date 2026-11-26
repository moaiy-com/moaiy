#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/list_release_assets.sh --manifest <path> --sha256 <path> [--github-output <path>]

Description:
  Resolves the files a GitHub Release upload must include from release-manifest.json.
  An x86_64 DMG is included when the manifest lists one, and omitted when it does not.
  A checksum entry for a disk image that is not in the manifest is an error.

Outputs (when --github-output is set):
  arm64_dmg_path, x86_64_dmg_path (empty if none), sha256_path, manifest_path, upload_list_path
EOF
}

MANIFEST_PATH=""
SHA256_PATH=""
GITHUB_OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      MANIFEST_PATH="${2:-}"
      shift 2
      ;;
    --sha256)
      SHA256_PATH="${2:-}"
      shift 2
      ;;
    --github-output)
      GITHUB_OUTPUT_PATH="${2:-}"
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

if [[ -z "$MANIFEST_PATH" || -z "$SHA256_PATH" ]]; then
  echo "ERROR: --manifest and --sha256 are required"
  usage
  exit 1
fi

if [[ ! -f "$MANIFEST_PATH" || ! -f "$SHA256_PATH" ]]; then
  echo "ERROR: manifest or SHA256SUMS file is missing"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required"
  exit 1
fi

RELEASE_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
arm64_path=""
x64_path=""

while IFS=$'\t' read -r arch relpath name sha; do
  if [[ -z "${arch:-}" ]]; then
    continue
  fi
  case "${relpath:-}" in
    ""|/*|../*|*/../*|*/..|..)
      echo "ERROR: unsafe artifact path: ${relpath:-<empty>}"
      exit 1
      ;;
  esac

  full="$RELEASE_DIR/$relpath"
  if [[ ! -f "$full" ]]; then
    echo "ERROR: manifest artifact missing on disk: $full"
    exit 1
  fi
  if [[ "$(basename "$full")" != "$name" ]]; then
    echo "ERROR: artifact path/name mismatch for $name ($relpath)"
    exit 1
  fi

  actual="$(shasum -a 256 "$full" | awk '{print $1}')"
  if [[ -z "${sha:-}" || "$actual" != "$sha" ]]; then
    echo "ERROR: on-disk hash does not match manifest for $name"
    exit 1
  fi

  sums="$(awk -v n="$name" '$2==n {print $1}' "$SHA256_PATH")"
  if [[ "$sums" != "$sha" ]]; then
    echo "ERROR: SHA256SUMS.txt does not match manifest for $name"
    exit 1
  fi

  case "$arch" in
    arm64)
      if [[ -n "$arm64_path" ]]; then
        echo "ERROR: manifest contains more than one arm64 artifact"
        exit 1
      fi
      arm64_path="$full"
      ;;
    x86_64)
      if [[ -n "$x64_path" ]]; then
        echo "ERROR: manifest contains more than one x86_64 artifact"
        exit 1
      fi
      x64_path="$full"
      ;;
    *)
      echo "ERROR: unsupported artifact architecture: $arch"
      exit 1
      ;;
  esac
done < <(jq -r '.artifacts[] | [.arch, .path, .name, .sha256] | @tsv' "$MANIFEST_PATH")

if [[ -z "$arm64_path" ]]; then
  echo "ERROR: manifest has no arm64 artifact"
  exit 1
fi

arm64_name="$(basename "$arm64_path")"
x64_name=""
if [[ -n "$x64_path" ]]; then
  x64_name="$(basename "$x64_path")"
fi

while read -r sum name; do
  if [[ -z "${sum:-}" ]]; then
    continue
  fi
  case "${name:-}" in
    *.dmg)
      if [[ "$name" != "$arm64_name" && "$name" != "$x64_name" ]]; then
        echo "ERROR: SHA256SUMS.txt lists $name, which the manifest does not publish."
        echo "Refusing to drop a disk image that was checksummed but not declared."
        exit 1
      fi
      ;;
  esac
done < "$SHA256_PATH"

UPLOAD_LIST="$(mktemp "${TMPDIR:-/tmp}/moaiy-release-upload.XXXXXX")"
{
  printf '%s\n' "$arm64_path"
  if [[ -n "$x64_path" ]]; then
    printf '%s\n' "$x64_path"
  fi
  printf '%s\n' "$SHA256_PATH"
  printf '%s\n' "$MANIFEST_PATH"
} > "$UPLOAD_LIST"

if [[ -n "$GITHUB_OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$GITHUB_OUTPUT_PATH")"
  {
    echo "arm64_dmg_path=$arm64_path"
    echo "x86_64_dmg_path=$x64_path"
    echo "sha256_path=$SHA256_PATH"
    echo "manifest_path=$MANIFEST_PATH"
    echo "upload_list_path=$UPLOAD_LIST"
  } >> "$GITHUB_OUTPUT_PATH"
fi

echo "Resolved release assets."
echo "  arm64: $arm64_path"
if [[ -n "$x64_path" ]]; then
  echo "  x86_64: $x64_path"
else
  echo "  x86_64: (none)"
fi
echo "  upload list: $UPLOAD_LIST"
