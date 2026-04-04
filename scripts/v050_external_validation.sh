#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/v050_external_validation.sh [options]

Description:
  Runs the v0.5.0 compatibility smoke bundle and exports an xcresult summary
  for external validation environments (for example real Intel or macOS 12.x).
  If xcodebuild fails with known sandbox macro expansion issue (RB-002),
  the script emits actionable fallback artifacts and exits with code 3.

Options:
  --label <name>           Run label used in output filenames (default: external)
  --arch <arch>            Optional macOS arch override (arm64 or x86_64)
  --scheme <name>          Xcode scheme (default: MoaiyTests)
  --project <path>         Xcode project path (default: <repo>/Moaiy/Moaiy.xcodeproj)
  --derived-data <path>    DerivedData path (default: /tmp/moaiy-deriveddata-v050)
  --result-dir <path>      Output directory for xcresult and summaries (default: <repo>/dist/validation)
  -h, --help               Show help

Examples:
  ./scripts/v050_external_validation.sh --label intel-real
  ./scripts/v050_external_validation.sh --label macos12-real
  ./scripts/v050_external_validation.sh --label x86-precheck --arch x86_64
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"
SCHEME="MoaiyTests"
LABEL="external"
ARCH=""
DERIVED_DATA_PATH="/tmp/moaiy-deriveddata-v050"
RESULT_DIR="$ROOT_DIR/dist/validation"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      LABEL="${2:-}"
      shift 2
      ;;
    --arch)
      ARCH="${2:-}"
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

if [[ -z "$LABEL" ]]; then
  echo "ERROR: --label must not be empty"
  exit 1
fi

if [[ -n "$ARCH" && "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "ERROR: --arch must be 'arm64' or 'x86_64'"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

mkdir -p "$RESULT_DIR"

SAFE_LABEL="$(printf '%s' "$LABEL" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESULT_BUNDLE="$RESULT_DIR/v0.5.0-${SAFE_LABEL}-${TIMESTAMP}.xcresult"
SUMMARY_JSON_PATH="$RESULT_DIR/v0.5.0-${SAFE_LABEL}-${TIMESTAMP}-summary.json"
SUMMARY_MD_PATH="$RESULT_DIR/v0.5.0-${SAFE_LABEL}-${TIMESTAMP}-summary.md"
XCODEBUILD_LOG_PATH="$RESULT_DIR/v0.5.0-${SAFE_LABEL}-${TIMESTAMP}-xcodebuild.log"
FALLBACK_CMD_PATH="$RESULT_DIR/v0.5.0-${SAFE_LABEL}-${TIMESTAMP}-fallback-command.sh"

if [[ -n "$ARCH" ]]; then
  DESTINATION="platform=macOS,arch=$ARCH"
else
  DESTINATION="platform=macOS"
fi

TEST_TARGETS=(
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

CMD=(
  xcodebuild
  test
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -resultBundlePath "$RESULT_BUNDLE"
)

for target in "${TEST_TARGETS[@]}"; do
  CMD+=("-only-testing:${target}")
done

echo "Running v0.5.0 compatibility smoke..."
echo "Label: $LABEL"
echo "Destination: $DESTINATION"
echo "Result bundle: $RESULT_BUNDLE"
echo "xcodebuild log: $XCODEBUILD_LOG_PATH"
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
# v0.5.0 External Validation Summary

- Label: \`$LABEL\`
- Result: \`Blocked\`
- Blocker: \`RB-002\` (sandbox macro expansion issue)
- xcodebuild exit code: \`$XCODEBUILD_STATUS\`
- Command destination: \`$DESTINATION\`
- xcodebuild log: \`$XCODEBUILD_LOG_PATH\`
- Fallback command script: \`$FALLBACK_CMD_PATH\`

## Next Action

Run the fallback command outside restricted sandbox on the target machine.
EOF

    echo
    echo "Known blocker detected: RB-002 (sandbox macro expansion issue)."
    echo "Artifacts generated:"
    echo "  summary md  : $SUMMARY_MD_PATH"
    echo "  summary json: $SUMMARY_JSON_PATH"
    echo "  xcodebuild  : $XCODEBUILD_LOG_PATH"
    echo "  fallback cmd: $FALLBACK_CMD_PATH"
    exit 3
  fi

  echo
  echo "ERROR: xcodebuild failed with exit code $XCODEBUILD_STATUS."
  echo "Inspect log: $XCODEBUILD_LOG_PATH"
  exit "$XCODEBUILD_STATUS"
fi

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "ERROR: expected xcresult bundle is missing: $RESULT_BUNDLE"
  echo "Inspect log: $XCODEBUILD_LOG_PATH"
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
# v0.5.0 External Validation Summary

- Label: \`$LABEL\`
- Result: \`$RESULT\`
- Passed: \`$PASSED\`
- Failed: \`$FAILED\`
- Skipped: \`$SKIPPED\`
- Total: \`$TOTAL\`
- Architecture: \`$ARCHITECTURE\`
- OS: \`$OS_VERSION\` (\`$OS_BUILD\`)
- Result bundle: \`$RESULT_BUNDLE\`
- Summary JSON: \`$SUMMARY_JSON_PATH\`
- Command destination: \`$DESTINATION\`
EOF

echo
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
