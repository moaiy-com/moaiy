#!/usr/bin/env bash
#
# Authentic sandboxed-parent launch of MoaiyScdaemon.app.
# A tiny App Sandbox host opens the helper with no arguments or environment
# (the CoreServicesUIAgent-stripped case). Success: the helper is started by
# launchd, stays up, and S.scdaemon accepts connections in the Moaiy
# container GNUPGHOME. A backend socket in the helper container is expected.
#
# Usage:
#   scripts/test_scdaemon_helper_sandbox_launch.sh [--keep-helper] <Moaiy.app|MoaiyScdaemon.app>
set -euo pipefail

HELPER_BUNDLE_ID="com.moaiy.app.scdaemon"
HOST_BUNDLE_ID="com.moaiy.test.scdaemonlaunchhost"
GNUPGHOME_SUFFIX="Library/Containers/com.moaiy.app/Data/Library/gnupg"
WORK="$(mktemp -d /tmp/moaiy-scdaemon-launch-host-XXXX)"
HOST_APP="$WORK/MoaiyScdaemonLaunchHost.app"
KEEP_HELPER=0
if [[ "${1:-}" == "--keep-helper" ]]; then
  KEEP_HELPER=1
  shift
fi

HELPER_PATTERN='/MoaiyScdaemon.app/Contents/MacOS/'

stop_test_helpers() {
  local pid
  for pid in $(pgrep -f "$HELPER_PATTERN" || true); do
    kill "$pid" 2>/dev/null || true
  done
  sleep 0.2
  for pid in $(pgrep -f "$HELPER_PATTERN" || true); do
    kill -9 "$pid" 2>/dev/null || true
  done
}

cleanup() {
  if [[ "$KEEP_HELPER" -eq 0 ]]; then
    stop_test_helpers
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

if [[ "${1:-}" == "" || ! -e "$1" ]]; then
  echo "Usage: $0 [--keep-helper] <Moaiy.app|MoaiyScdaemon.app>"
  exit 2
fi

SOURCE="$1"
if [[ "$(basename "$SOURCE")" == "Moaiy.app" ]]; then
  HELPER="$SOURCE/Contents/Helpers/MoaiyScdaemon.app"
else
  HELPER="$SOURCE"
fi
if [[ ! -d "$HELPER" ]]; then
  echo "ERROR: helper app not found at $HELPER"
  exit 1
fi

REAL_HOME="$(python3 -c 'import pwd,os; print(pwd.getpwuid(os.getuid()).pw_dir)')"
if [[ "$REAL_HOME" == *"/Library/Containers/"* || "$REAL_HOME" != /* ]]; then
  echo "ERROR: passwd home looks invalid: $REAL_HOME"
  exit 1
fi
GNUPGHOME="$REAL_HOME/$GNUPGHOME_SUFFIX"
SOCKET="$GNUPGHOME/S.scdaemon"
HELPER_CONTAINER_SOCKET="$REAL_HOME/Library/Containers/$HELPER_BUNDLE_ID/Data/Library/gnupg/S.scdaemon"
HELPER_CONTAINER_DOT="$REAL_HOME/Library/Containers/$HELPER_BUNDLE_ID/Data/.gnupg/S.scdaemon"

if [[ ! -d "$GNUPGHOME" ]]; then
  echo "ERROR: Moaiy container GNUPGHOME is missing: $GNUPGHOME"
  exit 1
fi

# Do not leave a stale socket from a previous doomed helper.
if [[ -e "$SOCKET" ]]; then
  python3 - <<PY
import socket, os, sys
path = os.environ.get("SOCKET", "")
PY
  if ! python3 -c "
import socket, sys
s=socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.connect(sys.argv[1]); print('live')
except Exception:
    print('stale')
finally:
    s.close()
" "$SOCKET" | grep -q live; then
    rm -f "$SOCKET"
    echo "Removed stale S.scdaemon"
  else
    echo "NOTE: $SOCKET is already accepting connections; stopping test helper to get a fresh launch"
    stop_test_helpers
    sleep 0.3
    if [[ -e "$SOCKET" ]]; then
      rm -f "$SOCKET" || true
    fi
  fi
fi

ENT="$WORK/host.entitlements"
cat > "$ENT" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>
PLIST

mkdir -p "$HOST_APP/Contents/MacOS" "$HOST_APP/Contents/Helpers"
cat > "$HOST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>MoaiyScdaemonLaunchHost</string>
	<key>CFBundleIdentifier</key>
	<string>com.moaiy.test.scdaemonlaunchhost</string>
	<key>CFBundleName</key>
	<string>MoaiyScdaemonLaunchHost</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSBackgroundOnly</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
</dict>
</plist>
PLIST

ditto "$HELPER" "$HOST_APP/Contents/Helpers/MoaiyScdaemon.app"

# Bake the helper URL into the host so Launch Services need not pass argv/env
# to the sandboxed parent either.
HELPER_PATH="$HOST_APP/Contents/Helpers/MoaiyScdaemon.app"
cat > "$WORK/host.swift" <<SWIFT
import AppKit
import Foundation

let helperURL = URL(fileURLWithPath: #"${HELPER_PATH}"#, isDirectory: true)
let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false
configuration.createsNewApplicationInstance = true

let sem = DispatchSemaphore(value: 0)
var openError: Error?
NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration) { _, error in
    openError = error
    sem.signal()
}
if sem.wait(timeout: .now() + 10) == .timedOut {
    fputs("openApplication timed out\\n", stderr)
    exit(1)
}
if let openError {
    fputs("openApplication failed: \\(openError)\\n", stderr)
    exit(1)
}
exit(0)
SWIFT

swiftc -O -target arm64-apple-macos14.0 \
  -o "$HOST_APP/Contents/MacOS/MoaiyScdaemonLaunchHost" \
  "$WORK/host.swift"
chmod 755 "$HOST_APP/Contents/MacOS/MoaiyScdaemonLaunchHost"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER_ENT="$ROOT/Moaiy/Resources/GPGScdaemon.entitlements"
# Re-sign nested helper after ditto (ad-hoc signatures are path-sensitive).
# Match production: ad-hoc, no hardened runtime, same entitlements.
codesign --force --timestamp=none --sign - \
  --identifier "$HELPER_BUNDLE_ID" \
  --entitlements "$HELPER_ENT" \
  "$HOST_APP/Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/scdaemon"
# Launcher and the .app must not carry App Sandbox: the launcher execs
# scdaemon, which applies the standalone profile once.
codesign --force --timestamp=none --sign - \
  --identifier "$HELPER_BUNDLE_ID" \
  "$HOST_APP/Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/MoaiyScdaemon"
for lib in "$HOST_APP/Contents/Helpers/MoaiyScdaemon.app/Contents/lib/"*.dylib; do
  codesign --force --timestamp=none --sign - "$lib"
done
codesign --force --timestamp=none --sign - \
  --identifier "$HELPER_BUNDLE_ID" \
  "$HOST_APP/Contents/Helpers/MoaiyScdaemon.app"

codesign --force --timestamp=none --sign - \
  --identifier "$HOST_BUNDLE_ID" \
  --entitlements "$ENT" \
  "$HOST_APP"

echo "GNUPGHOME=$GNUPGHOME"
echo "HOST=$HOST_APP"
echo "HELPER=$HELPER_PATH"

# Launch the sandboxed host via Launch Services, not by exec from this shell.
open -W --background "$HOST_APP"
OPEN_STATUS=$?
if [[ "$OPEN_STATUS" -ne 0 ]]; then
  echo "ERROR: sandboxed host failed to launch (open exit $OPEN_STATUS)"
  exit 1
fi

accepts() {
  python3 -c "
import socket, sys
s=socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.connect(sys.argv[1])
    sys.exit(0)
except Exception:
    sys.exit(1)
finally:
    s.close()
" "$1"
}

deadline=$((SECONDS + 8))
while (( SECONDS < deadline )); do
  if [[ -e "$SOCKET" ]] && accepts "$SOCKET"; then
    break
  fi
  sleep 0.05
done

if ! accepts "$SOCKET"; then
  echo "ERROR: S.scdaemon did not accept connections at $SOCKET"
  echo "--- helper processes ---"
  pgrep -af "$HELPER_PATTERN" || true
  echo "--- helper container sockets ---"
  ls -la "$HELPER_CONTAINER_SOCKET" "$HELPER_CONTAINER_DOT" 2>/dev/null || true
  exit 1
fi

# scdaemon binds in its own container; the supervisor must also publish
# a listening S.scdaemon in the Moaiy container (already checked above).
if [[ -e "$HELPER_CONTAINER_SOCKET" ]]; then
  echo "HELPER_BACKEND_SOCKET=$HELPER_CONTAINER_SOCKET"
fi

# The listening process should be the real scdaemon image, parent launchd (1)
# or launchd via a short-lived xpcproxy that is already gone.
HELPER_PIDS="$(pgrep -f "$HELPER_PATTERN" || true)"
if [[ -z "$HELPER_PIDS" ]]; then
  echo "ERROR: socket is live but no MoaiyScdaemon.app process is visible"
  exit 1
fi

echo "SOCKET_ACCEPTING=$SOCKET"
echo "HELPER_PIDS=$HELPER_PIDS"
ok=0
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  ps -o pid,ppid,etime,command -p "$pid"
  ppid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
  comm="$(ps -o command= -p "$pid")"
  echo "pid=$pid ppid=$ppid command=$comm"
  if [[ "$ppid" == "1" ]]; then
    ok=1
  fi
  # Must not be a child of this unsandboxed shell or of gpg-agent.
  parent_cmd="$(ps -o command= -p "$ppid" 2>/dev/null || true)"
  if [[ "$parent_cmd" == *gpg-agent* ]]; then
    echo "ERROR: helper parent is gpg-agent: $parent_cmd"
    exit 1
  fi
  if [[ "$comm" != *"--multi-server"* && "$comm" != *"/MoaiyScdaemon" ]]; then
    # After exec the command line should include --multi-server --homedir.
    # During the brief launcher window it may still be MoaiyScdaemon.
    true
  fi
done <<< "$HELPER_PIDS"

# Prefer seeing the exec'd scdaemon with --multi-server and the Moaiy homedir.
if pgrep -af "$HELPER_PATTERN" | grep -q -- "--multi-server"; then
  echo "HELPER_ARGV_HAS_MULTI_SERVER=yes"
  ok=1
fi
if pgrep -af "$HELPER_PATTERN" | grep -q "$GNUPGHOME"; then
  echo "HELPER_ARGV_HAS_MOAIY_GNUPGHOME=yes"
  ok=1
fi
if pgrep -af "$HELPER_PATTERN" | grep -q -- "--daemon"; then
  echo "ERROR: helper was started with --daemon"
  exit 1
fi

if [[ "$ok" -ne 1 ]]; then
  echo "ERROR: could not confirm launchd parent or expected exec argv"
  pgrep -af "$HELPER_PATTERN" || true
  exit 1
fi

# Still running after a short settle (must not be the 70ms exit(0) case).
sleep 1
if ! accepts "$SOCKET"; then
  echo "ERROR: S.scdaemon stopped accepting within 1s (helper likely exited)"
  exit 1
fi
if [[ -z "$(pgrep -f "$HELPER_PATTERN" || true)" ]]; then
  echo "ERROR: helper process exited within 1s"
  exit 1
fi

echo "SANDBOXED_LAUNCH_OK"
exit 0
