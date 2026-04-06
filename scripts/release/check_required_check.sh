#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release/check_required_check.sh --repo owner/name --commit <sha> --check-name <name> [options]

Description:
  Waits for a required check run on a commit and ensures it completes with success.

Options:
  --repo <owner/name>       Repository slug (required)
  --commit <sha>            Commit SHA to validate (required)
  --check-name <name>       Required check run name (required)
  --wait-seconds <n>        Max wait time in seconds (default: 180)
  --poll-interval <n>       Poll interval in seconds (default: 10)
  -h, --help                Show help
EOF
}

REPO=""
COMMIT_SHA=""
CHECK_NAME=""
WAIT_SECONDS=180
POLL_INTERVAL=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --commit)
      COMMIT_SHA="${2:-}"
      shift 2
      ;;
    --check-name)
      CHECK_NAME="${2:-}"
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

if [[ -z "$REPO" || -z "$COMMIT_SHA" || -z "$CHECK_NAME" ]]; then
  echo "ERROR: --repo, --commit, and --check-name are required"
  usage
  exit 1
fi

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --wait-seconds and --poll-interval must be positive integers"
  exit 1
fi

if [[ "$WAIT_SECONDS" -le 0 || "$POLL_INTERVAL" -le 0 ]]; then
  echo "ERROR: --wait-seconds and --poll-interval must be > 0"
  exit 1
fi

MAX_ATTEMPTS=$(( (WAIT_SECONDS + POLL_INTERVAL - 1) / POLL_INTERVAL ))
if [[ "$MAX_ATTEMPTS" -lt 1 ]]; then
  MAX_ATTEMPTS=1
fi

echo "Checking required check run..."
echo "  repo       : $REPO"
echo "  commit     : $COMMIT_SHA"
echo "  check name : $CHECK_NAME"
echo "  wait/poll  : ${WAIT_SECONDS}s / ${POLL_INTERVAL}s"

found_any="false"
last_status=""
last_conclusion=""
last_url=""

for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
  if ! response="$(
    gh api -H "Accept: application/vnd.github+json" \
      "repos/$REPO/commits/$COMMIT_SHA/check-runs?per_page=100"
  )"; then
    echo "WARN: failed to query check-runs on attempt $attempt/$MAX_ATTEMPTS"
  else
    latest_check="$(printf '%s\n' "$response" | jq -c --arg name "$CHECK_NAME" '
      .check_runs
      | map(select(.name == $name))
      | sort_by((.started_at // .completed_at // ""))
      | last // empty
    ')"

    if [[ -n "$latest_check" ]]; then
      found_any="true"
      last_status="$(printf '%s\n' "$latest_check" | jq -r '.status // ""')"
      last_conclusion="$(printf '%s\n' "$latest_check" | jq -r '.conclusion // ""')"
      last_url="$(printf '%s\n' "$latest_check" | jq -r '.html_url // ""')"

      echo "Attempt $attempt/$MAX_ATTEMPTS: status=$last_status conclusion=${last_conclusion:-pending}"

      if [[ "$last_status" == "completed" ]]; then
        if [[ "$last_conclusion" == "success" ]]; then
          echo "Required check passed: $CHECK_NAME"
          exit 0
        fi

        echo "ERROR: required check completed without success"
        echo "  check      : $CHECK_NAME"
        echo "  conclusion : ${last_conclusion:-unknown}"
        if [[ -n "$last_url" ]]; then
          echo "  details    : $last_url"
        fi
        exit 2
      fi
    else
      echo "Attempt $attempt/$MAX_ATTEMPTS: check '$CHECK_NAME' not found yet"
    fi
  fi

  if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
    sleep "$POLL_INTERVAL"
  fi
done

echo "ERROR: timed out waiting for required check '$CHECK_NAME'"
if [[ "$found_any" == "true" ]]; then
  echo "  last status     : ${last_status:-unknown}"
  echo "  last conclusion : ${last_conclusion:-unknown}"
  if [[ -n "$last_url" ]]; then
    echo "  details         : $last_url"
  fi
else
  echo "  no matching check-runs were observed for commit $COMMIT_SHA"
fi
exit 3
