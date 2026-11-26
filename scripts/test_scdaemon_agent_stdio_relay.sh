#!/usr/bin/env bash
# Proves the launcher, when invoked the way gpg-agent pipe-connects
# scdaemon-program (--multi-server --homedir), relays Assuan stdio to the
# published S.scdaemon and rewrites GETINFO socket_name to that path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Moaiy/Resources/scdaemon_launcher.c"
WORKDIR="$(mktemp -d /tmp/moaiy-stdio-relay.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

cc -Wall -Werror -O2 -o "$WORKDIR/MoaiyScdaemon" "$SRC"

HOME_DIR="$WORKDIR/gnupg"
mkdir -p "$HOME_DIR"
SOCK="$HOME_DIR/S.scdaemon"
HELPER_PATH="$WORKDIR/helper-container/S.scdaemon"

python3 - "$SOCK" "$HELPER_PATH" "$WORKDIR/server.ready" "$WORKDIR/server.err" << 'PY' &
import os, socket, sys, threading

sock_path, helper_path, ready_path, err_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    os.unlink(sock_path)
except FileNotFoundError:
    pass
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sock_path)
server.listen(4)
os.chmod(sock_path, 0o700)
open(ready_path, "w").close()

def handle(conn):
    try:
        conn.sendall(b"OK GNU Privacy Guard's Smartcard server ready, process 1\n")
        buf = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                cmd = line.strip()
                if cmd == b"GETINFO socket_name":
                    conn.sendall(b"D " + helper_path.encode() + b"\nOK\n")
                elif cmd == b"SERIALNO":
                    conn.sendall(b"S SERIALNO TESTSERIAL\nOK\n")
                elif cmd == b"BYE" or cmd == b"/bye":
                    conn.sendall(b"OK\n")
                    return
                else:
                    conn.sendall(b"OK\n")
    finally:
        conn.close()

try:
    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()
except Exception as exc:
    open(err_path, "w").write(str(exc))
PY
SERVER_PID=$!

for i in $(seq 1 50); do
  [[ -e "$WORKDIR/server.ready" ]] && break
  sleep 0.05
done
if [[ ! -e "$WORKDIR/server.ready" ]]; then
  echo "FAIL: mock S.scdaemon did not start"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

# Exercise the launcher the way gpg-agent does: pipe Assuan on stdio.
OUT="$WORKDIR/client.out"
if ! printf 'GETINFO socket_name\nSERIALNO\nBYE\n' | "$WORKDIR/MoaiyScdaemon" --homedir "$HOME_DIR" --multi-server >"$OUT"; then
  echo "FAIL: launcher stdio relay exited non-zero"
  cat "$OUT" || true
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

if ! grep -q "OK GNU Privacy Guard's Smartcard server ready" "$OUT"; then
  echo "FAIL: missing Assuan greeting"
  cat "$OUT"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi
if grep -q "$HELPER_PATH" "$OUT"; then
  echo "FAIL: helper-container socket path leaked to the agent"
  cat "$OUT"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi
if ! grep -qx "D $SOCK" "$OUT"; then
  echo "FAIL: GETINFO socket_name was not rewritten to the published socket"
  cat "$OUT"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi
if ! grep -q "S SERIALNO TESTSERIAL" "$OUT"; then
  echo "FAIL: SERIALNO was not relayed"
  cat "$OUT"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

# Unsafe homedir must be rejected (no Assuan started).
if printf 'GETINFO socket_name\n' | "$WORKDIR/MoaiyScdaemon" --homedir "$HOME_DIR/../gnupg" --multi-server >"$WORKDIR/reject.out" 2>"$WORKDIR/reject.err"; then
  echo "FAIL: expected invalid --homedir to fail"
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true
echo "PASS: launcher stdio relay rewrites GETINFO socket_name and relays SERIALNO"
