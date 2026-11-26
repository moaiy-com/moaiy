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
  --dry-run                     Resolve signing and architectures, then exit
                                before version sync, gates, or packaging
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
DRY_RUN=false

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
    --dry-run)
      DRY_RUN=true
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

is_valid_team_id() {
  local team_id="$1"
  [[ -n "$team_id" && "$team_id" != "__TEAM_ID_PLACEHOLDER__" && "$team_id" != "YOUR_TEAM_ID" ]]
}

has_valid_team_id() {
  # A non-empty environment value wins, including an invalid placeholder.
  # An unset or empty variable falls through to Moaiy/Config/Moaiy.Signing.xcconfig.
  if [[ -n "${MOAIY_DEVELOPMENT_TEAM_ID:-}" ]]; then
    is_valid_team_id "${MOAIY_DEVELOPMENT_TEAM_ID}"
    return
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

  is_valid_team_id "$team_id"
}

# True when the bundled GnuPG runtime contains an x86_64 slice.
# package_dmg.sh refuses to build an architecture the bundle does not contain,
# and the Xcode project currently sets ARCHS = arm64. Intel packaging stays
# enabled only when lipo can see x86_64, so a universal runtime is not dropped.
bundled_runtime_supports_x86_64() {
  local gpg_bin="$ROOT_DIR/Moaiy/Resources/gpg.bundle/bin/gpg"
  local archs=""

  if [[ ! -f "$gpg_bin" ]]; then
    echo "ERROR: bundled gpg binary missing: $gpg_bin" >&2
    return 2
  fi

  if ! command -v lipo >/dev/null 2>&1; then
    echo "WARNING: lipo is not available; treating the bundled runtime as arm64-only." >&2
    return 1
  fi

  if ! archs="$(lipo -archs "$gpg_bin" 2>/dev/null)"; then
    echo "ERROR: lipo could not read architectures from $gpg_bin." >&2
    echo "Refusing to guess and omit an Intel artifact." >&2
    return 2
  fi

  [[ "$archs" == *"x86_64"* ]]
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

if [[ "$MODE" == "publish" && "$EFFECTIVE_SIGNING_MODE" == "unsigned" ]]; then
  echo "WARNING: publishing an unsigned build. It is not code-signed and is not notarized." >&2
  echo "WARNING: macOS Gatekeeper will block opening it until the user allows it." >&2
  echo "WARNING: this is not a substitute for a Developer ID signed and notarized release." >&2
fi

SUPPORTS_X86_64=false
set +e
bundled_runtime_supports_x86_64
arch_status=$?
set -e
if [[ "$arch_status" -eq 0 ]]; then
  SUPPORTS_X86_64=true
elif [[ "$arch_status" -eq 2 ]]; then
  exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "signing_mode=$EFFECTIVE_SIGNING_MODE"
  echo "build_configuration=$BUILD_CONFIGURATION"
  echo "supports_x86_64=$SUPPORTS_X86_64"
  echo "release_mode=$MODE"
  exit 0
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

if [[ "$SUPPORTS_X86_64" == true ]]; then
  if [[ "$GATE" == "balanced" ]]; then
    run_gate "x86_64" "smoke"
  elif [[ "$GATE" == "strict" ]]; then
    run_gate "x86_64" "full"
  else
    echo "Skipping x86_64 validation in fast mode."
  fi
else
  echo "Bundled gpg.bundle is arm64-only ($BUNDLED_GPG_ARCHS); targeting arm64 release artifacts."
fi

ARM64_DMG_NAME="Moaiy-${VERSION}-macos-apple-silicon.dmg"
X64_DMG_PATH=""

"$ROOT_DIR/scripts/package_dmg.sh" \
  --scheme Moaiy \
  --configuration "$BUILD_CONFIGURATION" \
  --arch arm64 \
  --version "$VERSION" \
  --artifact-name "$ARM64_DMG_NAME" \
  --dist-dir "$ASSET_DIR"

ARM64_DMG_PATH="$ASSET_DIR/$ARM64_DMG_NAME"
SHA256_PATH="$RELEASE_DIR/SHA256SUMS.txt"
MANIFEST_PATH="$RELEASE_DIR/release-manifest.json"
NOTES_PATH="$RELEASE_DIR/release-notes.md"

if [[ ! -f "$ARM64_DMG_PATH" ]]; then
  echo "ERROR: expected arm64 DMG artifact is missing"
  exit 1
fi

arm64_sha="$(shasum -a 256 "$ARM64_DMG_PATH" | awk '{print $1}')"
arm64_size="$(stat -f%z "$ARM64_DMG_PATH")"
built_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ "$SUPPORTS_X86_64" == true ]]; then
  X64_DMG_NAME="Moaiy-${VERSION}-macos-intel-chip.dmg"
  "$ROOT_DIR/scripts/package_dmg.sh" \
    --scheme Moaiy \
    --configuration "$BUILD_CONFIGURATION" \
    --arch x86_64 \
    --version "$VERSION" \
    --artifact-name "$X64_DMG_NAME" \
    --dist-dir "$ASSET_DIR"
  X64_DMG_PATH="$ASSET_DIR/$X64_DMG_NAME"
  (cd "$ASSET_DIR" && shasum -a 256 "$ARM64_DMG_NAME" "$X64_DMG_NAME" > "$SHA256_PATH")
  x64_sha="$(shasum -a 256 "$X64_DMG_PATH" | awk '{print $1}')"
  x64_size="$(stat -f%z "$X64_DMG_PATH")"
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
  "pqc_compatibility_caveat": {
    "enabled": true,
    "algorithm": "Kyber-768 hybrid OpenPGP"
  },
  "built_at_utc": "$built_at_utc"
}
EOF
else
  (cd "$ASSET_DIR" && shasum -a 256 "$ARM64_DMG_NAME" > "$SHA256_PATH")
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
    }
  ],
  "sha256": {
    "$ARM64_DMG_NAME": "$arm64_sha"
  },
  "gate_mode": "$GATE",
  "signing_mode": "$EFFECTIVE_SIGNING_MODE",
  "pqc_compatibility_caveat": {
    "enabled": true,
    "algorithm": "Kyber-768 hybrid OpenPGP"
  },
  "built_at_utc": "$built_at_utc"
}
EOF
fi

"$ROOT_DIR/scripts/release/render_release_notes.sh" \
  --version "$VERSION" \
  --manifest "$MANIFEST_PATH" \
  --output "$NOTES_PATH"

if [[ "$EFFECTIVE_SIGNING_MODE" == "unsigned" ]]; then
  if ! grep -Fq "not code-signed" "$NOTES_PATH" \
    || ! grep -Fq "not notarized" "$NOTES_PATH" \
    || ! grep -Fq "Gatekeeper will block" "$NOTES_PATH" \
    || ! grep -Fq "not a substitute for a Developer ID signed and notarized release" "$NOTES_PATH" \
    || ! grep -Fq "未经代码签名" "$NOTES_PATH" \
    || ! grep -Fq "未经公证" "$NOTES_PATH" \
    || ! grep -Fq "不能代替" "$NOTES_PATH"; then
    echo "ERROR: unsigned release notes are missing the Gatekeeper warning."
    exit 1
  fi
fi

echo "Release orchestration completed."
echo "  notes: $NOTES_PATH"
echo "  manifest: $MANIFEST_PATH"
echo "  checksums: $SHA256_PATH"
echo "  arm64 dmg: $ARM64_DMG_PATH"
if [[ -n "$X64_DMG_PATH" ]]; then
  echo "  x86_64 dmg: $X64_DMG_PATH"
else
  echo "  x86_64 dmg: (not packaged; bundled runtime has no x86_64 slice)"
fi

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
