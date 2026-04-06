#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/external_validation.sh --version X.Y.Z [options]

Description:
  Runs compatibility validation and exports xcresult summaries.
  If xcodebuild fails with known sandbox macro issue (RB-002), this script
  emits fallback artifacts and exits with code 3.

Options:
  --version <X.Y.Z>         Release version used in output filenames (required)
  --label <name>            Run label used in output filenames (default: external)
  --mode <full|smoke>       Validation mode (default: full)
  --arch <arch>             Optional macOS arch override (arm64 or x86_64)
  --serial-tests <true|false>
                            Force serialized test execution to avoid flaky shared-state races
                            (default: true)
  --scheme <name>           Xcode scheme (default: MoaiyTests)
  --project <path>          Xcode project path (default: <repo>/Moaiy/Moaiy.xcodeproj)
  --derived-data <path>     DerivedData path (default: /tmp/moaiy-deriveddata-release)
  --result-dir <path>       Output directory for xcresult and summaries (default: <repo>/dist/validation)
  -h, --help                Show help

Examples:
  ./scripts/release/external_validation.sh --version 0.5.3 --label arm64-full --arch arm64 --mode full
  ./scripts/release/external_validation.sh --version 0.5.3 --label x64-smoke --arch x86_64 --mode smoke
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"
SCHEME="MoaiyTests"
VERSION=""
LABEL="external"
MODE="full"
ARCH=""
SERIAL_TESTS="true"
DERIVED_DATA_PATH="/tmp/moaiy-deriveddata-release"
RESULT_DIR="$ROOT_DIR/dist/validation"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --label)
      LABEL="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --serial-tests)
      SERIAL_TESTS="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT_PATH="${2:-}"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --result-dir)
      RESULT_DIR="${2:-}"
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
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: --version must match X.Y.Z"
  exit 1
fi

if [[ -z "$LABEL" ]]; then
  echo "ERROR: --label must not be empty"
  exit 1
fi

if [[ "$MODE" != "full" && "$MODE" != "smoke" ]]; then
  echo "ERROR: --mode must be full or smoke"
  exit 1
fi

if [[ -n "$ARCH" && "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "ERROR: --arch must be arm64 or x86_64"
  exit 1
fi

if [[ "$SERIAL_TESTS" != "true" && "$SERIAL_TESTS" != "false" ]]; then
  echo "ERROR: --serial-tests must be true or false"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required"
  exit 1
fi

mkdir -p "$RESULT_DIR"

SAFE_LABEL="$(printf '%s' "$LABEL" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PREFIX="v${VERSION}-${SAFE_LABEL}-${TIMESTAMP}"
RESULT_BUNDLE="$RESULT_DIR/${PREFIX}.xcresult"
SUMMARY_JSON_PATH="$RESULT_DIR/${PREFIX}-summary.json"
SUMMARY_MD_PATH="$RESULT_DIR/${PREFIX}-summary.md"
XCODEBUILD_LOG_PATH="$RESULT_DIR/${PREFIX}-xcodebuild.log"
FALLBACK_CMD_PATH="$RESULT_DIR/${PREFIX}-fallback-command.sh"

if [[ -n "$ARCH" ]]; then
  DESTINATION="platform=macOS,arch=$ARCH"
else
  DESTINATION="platform=macOS"
fi

FULL_TARGETS=(
  "MoaiyTests/KeyGenerationTests"
  "MoaiyTests/KeyImportExportTests"
  "MoaiyTests/KeyManagementIntegrationTests"
  "MoaiyTests/TrustManagementTests"
  "MoaiyTests/GPGServiceTests"
  "MoaiyTests/KeyActionFilePlannerTests"
  "MoaiyTests/KeyActionBatchResultPlannerTests"
  "MoaiyTests/KeyActionMenuAvailabilityTests"
  "MoaiyTests/BackupExportSummaryTests"
  "MoaiyTests/TextEncryptionFlowTests"
  "MoaiyTests/FileEncryptionFlowTests"
)

SMOKE_TARGETS=(
  "MoaiyTests/KeyGenerationTests"
  "MoaiyTests/KeyImportExportTests"
  "MoaiyTests/BackupExportSummaryTests"
  "MoaiyTests/TextEncryptionFlowTests"
  "MoaiyTests/FileEncryptionFlowTests"
)

if [[ "$MODE" == "full" ]]; then
  TEST_TARGETS=("${FULL_TARGETS[@]}")
else
  TEST_TARGETS=("${SMOKE_TARGETS[@]}")
fi

CMD=(
  xcodebuild
  test
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -resultBundlePath "$RESULT_BUNDLE"
)

if [[ "$SERIAL_TESTS" == "true" ]]; then
  CMD+=(
    -parallel-testing-enabled NO
    -maximum-parallel-testing-workers 1
  )
fi

for target in "${TEST_TARGETS[@]}"; do
  CMD+=("-only-testing:${target}")
done

echo "Running external validation..."
echo "  version: $VERSION"
echo "  label: $LABEL"
echo "  mode: $MODE"
echo "  destination: $DESTINATION"
echo "  serial tests: $SERIAL_TESTS"
echo "  result bundle: $RESULT_BUNDLE"
echo "  xcodebuild log: $XCODEBUILD_LOG_PATH"
echo

set +e
"${CMD[@]}" 2>&1 | tee "$XCODEBUILD_LOG_PATH"
XCODEBUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$XCODEBUILD_STATUS" -ne 0 ]]; then
  if grep -E -q 'ObservationMacros|PreviewsMacros|ObservableMacro|SwiftUIView' "$XCODEBUILD_LOG_PATH"; then
    {
      echo '#!/usr/bin/env bash'
      echo 'set -euo pipefail'
      printf '%q ' "${CMD[@]}"
      echo
    } > "$FALLBACK_CMD_PATH"
    chmod +x "$FALLBACK_CMD_PATH"

    cat > "$SUMMARY_JSON_PATH" <<EOF
{
  "version": "$VERSION",
  "mode": "$MODE",
  "result": "Blocked",
  "blockerId": "RB-002",
  "reason": "Sandboxed xcodebuild macro expansion failed",
  "xcodebuildExitCode": $XCODEBUILD_STATUS,
  "label": "$LABEL",
  "destination": "$DESTINATION",
  "xcodebuildLog": "$XCODEBUILD_LOG_PATH",
  "fallbackCommandScript": "$FALLBACK_CMD_PATH"
}
EOF

    cat > "$SUMMARY_MD_PATH" <<EOF
# External Validation Summary

- Version: \`$VERSION\`
- Label: \`$LABEL\`
- Mode: \`$MODE\`
- Result: \`Blocked\`
- Blocker: \`RB-002\` (sandbox macro expansion issue)
- Serial tests: \`$SERIAL_TESTS\`
- xcodebuild exit code: \`$XCODEBUILD_STATUS\`
- Destination: \`$DESTINATION\`
- xcodebuild log: \`$XCODEBUILD_LOG_PATH\`
- Fallback command: \`$FALLBACK_CMD_PATH\`

## Next Action

Run the fallback command outside restricted sandbox on the target machine.
EOF

    echo "Known blocker detected: RB-002."
    echo "Summary: $SUMMARY_MD_PATH"
    exit 3
  fi

  echo "ERROR: xcodebuild failed with exit code $XCODEBUILD_STATUS"
  echo "Inspect log: $XCODEBUILD_LOG_PATH"
  exit "$XCODEBUILD_STATUS"
fi

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "ERROR: expected xcresult bundle is missing: $RESULT_BUNDLE"
  exit 4
fi

SUMMARY_JSON="$(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE")"
printf '%s\n' "$SUMMARY_JSON" > "$SUMMARY_JSON_PATH"

RESULT="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.result')"
PASSED="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.passedTests')"
FAILED="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.failedTests')"
SKIPPED="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.skippedTests')"
TOTAL="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.totalTestCount')"
ARCHITECTURE="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.devicesAndConfigurations[0].device.architecture // "unknown"')"
OS_VERSION="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.devicesAndConfigurations[0].device.osVersion // "unknown"')"
OS_BUILD="$(printf '%s\n' "$SUMMARY_JSON" | jq -r '.devicesAndConfigurations[0].device.osBuildNumber // "unknown"')"

cat > "$SUMMARY_MD_PATH" <<EOF
# External Validation Summary

- Version: \`$VERSION\`
- Label: \`$LABEL\`
- Mode: \`$MODE\`
- Serial tests: \`$SERIAL_TESTS\`
- Result: \`$RESULT\`
- Passed: \`$PASSED\`
- Failed: \`$FAILED\`
- Skipped: \`$SKIPPED\`
- Total: \`$TOTAL\`
- Architecture: \`$ARCHITECTURE\`
- OS: \`$OS_VERSION\` (\`$OS_BUILD\`)
- Result bundle: \`$RESULT_BUNDLE\`
- Summary JSON: \`$SUMMARY_JSON_PATH\`
- Destination: \`$DESTINATION\`
EOF

echo "Validation summary:"
echo "  result      : $RESULT"
echo "  passed/total: $PASSED/$TOTAL"
echo "  failed      : $FAILED"
echo "  architecture: $ARCHITECTURE"
echo "  os          : $OS_VERSION ($OS_BUILD)"
echo "  summary md  : $SUMMARY_MD_PATH"
echo "  summary json: $SUMMARY_JSON_PATH"
echo "  xcresult    : $RESULT_BUNDLE"

if [[ "$RESULT" != "Passed" || "$FAILED" != "0" ]]; then
  exit 2
fi
