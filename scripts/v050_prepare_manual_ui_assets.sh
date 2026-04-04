#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/v050_prepare_manual_ui_assets.sh [options]

Description:
  Prepares assets and a report template for v0.5.0 manual UI regression
  (MR-01 to MR-05, MR-08) on the current machine.

Options:
  --output-dir <path>   Output base directory (default: <repo>/dist/manual-ui)
  --label <name>        Optional run label used in folder name (default: local)
  -h, --help            Show help
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_BASE="$ROOT_DIR/dist/manual-ui"
LABEL="local"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_BASE="${2:-}"
      shift 2
      ;;
    --label)
      LABEL="${2:-}"
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

SAFE_LABEL="$(printf '%s' "$LABEL" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUTPUT_BASE/v0.5.0-manual-${SAFE_LABEL}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

PLAIN_FILE="$RUN_DIR/plain.txt"
REPORT_FILE="$RUN_DIR/manual-report-template.md"
README_FILE="$RUN_DIR/README.md"

cat > "$PLAIN_FILE" <<EOF
hello moaiy
manual-run-label: ${LABEL}
prepared-at: ${TIMESTAMP}
EOF

cat > "$REPORT_FILE" <<'EOF'
# v0.5.0 Manual UI Regression Report

## Environment

- Host:
- CPU:
- macOS version:
- Date:
- Runner:

## Cases

- MR-01 (Create key): Pass / Fail / Blocked
- MR-02 (Import public key): Pass / Fail / Blocked
- MR-03 (Import secret key): Pass / Fail / Blocked
- MR-04 (Export public key): Pass / Fail / Blocked
- MR-05 (Export private key): Pass / Fail / Blocked
- MR-08 (File encrypt/decrypt UI path): Pass / Fail / Blocked

## Artifacts

- plain.txt path:
- imported public key file (`pub.asc`) path:
- imported secret key file (`sec.asc`) path:
- exported public key path:
- exported private key path:
- encrypted file path:
- decrypted file path:

## Issues

- ID / Severity / Repro / Scope
EOF

cat > "$README_FILE" <<EOF
# v0.5.0 Manual UI Assets

Prepared assets for manual UI regression.

## Files

- plain text sample: \`${PLAIN_FILE}\`
- report template: \`${REPORT_FILE}\`

## Notes

- You still need key material files (\`pub.asc\`, \`sec.asc\`) from your own keyring flow.
- Fill report template and sync results back into:
  - \`doc/v0.5.0-d4-manual-regression-script.md\`
  - \`doc/v0.5.0-d4-regression-matrix.md\`
  - \`doc/v0.5.0-minimal-release-checklist.md\`
EOF

echo "Prepared manual UI asset bundle:"
echo "  run dir    : $RUN_DIR"
echo "  plain file : $PLAIN_FILE"
echo "  report     : $REPORT_FILE"
echo "  readme     : $README_FILE"
