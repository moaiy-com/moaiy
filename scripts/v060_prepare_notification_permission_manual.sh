#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/v060_prepare_notification_permission_manual.sh [options]

Description:
  Prepares a manual regression bundle for the notification-permission denial flow
  and optionally resets macOS notification permission for the target bundle ID.

Options:
  --output-dir <path>    Output base directory (default: <repo>/dist/manual-ui)
  --label <name>         Optional run label used in folder name (default: local)
  --bundle-id <id>       App bundle id for permission reset (default: com.moaiy.app)
  --app-path <path>      Optional app bundle path to launch after preparation
  --skip-reset           Do not run tccutil permission reset
  -h, --help             Show help
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_BASE="$ROOT_DIR/dist/manual-ui"
LABEL="local"
BUNDLE_ID="com.moaiy.app"
APP_PATH=""
SKIP_RESET=0

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
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --app-path)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --skip-reset)
      SKIP_RESET=1
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

if [[ -z "$LABEL" ]]; then
  echo "ERROR: --label must not be empty"
  exit 1
fi

SAFE_LABEL="$(printf '%s' "$LABEL" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUTPUT_BASE/v0.6.0-notification-permission-${SAFE_LABEL}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

REPORT_FILE="$RUN_DIR/manual-report-template.md"
README_FILE="$RUN_DIR/README.md"

cat > "$REPORT_FILE" <<'REPORT'
# v0.6.0 Notification Permission Regression Report

## Environment

- Host:
- CPU:
- macOS version:
- Date:
- Runner:
- App build path:
- Bundle id:

## Cases

- NP-01 (Permission denied by system prompt): Pass / Fail / Blocked
- NP-02 (Reminder toggle rollback after denial): Pass / Fail / Blocked
- NP-03 (Permission guidance prompt appears): Pass / Fail / Blocked
- NP-04 (Prompt style consistency with global alert host): Pass / Fail / Blocked
- NP-05 (No reminder scheduled when permission denied): Pass / Fail / Blocked
- NP-06 (Permission granted path keeps toggle enabled): Pass / Fail / Blocked

## Execution Notes

- System prompt choice for NP-01:
- Observed reminder toggle final state:
- Observed prompt title/message:
- Notification center pending requests check command/output:

## Issues

- ID / Severity / Repro / Scope
REPORT

cat > "$README_FILE" <<EOF
# v0.6.0 Notification Permission Manual Bundle

Prepared at: ${TIMESTAMP}

## Files

- Report template: \`${REPORT_FILE}\`

## Recommended flow

1. Launch Moaiy and open Expiration Reminder Settings.
2. Toggle reminder ON when system permission is not granted.
3. In macOS permission prompt, choose "Don't Allow" for NP-01..NP-05.
4. Repeat with "Allow" for NP-06.
5. Fill \`${REPORT_FILE}\` and attach evidence.

## Optional checks

- Pending notification requests can be inspected by app logs.
- Use this run folder as the evidence bundle root.
EOF

if [[ "$SKIP_RESET" -eq 0 ]]; then
  if command -v tccutil >/dev/null 2>&1; then
    echo "Resetting Notifications permission for bundle id: ${BUNDLE_ID}"
    tccutil reset Notifications "$BUNDLE_ID" || true
  else
    echo "WARNING: tccutil not found; skipped permission reset"
  fi
fi

if [[ -n "$APP_PATH" ]]; then
  if [[ -d "$APP_PATH" ]]; then
    echo "Launching app: $APP_PATH"
    open "$APP_PATH"
  else
    echo "WARNING: --app-path does not exist: $APP_PATH"
  fi
fi

echo "Prepared notification-permission manual bundle:"
echo "  run dir : $RUN_DIR"
echo "  report  : $REPORT_FILE"
echo "  readme  : $README_FILE"
