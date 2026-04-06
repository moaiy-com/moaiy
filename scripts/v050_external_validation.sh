#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HAS_VERSION_FLAG=false
for arg in "$@"; do
  if [[ "$arg" == "--version" ]]; then
    HAS_VERSION_FLAG=true
    break
  fi
done

if [[ "$HAS_VERSION_FLAG" == true ]]; then
  exec "$SCRIPT_DIR/release/external_validation.sh" "$@"
else
  exec "$SCRIPT_DIR/release/external_validation.sh" --version 0.5.0 "$@"
fi
