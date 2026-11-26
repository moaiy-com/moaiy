#!/usr/bin/env bash
# Protocol check for scripts/moaiy-pinentry.c. The token is generated at runtime
# and is not passed on argv.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/scripts/moaiy-pinentry.c"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/moaiy-pinentry.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cc -Wall -Wextra -Werror -o "$WORK/pinentry" "$SRC"
HOME_DIR="$WORK/gnupg"
mkdir -m 700 "$HOME_DIR"
TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
printf '%s' "$TOKEN" > "$HOME_DIR/moaiy-pinentry.token"
chmod 600 "$HOME_DIR/moaiy-pinentry.token"

run_pinentry() {
  GNUPGHOME="$HOME_DIR" "$WORK/pinentry"
}

OUTPUT="$(printf '%s\n' 'OPTION ttyname=/dev/tty' 'SETDESC confirm card' 'CONFIRM' 'GETPIN' 'BYE' | run_pinentry)"
printf '%s\n' "$OUTPUT" | grep -q 'OK Your orders please'
printf '%s\n' "$OUTPUT" | grep -q '^D '"$TOKEN"'$'
CONFIRM_OK_COUNT="$(printf '%s\n' "$OUTPUT" | grep -c '^OK$' || true)"
if [[ "$CONFIRM_OK_COUNT" -lt 2 ]]; then
  echo "FAIL: CONFIRM was not acknowledged"
  exit 1
fi

chmod 644 "$HOME_DIR/moaiy-pinentry.token"
LOOSE="$(printf '%s\n' 'GETPIN' 'BYE' | run_pinentry)"
if printf '%s\n' "$LOOSE" | grep -q "$TOKEN"; then
  echo "FAIL: token leaked from a loose token file"
  exit 1
fi
printf '%s\n' "$LOOSE" | grep -q 'ERR 83886179'

rm -f "$HOME_DIR/moaiy-pinentry.token"
MISSING="$(printf '%s\n' 'GETPIN' 'BYE' | run_pinentry)"
printf '%s\n' "$MISSING" | grep -q 'ERR 83886179'

echo "moaiy pinentry protocol checks passed"
