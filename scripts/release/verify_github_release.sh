#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/verify_github_release.sh --repo owner/name --tag vX.Y.Z --mode draft|publish [options]

Description:
  Verifies GitHub release visibility, draft/publish state, required assets,
  and asset SHA-256 digests after upload.

Required options:
  --repo <owner/name>
  --tag <vX.Y.Z>
  --mode <draft|publish>
  --arm64-dmg-path <path>
  --x86-64-dmg-path <path>
  --sha256-path <path>
  --manifest-path <path>

Optional:
  --wait-seconds <n>        Max wait time for release/asset consistency (default: 180)
  --poll-interval <n>       Poll interval in seconds (default: 5)
  -h, --help                Show help
EOF
}

REPO=""
TAG=""
MODE=""
ARM64_DMG_PATH=""
X64_DMG_PATH=""
SHA256_PATH=""
MANIFEST_PATH=""
WAIT_SECONDS=180
POLL_INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --arm64-dmg-path)
      ARM64_DMG_PATH="${2:-}"
      shift 2
      ;;
    --x86-64-dmg-path)
      X64_DMG_PATH="${2:-}"
      shift 2
      ;;
    --sha256-path)
      SHA256_PATH="${2:-}"
      shift 2
      ;;
    --manifest-path)
      MANIFEST_PATH="${2:-}"
      shift 2
      ;;
    --wait-seconds)
      WAIT_SECONDS="${2:-}"
      shift 2
      ;;
    --poll-interval)
      POLL_INTERVAL="${2:-}"
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

if [[ -z "$REPO" || -z "$TAG" || -z "$MODE" ]]; then
  echo "ERROR: --repo, --tag, and --mode are required"
  usage
  exit 1
fi

if [[ "$MODE" != "draft" && "$MODE" != "publish" ]]; then
  echo "ERROR: --mode must be draft or publish"
  exit 1
fi

for path in "$ARM64_DMG_PATH" "$X64_DMG_PATH" "$SHA256_PATH" "$MANIFEST_PATH"; do
  if [[ ! -f "$path" ]]; then
    echo "ERROR: required file missing: $path"
    exit 1
  fi
done

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --wait-seconds and --poll-interval must be positive integers"
  exit 1
fi

if [[ "$WAIT_SECONDS" -le 0 || "$POLL_INTERVAL" -le 0 ]]; then
  echo "ERROR: --wait-seconds and --poll-interval must be > 0"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required"
  exit 1
fi

arm64_name="$(basename "$ARM64_DMG_PATH")"
x64_name="$(basename "$X64_DMG_PATH")"
sha256_name="$(basename "$SHA256_PATH")"
manifest_name="$(basename "$MANIFEST_PATH")"

arm64_sha="$(shasum -a 256 "$ARM64_DMG_PATH" | awk '{print $1}')"
x64_sha="$(shasum -a 256 "$X64_DMG_PATH" | awk '{print $1}')"
sha256_sha="$(shasum -a 256 "$SHA256_PATH" | awk '{print $1}')"
manifest_sha="$(shasum -a 256 "$MANIFEST_PATH" | awk '{print $1}')"

manifest_arm64_sha="$(jq -r --arg name "$arm64_name" '.sha256[$name] // empty' "$MANIFEST_PATH")"
manifest_x64_sha="$(jq -r --arg name "$x64_name" '.sha256[$name] // empty' "$MANIFEST_PATH")"
if [[ -z "$manifest_arm64_sha" || -z "$manifest_x64_sha" ]]; then
  echo "ERROR: manifest missing DMG sha256 entries"
  exit 1
fi
if [[ "$manifest_arm64_sha" != "$arm64_sha" || "$manifest_x64_sha" != "$x64_sha" ]]; then
  echo "ERROR: local DMG hashes do not match release-manifest.json"
  exit 1
fi

file_sha_arm64="$(awk -v n="$arm64_name" '$2==n {print $1}' "$SHA256_PATH")"
file_sha_x64="$(awk -v n="$x64_name" '$2==n {print $1}' "$SHA256_PATH")"
if [[ "$file_sha_arm64" != "$arm64_sha" || "$file_sha_x64" != "$x64_sha" ]]; then
  echo "ERROR: SHA256SUMS.txt content does not match local DMG hashes"
  exit 1
fi

ASSET_NAMES=("$arm64_name" "$x64_name" "$sha256_name" "$manifest_name")
ASSET_HASHES=("$arm64_sha" "$x64_sha" "$sha256_sha" "$manifest_sha")

MAX_ATTEMPTS=$(( (WAIT_SECONDS + POLL_INTERVAL - 1) / POLL_INTERVAL ))
if [[ "$MAX_ATTEMPTS" -lt 1 ]]; then
  MAX_ATTEMPTS=1
fi

echo "Verifying GitHub release state..."
echo "  repo/tag   : $REPO / $TAG"
echo "  mode       : $MODE"
echo "  wait/poll  : ${WAIT_SECONDS}s / ${POLL_INTERVAL}s"

last_error=""

for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
  if ! release_json="$(gh release view "$TAG" --repo "$REPO" --json tagName,isDraft,url,assets 2>/dev/null)"; then
    last_error="release not visible yet"
  else
    release_tag="$(printf '%s\n' "$release_json" | jq -r '.tagName // ""')"
    is_draft="$(printf '%s\n' "$release_json" | jq -r '.isDraft')"
    release_url="$(printf '%s\n' "$release_json" | jq -r '.url // ""')"

    if [[ "$release_tag" != "$TAG" ]]; then
      last_error="release tag mismatch (expected=$TAG actual=$release_tag)"
    elif [[ "$MODE" == "publish" && "$is_draft" != "false" ]]; then
      last_error="release is still draft"
    elif [[ "$MODE" == "draft" && "$is_draft" != "true" ]]; then
      last_error="release is already published"
    else
      all_assets_ok="true"
      for ((i=0; i<${#ASSET_NAMES[@]}; i++)); do
        name="${ASSET_NAMES[$i]}"
        expected_digest="sha256:${ASSET_HASHES[$i]}"
        actual_digest="$(
          printf '%s\n' "$release_json" | jq -r --arg name "$name" '
            .assets | map(select(.name == $name)) | .[0].digest // empty
          '
        )"

        if [[ -z "$actual_digest" ]]; then
          all_assets_ok="false"
          last_error="missing asset or digest: $name"
          break
        fi

        if [[ "$actual_digest" != "$expected_digest" ]]; then
          all_assets_ok="false"
          last_error="digest mismatch for $name (expected=$expected_digest actual=$actual_digest)"
          break
        fi
      done

      if [[ "$all_assets_ok" == "true" ]]; then
        echo "Release verification passed."
        echo "  release url: $release_url"
        exit 0
      fi
    fi
  fi

  echo "Attempt $attempt/$MAX_ATTEMPTS: $last_error"
  if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
    sleep "$POLL_INTERVAL"
  fi
done

echo "ERROR: release verification failed after $MAX_ATTEMPTS attempts"
echo "  last error: ${last_error:-unknown}"
exit 2
