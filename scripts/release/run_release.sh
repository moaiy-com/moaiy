#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/run_release.sh --version X.Y.Z [options]

Options:
  --version <X.Y.Z>             Release version (required)
  --mode <draft|publish>        Release mode (default: draft)
  --signing <auto|unsigned|signed>
                                Signing strategy (default: auto)
  --gate <balanced|strict|fast>
                                Validation gate level (default: balanced)
  --dist-dir <path>             Output root (default: <repo>/dist/release)
  --allow-existing-tag          Allow local existing tag during reruns
  --github-output <path>        Optional GitHub output file path
  -h, --help                    Show help

Outputs:
  - <dist-dir>/vX.Y.Z-<timestamp>/assets/*.dmg
  - <dist-dir>/vX.Y.Z-<timestamp>/SHA256SUMS.txt
  - <dist-dir>/vX.Y.Z-<timestamp>/release-manifest.json
  - <dist-dir>/vX.Y.Z-<timestamp>/release-notes.md
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
MODE="draft"
SIGNING="auto"
GATE="balanced"
DIST_DIR="$ROOT_DIR/dist/release"
ALLOW_EXISTING_TAG=false
GITHUB_OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --signing)
      SIGNING="${2:-}"
      shift 2
      ;;
    --gate)
      GATE="${2:-}"
      shift 2
      ;;
    --dist-dir)
      DIST_DIR="${2:-}"
      shift 2
      ;;
    --allow-existing-tag)
      ALLOW_EXISTING_TAG=true
      shift
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

if [[ -z "$VERSION" ]]; then
  echo "ERROR: --version is required"
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: --version must match X.Y.Z"
  exit 1
fi

if [[ "$MODE" != "draft" && "$MODE" != "publish" ]]; then
  echo "ERROR: --mode must be draft or publish"
  exit 1
fi

if [[ "$SIGNING" != "auto" && "$SIGNING" != "unsigned" && "$SIGNING" != "signed" ]]; then
  echo "ERROR: --signing must be auto, unsigned, or signed"
  exit 1
fi

if [[ "$GATE" != "balanced" && "$GATE" != "strict" && "$GATE" != "fast" ]]; then
  echo "ERROR: --gate must be balanced, strict, or fast"
  exit 1
fi

if [[ -n "$GITHUB_OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$GITHUB_OUTPUT_PATH")"
fi

has_valid_team_id() {
  if [[ -n "${MOAIY_DEVELOPMENT_TEAM_ID:-}" ]]; then
    return 0
  fi

  local signing_config="$ROOT_DIR/Moaiy/Config/Moaiy.Signing.xcconfig"
  if [[ ! -f "$signing_config" ]]; then
    return 1
  fi

  local team_id
  team_id="$(
    sed -n 's/^[[:space:]]*MOAIY_DEVELOPMENT_TEAM_ID[[:space:]]*=[[:space:]]*//p' "$signing_config" \
      | head -n 1 \
      | xargs
  )"

  [[ -n "$team_id" && "$team_id" != "__TEAM_ID_PLACEHOLDER__" && "$team_id" != "YOUR_TEAM_ID" ]]
}

EFFECTIVE_SIGNING_MODE="$SIGNING"
BUILD_CONFIGURATION="Debug"

if [[ "$SIGNING" == "auto" ]]; then
  if has_valid_team_id; then
    EFFECTIVE_SIGNING_MODE="signed"
    BUILD_CONFIGURATION="Release"
  else
    EFFECTIVE_SIGNING_MODE="unsigned"
    BUILD_CONFIGURATION="Debug"
  fi
elif [[ "$SIGNING" == "signed" ]]; then
  if ! has_valid_team_id; then
    echo "ERROR: signing mode is signed but no valid development team id was found"
    exit 1
  fi
  EFFECTIVE_SIGNING_MODE="signed"
  BUILD_CONFIGURATION="Release"
else
  EFFECTIVE_SIGNING_MODE="unsigned"
  BUILD_CONFIGURATION="Debug"
fi

SYNC_ARGS=(--version "$VERSION")
if [[ "$ALLOW_EXISTING_TAG" == true ]]; then
  SYNC_ARGS+=(--allow-existing-tag)
fi
"$ROOT_DIR/scripts/release/check_version_sync.sh" "${SYNC_ARGS[@]}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RELEASE_DIR="$DIST_DIR/v${VERSION}-${TIMESTAMP}"
ASSET_DIR="$RELEASE_DIR/assets"
VALIDATION_DIR="$RELEASE_DIR/validation"
mkdir -p "$ASSET_DIR" "$VALIDATION_DIR"

TAG="v$VERSION"
TARGET_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"

echo "Release orchestration starting..."
echo "  version: $VERSION"
echo "  mode: $MODE"
echo "  gate: $GATE"
echo "  signing mode: $EFFECTIVE_SIGNING_MODE"
echo "  build configuration: $BUILD_CONFIGURATION"
echo "  target commit: $TARGET_COMMIT"
echo "  release dir: $RELEASE_DIR"

run_gate() {
  local arch="$1"
  local mode="$2"
  "$ROOT_DIR/scripts/release/external_validation.sh" \
    --version "$VERSION" \
    --label "release-${arch}-${mode}" \
    --mode "$mode" \
    --arch "$arch" \
    --result-dir "$VALIDATION_DIR"
}

run_gate "arm64" "full"

if [[ "$GATE" == "balanced" ]]; then
  run_gate "x86_64" "smoke"
elif [[ "$GATE" == "strict" ]]; then
  run_gate "x86_64" "full"
else
  echo "Skipping x86_64 validation in fast mode."
fi

ARM64_DMG_NAME="Moaiy-${VERSION}-macos-apple-silicon.dmg"
X64_DMG_NAME="Moaiy-${VERSION}-macos-intel-chip.dmg"

"$ROOT_DIR/scripts/package_dmg.sh" \
  --scheme Moaiy \
  --configuration "$BUILD_CONFIGURATION" \
  --arch arm64 \
  --version "$VERSION" \
  --artifact-name "$ARM64_DMG_NAME" \
  --dist-dir "$ASSET_DIR"

"$ROOT_DIR/scripts/package_dmg.sh" \
  --scheme Moaiy \
  --configuration "$BUILD_CONFIGURATION" \
  --arch x86_64 \
  --version "$VERSION" \
  --artifact-name "$X64_DMG_NAME" \
  --dist-dir "$ASSET_DIR"

ARM64_DMG_PATH="$ASSET_DIR/$ARM64_DMG_NAME"
X64_DMG_PATH="$ASSET_DIR/$X64_DMG_NAME"
SHA256_PATH="$RELEASE_DIR/SHA256SUMS.txt"
MANIFEST_PATH="$RELEASE_DIR/release-manifest.json"
NOTES_PATH="$RELEASE_DIR/release-notes.md"

if [[ ! -f "$ARM64_DMG_PATH" || ! -f "$X64_DMG_PATH" ]]; then
  echo "ERROR: expected DMG artifacts are missing"
  exit 1
fi

(cd "$ASSET_DIR" && shasum -a 256 "$ARM64_DMG_NAME" "$X64_DMG_NAME" > "$SHA256_PATH")

arm64_sha="$(shasum -a 256 "$ARM64_DMG_PATH" | awk '{print $1}')"
x64_sha="$(shasum -a 256 "$X64_DMG_PATH" | awk '{print $1}')"
arm64_size="$(stat -f%z "$ARM64_DMG_PATH")"
x64_size="$(stat -f%z "$X64_DMG_PATH")"
built_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$MANIFEST_PATH" <<EOF
{
  "version": "$VERSION",
  "tag": "$TAG",
  "target_commit": "$TARGET_COMMIT",
  "artifacts": [
    {
      "name": "$ARM64_DMG_NAME",
      "path": "assets/$ARM64_DMG_NAME",
      "arch": "arm64",
      "size_bytes": $arm64_size,
      "sha256": "$arm64_sha"
    },
    {
      "name": "$X64_DMG_NAME",
      "path": "assets/$X64_DMG_NAME",
      "arch": "x86_64",
      "size_bytes": $x64_size,
      "sha256": "$x64_sha"
    }
  ],
  "sha256": {
    "$ARM64_DMG_NAME": "$arm64_sha",
    "$X64_DMG_NAME": "$x64_sha"
  },
  "gate_mode": "$GATE",
  "signing_mode": "$EFFECTIVE_SIGNING_MODE",
  "built_at_utc": "$built_at_utc"
}
EOF

"$ROOT_DIR/scripts/release/render_release_notes.sh" \
  --version "$VERSION" \
  --manifest "$MANIFEST_PATH" \
  --output "$NOTES_PATH"

echo "Release orchestration completed."
echo "  notes: $NOTES_PATH"
echo "  manifest: $MANIFEST_PATH"
echo "  checksums: $SHA256_PATH"
echo "  arm64 dmg: $ARM64_DMG_PATH"
echo "  x86_64 dmg: $X64_DMG_PATH"

if [[ -n "$GITHUB_OUTPUT_PATH" ]]; then
  {
    echo "release_version=$VERSION"
    echo "release_tag=$TAG"
    echo "release_mode=$MODE"
    echo "gate_mode=$GATE"
    echo "signing_mode=$EFFECTIVE_SIGNING_MODE"
    echo "target_commit=$TARGET_COMMIT"
    echo "release_dir=$RELEASE_DIR"
    echo "asset_dir=$ASSET_DIR"
    echo "release_notes_path=$NOTES_PATH"
    echo "release_manifest_path=$MANIFEST_PATH"
    echo "release_sha256_path=$SHA256_PATH"
    echo "arm64_dmg_path=$ARM64_DMG_PATH"
    echo "x86_64_dmg_path=$X64_DMG_PATH"
  } >> "$GITHUB_OUTPUT_PATH"
fi
