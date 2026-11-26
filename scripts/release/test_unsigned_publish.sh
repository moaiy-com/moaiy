#!/usr/bin/env bash
# Policy tests for unsigned official publish and architecture-scoped release assets.
# These do not build, sign, tag, or upload a GitHub Release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/moaiy-unsigned-publish.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$label (expected '$expected', actual '$actual')"
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    fail "missing '$needle' in $file"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected '$needle' in $file"
  fi
}

assert_fails_with() {
  local needle="$1"
  shift
  local out="$TMP_DIR/fail-out"
  local err="$TMP_DIR/fail-err"
  local combined="$TMP_DIR/fail-combined"
  if "$@" >"$out" 2>"$err"; then
    fail "command succeeded; expected failure containing '$needle'"
  fi
  cat "$out" "$err" > "$combined"
  if ! grep -Fq "$needle" "$combined"; then
    echo "----- command output -----" >&2
    cat "$combined" >&2
    fail "missing '$needle' in failure output"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
  fi
}

require_cmd jq
require_cmd shasum
require_cmd awk

for script in \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  "$ROOT_DIR/scripts/release/render_release_notes.sh" \
  "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  "$ROOT_DIR/scripts/release/list_release_assets.sh" \
  "$ROOT_DIR/scripts/release/check_version_sync.sh"
do
  bash -n "$script"
done

if grep -Fq "publish mode requires signed artifacts" "$ROOT_DIR/scripts/release/run_release.sh"; then
  fail "run_release.sh still rejects unsigned publish"
fi
if ! grep -Fq "list_release_assets.sh" "$ROOT_DIR/.github/workflows/release.yml"; then
  fail "release workflow does not resolve assets from the manifest"
fi
if ! grep -Fq 'verify_cmd+=(--x86-64-dmg-path' "$ROOT_DIR/.github/workflows/release.yml"; then
  fail "release workflow still requires an Intel DMG unconditionally"
fi

dry_run() {
  local stdout="$1"
  local stderr="$2"
  shift 2
  set +e
  "$@" >"$stdout" 2>"$stderr"
  local status=$?
  set -e
  printf '%s\n' "$status"
}

value_of() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1==key {print substr($0, index($0, "=") + 1)}' "$file"
}

tool_path() {
  local bindir="$1"
  mkdir -p "$bindir"
  for cmd in bash dirname sed head xargs; do
    if [[ ! -e "$bindir/$cmd" ]]; then
      ln -s "$(command -v "$cmd")" "$bindir/$cmd"
    fi
  done
  printf '%s\n' "$bindir"
}

echo "== bundled runtime architecture =="
python3 - "$ROOT_DIR/Moaiy/Resources/gpg.bundle/bin/gpg" <<'PY'
import struct
import sys

data = open(sys.argv[1], "rb").read(8)
magic, cputype = struct.unpack("<II", data)
# Thin MH_MAGIC_64 / CPU_TYPE_ARM64. A universal binary would be FAT_MAGIC
# (0xBEBAFECA little-endian) and must not be treated as arm64-only.
if magic != 0xFEEDFACF or cputype != 0x0100000C:
    raise SystemExit(
        f"bundled gpg is not thin arm64 (magic={magic:#x} cputype={cputype:#x}); "
        "update the release path before dropping or adding an Intel artifact"
    )
print("bundled gpg is a thin arm64 Mach-O")
PY

echo "== dry-run signing policy =="

stdout="$TMP_DIR/stdout"
stderr="$TMP_DIR/stderr"
base_path="$(tool_path "$TMP_DIR/bin")"

status="$(dry_run "$stdout" "$stderr" \
  env -u MOAIY_DEVELOPMENT_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing auto --dry-run)"
assert_eq "$status" "0" "auto publish without a team id"
assert_eq "$(value_of "$stdout" signing_mode)" "unsigned" "auto publish signing mode"
assert_eq "$(value_of "$stdout" build_configuration)" "Debug" "auto publish configuration"
assert_eq "$(value_of "$stdout" supports_x86_64)" "false" "current runtime x86_64 support"
assert_eq "$(value_of "$stdout" release_mode)" "publish" "auto publish mode"
assert_contains "$stderr" "Gatekeeper will block"
assert_contains "$stderr" "not a substitute for a Developer ID signed and notarized release"

status="$(dry_run "$stdout" "$stderr" \
  env -u MOAIY_DEVELOPMENT_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode draft --signing unsigned --dry-run)"
assert_eq "$status" "0" "unsigned draft"
assert_eq "$(value_of "$stdout" signing_mode)" "unsigned" "draft signing mode"
assert_not_contains "$stderr" "publishing an unsigned build"

status="$(dry_run "$stdout" "$stderr" \
  env MOAIY_DEVELOPMENT_TEAM_ID=YOUR_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing auto --dry-run)"
assert_eq "$status" "0" "placeholder team id publish"
assert_eq "$(value_of "$stdout" signing_mode)" "unsigned" "placeholder team id is unsigned"

status="$(dry_run "$stdout" "$stderr" \
  env MOAIY_DEVELOPMENT_TEAM_ID=ABCDE12345 PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing auto --dry-run)"
assert_eq "$status" "0" "auto publish with team id"
assert_eq "$(value_of "$stdout" signing_mode)" "signed" "team id prefers signed"
assert_eq "$(value_of "$stdout" build_configuration)" "Release" "signed configuration"
assert_not_contains "$stderr" "publishing an unsigned build"

status="$(dry_run "$stdout" "$stderr" \
  env MOAIY_DEVELOPMENT_TEAM_ID=ABCDE12345 PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing unsigned --dry-run)"
assert_eq "$status" "0" "explicit unsigned publish with team id"
assert_eq "$(value_of "$stdout" signing_mode)" "unsigned" "explicit unsigned override"
assert_eq "$(value_of "$stdout" build_configuration)" "Debug" "explicit unsigned configuration"
assert_contains "$stderr" "publishing an unsigned build"

status="$(dry_run "$stdout" "$stderr" \
  env -u MOAIY_DEVELOPMENT_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing signed --dry-run)"
assert_eq "$status" "1" "signed publish without a team id"
assert_contains "$stdout" "no valid development team id"

cat > "$base_path/lipo" <<'EOF'
#!/bin/sh
echo "arm64 x86_64"
EOF
chmod +x "$base_path/lipo"
status="$(dry_run "$stdout" "$stderr" \
  env -u MOAIY_DEVELOPMENT_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing auto --dry-run)"
assert_eq "$status" "0" "universal runtime dry-run"
assert_eq "$(value_of "$stdout" supports_x86_64)" "true" "lipo x86_64 slice is kept"

cat > "$base_path/lipo" <<'EOF'
#!/bin/sh
exit 1
EOF
status="$(dry_run "$stdout" "$stderr" \
  env -u MOAIY_DEVELOPMENT_TEAM_ID PATH="$base_path" \
  "$ROOT_DIR/scripts/release/run_release.sh" \
  --version 1.0.5 --mode publish --signing auto --dry-run)"
assert_eq "$status" "1" "unreadable lipo output"
assert_contains "$stderr" "Refusing to guess and omit an Intel artifact."
rm -f "$base_path/lipo"

echo "== release notes =="

CHANGELOG="$TMP_DIR/CHANGELOG.md"
cat > "$CHANGELOG" <<'EOF'
## [9.9.9]

### Changed
- Example change.

### Changed (zh-Hans)
- 示例变更。
EOF

render_case() {
  local signing="$1"
  local gate="$2"
  local with_x86="$3"
  local out="$TMP_DIR/notes-${signing}-${gate}-${with_x86}.md"
  local manifest="$TMP_DIR/manifest-${signing}-${gate}-${with_x86}.json"
  local artifacts sha_map
  if [[ "$with_x86" == "yes" ]]; then
    artifacts='[
      {"name":"Moaiy-9.9.9-macos-apple-silicon.dmg","path":"assets/Moaiy-9.9.9-macos-apple-silicon.dmg","arch":"arm64","size_bytes":10,"sha256":"aaa"},
      {"name":"Moaiy-9.9.9-macos-intel-chip.dmg","path":"assets/Moaiy-9.9.9-macos-intel-chip.dmg","arch":"x86_64","size_bytes":11,"sha256":"bbb"}
    ]'
    sha_map='{"Moaiy-9.9.9-macos-apple-silicon.dmg":"aaa","Moaiy-9.9.9-macos-intel-chip.dmg":"bbb"}'
  else
    artifacts='[
      {"name":"Moaiy-9.9.9-macos-apple-silicon.dmg","path":"assets/Moaiy-9.9.9-macos-apple-silicon.dmg","arch":"arm64","size_bytes":10,"sha256":"aaa"}
    ]'
    sha_map='{"Moaiy-9.9.9-macos-apple-silicon.dmg":"aaa"}'
  fi
  cat > "$manifest" <<EOF
{
  "version": "9.9.9",
  "tag": "v9.9.9",
  "target_commit": "abc123",
  "artifacts": $artifacts,
  "sha256": $sha_map,
  "gate_mode": "$gate",
  "signing_mode": "$signing",
  "pqc_compatibility_caveat": {"enabled": true, "algorithm": "Kyber-768 hybrid OpenPGP"},
  "built_at_utc": "2026-11-26T00:00:00Z"
}
EOF
  "$ROOT_DIR/scripts/release/render_release_notes.sh" \
    --version 9.9.9 \
    --manifest "$manifest" \
    --changelog "$CHANGELOG" \
    --output "$out" >/dev/null
  printf '%s\n' "$out"
}

unsigned_notes="$(render_case unsigned balanced no)"
assert_contains "$unsigned_notes" "not code-signed"
assert_contains "$unsigned_notes" "not notarized"
assert_contains "$unsigned_notes" "Gatekeeper will block"
assert_contains "$unsigned_notes" "not a substitute for a Developer ID signed and notarized release"
assert_contains "$unsigned_notes" "未经代码签名"
assert_contains "$unsigned_notes" "未经公证"
assert_contains "$unsigned_notes" "不能代替"
assert_contains "$unsigned_notes" "Developer ID"
assert_contains "$unsigned_notes" "Apple Silicon"
assert_contains "$unsigned_notes" "Debug build configuration"
assert_not_contains "$unsigned_notes" "Dual-architecture"
assert_not_contains "$unsigned_notes" "x86_64 uses build + smoke"
assert_not_contains "$unsigned_notes" "**Signed build.**"
assert_not_contains "$unsigned_notes" "this package is notarized"

signed_notes="$(render_case signed balanced no)"
assert_contains "$signed_notes" "**Signed build.**"
assert_contains "$signed_notes" "does not notarize"
assert_contains "$signed_notes" "已签名构建"
assert_not_contains "$signed_notes" "not code-signed"
assert_not_contains "$signed_notes" "Gatekeeper will block"
assert_not_contains "$signed_notes" "未经代码签名"

dual_notes="$(render_case unsigned balanced yes)"
assert_contains "$dual_notes" "Dual-architecture"
assert_contains "$dual_notes" "Moaiy-9.9.9-macos-intel-chip.dmg"
assert_contains "$dual_notes" "x86_64 uses build + smoke"
assert_contains "$dual_notes" "Gatekeeper will block"

fast_notes="$(render_case unsigned fast yes)"
assert_contains "$fast_notes" "Dual-architecture"
assert_not_contains "$fast_notes" "x86_64 uses build + smoke"

echo "== asset listing and GitHub verification =="

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

write_release() {
  local dir="$1"
  local with_x86="$2"
  mkdir -p "$dir/assets"
  printf 'arm64-payload' > "$dir/assets/Moaiy-9.9.9-macos-apple-silicon.dmg"
  local arm_sha
  arm_sha="$(sha256_of "$dir/assets/Moaiy-9.9.9-macos-apple-silicon.dmg")"
  local artifacts sha_map sums
  if [[ "$with_x86" == "yes" ]]; then
    printf 'x64-payload' > "$dir/assets/Moaiy-9.9.9-macos-intel-chip.dmg"
    local x64_sha
    x64_sha="$(sha256_of "$dir/assets/Moaiy-9.9.9-macos-intel-chip.dmg")"
    artifacts="[
      {\"name\":\"Moaiy-9.9.9-macos-apple-silicon.dmg\",\"path\":\"assets/Moaiy-9.9.9-macos-apple-silicon.dmg\",\"arch\":\"arm64\",\"size_bytes\":13,\"sha256\":\"$arm_sha\"},
      {\"name\":\"Moaiy-9.9.9-macos-intel-chip.dmg\",\"path\":\"assets/Moaiy-9.9.9-macos-intel-chip.dmg\",\"arch\":\"x86_64\",\"size_bytes\":11,\"sha256\":\"$x64_sha\"}
    ]"
    sha_map="{\"Moaiy-9.9.9-macos-apple-silicon.dmg\":\"$arm_sha\",\"Moaiy-9.9.9-macos-intel-chip.dmg\":\"$x64_sha\"}"
    sums="$(cd "$dir/assets" && shasum -a 256 Moaiy-9.9.9-macos-apple-silicon.dmg Moaiy-9.9.9-macos-intel-chip.dmg)"
  else
    artifacts="[
      {\"name\":\"Moaiy-9.9.9-macos-apple-silicon.dmg\",\"path\":\"assets/Moaiy-9.9.9-macos-apple-silicon.dmg\",\"arch\":\"arm64\",\"size_bytes\":13,\"sha256\":\"$arm_sha\"}
    ]"
    sha_map="{\"Moaiy-9.9.9-macos-apple-silicon.dmg\":\"$arm_sha\"}"
    sums="$(cd "$dir/assets" && shasum -a 256 Moaiy-9.9.9-macos-apple-silicon.dmg)"
  fi
  printf '%s\n' "$sums" > "$dir/SHA256SUMS.txt"
  cat > "$dir/release-manifest.json" <<EOF
{
  "version": "9.9.9",
  "tag": "v9.9.9",
  "target_commit": "abc123",
  "artifacts": $artifacts,
  "sha256": $sha_map,
  "gate_mode": "balanced",
  "signing_mode": "unsigned",
  "built_at_utc": "2026-11-26T00:00:00Z"
}
EOF
}

write_gh_json() {
  local dir="$1"
  local draft="$2"
  local json="$3"
  local assets="[]"
  local name digest
  assets="["
  local first=1
  for file in "$dir/assets/"*.dmg "$dir/SHA256SUMS.txt" "$dir/release-manifest.json"; do
    name="$(basename "$file")"
    digest="sha256:$(sha256_of "$file")"
    if [[ "$first" -eq 0 ]]; then
      assets+=","
    fi
    first=0
    assets+="{\"name\":\"$name\",\"digest\":\"$digest\"}"
  done
  assets+="]"
  cat > "$json" <<EOF
{"tagName":"v9.9.9","isDraft":$draft,"url":"https://example.test/releases/v9.9.9","assets":$assets}
EOF
}

install_gh() {
  local json="$1"
  local bindir="$2"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<EOF
#!/bin/bash
if [[ "\${1:-}" == "release" && "\${2:-}" == "view" ]]; then
  cat "$json"
  exit 0
fi
echo "unexpected gh invocation: \$*" >&2
exit 1
EOF
  chmod +x "$bindir/gh"
}

arm_only="$TMP_DIR/arm-only"
write_release "$arm_only" no
list_out="$TMP_DIR/arm-only-github-output"
"$ROOT_DIR/scripts/release/list_release_assets.sh" \
  --manifest "$arm_only/release-manifest.json" \
  --sha256 "$arm_only/SHA256SUMS.txt" \
  --github-output "$list_out" >/dev/null
assert_eq "$(value_of "$list_out" x86_64_dmg_path)" "" "arm64-only upload omits Intel"
assert_contains "$list_out" "Moaiy-9.9.9-macos-apple-silicon.dmg"
upload_list="$(value_of "$list_out" upload_list_path)"
assert_eq "$(wc -l < "$upload_list" | tr -d ' ')" "3" "arm64-only upload count"

dual="$TMP_DIR/dual"
write_release "$dual" yes
dual_out="$TMP_DIR/dual-github-output"
"$ROOT_DIR/scripts/release/list_release_assets.sh" \
  --manifest "$dual/release-manifest.json" \
  --sha256 "$dual/SHA256SUMS.txt" \
  --github-output "$dual_out" >/dev/null
if [[ -z "$(value_of "$dual_out" x86_64_dmg_path)" ]]; then
  fail "dual-arch manifest dropped the Intel DMG"
fi
dual_upload="$(value_of "$dual_out" upload_list_path)"
assert_eq "$(wc -l < "$dual_upload" | tr -d ' ')" "4" "dual-arch upload count"
assert_contains "$dual_upload" "Moaiy-9.9.9-macos-intel-chip.dmg"

extra="$TMP_DIR/extra-sums"
write_release "$extra" no
printf 'deadbeef  Moaiy-9.9.9-macos-intel-chip.dmg\n' >> "$extra/SHA256SUMS.txt"
assert_fails_with "does not publish" \
  "$ROOT_DIR/scripts/release/list_release_assets.sh" \
  --manifest "$extra/release-manifest.json" \
  --sha256 "$extra/SHA256SUMS.txt"

gh_json="$TMP_DIR/gh-arm.json"
write_gh_json "$arm_only" false "$gh_json"
gh_bin="$TMP_DIR/ghbin"
install_gh "$gh_json" "$gh_bin"
PATH="$gh_bin:$PATH" "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  --repo moaiy-com/moaiy \
  --tag v9.9.9 \
  --mode publish \
  --arm64-dmg-path "$arm_only/assets/Moaiy-9.9.9-macos-apple-silicon.dmg" \
  --sha256-path "$arm_only/SHA256SUMS.txt" \
  --manifest-path "$arm_only/release-manifest.json" \
  --wait-seconds 1 \
  --poll-interval 1 >/dev/null

assert_fails_with "refusing to verify a release that drops it" \
  env PATH="$gh_bin:$PATH" "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  --repo moaiy-com/moaiy \
  --tag v9.9.9 \
  --mode publish \
  --arm64-dmg-path "$dual/assets/Moaiy-9.9.9-macos-apple-silicon.dmg" \
  --sha256-path "$dual/SHA256SUMS.txt" \
  --manifest-path "$dual/release-manifest.json" \
  --wait-seconds 1 \
  --poll-interval 1

assert_fails_with "no x86_64 artifact" \
  env PATH="$gh_bin:$PATH" "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  --repo moaiy-com/moaiy \
  --tag v9.9.9 \
  --mode publish \
  --arm64-dmg-path "$arm_only/assets/Moaiy-9.9.9-macos-apple-silicon.dmg" \
  --x86-64-dmg-path "$dual/assets/Moaiy-9.9.9-macos-intel-chip.dmg" \
  --sha256-path "$arm_only/SHA256SUMS.txt" \
  --manifest-path "$arm_only/release-manifest.json" \
  --wait-seconds 1 \
  --poll-interval 1

dual_json="$TMP_DIR/gh-dual.json"
write_gh_json "$dual" false "$dual_json"
install_gh "$dual_json" "$gh_bin"
PATH="$gh_bin:$PATH" "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  --repo moaiy-com/moaiy \
  --tag v9.9.9 \
  --mode publish \
  --arm64-dmg-path "$dual/assets/Moaiy-9.9.9-macos-apple-silicon.dmg" \
  --x86-64-dmg-path "$dual/assets/Moaiy-9.9.9-macos-intel-chip.dmg" \
  --sha256-path "$dual/SHA256SUMS.txt" \
  --manifest-path "$dual/release-manifest.json" \
  --wait-seconds 1 \
  --poll-interval 1 >/dev/null

draft_json="$TMP_DIR/gh-draft.json"
write_gh_json "$arm_only" true "$draft_json"
install_gh "$draft_json" "$gh_bin"
assert_fails_with "still draft" \
  env PATH="$gh_bin:$PATH" "$ROOT_DIR/scripts/release/verify_github_release.sh" \
  --repo moaiy-com/moaiy \
  --tag v9.9.9 \
  --mode publish \
  --arm64-dmg-path "$arm_only/assets/Moaiy-9.9.9-macos-apple-silicon.dmg" \
  --sha256-path "$arm_only/SHA256SUMS.txt" \
  --manifest-path "$arm_only/release-manifest.json" \
  --wait-seconds 1 \
  --poll-interval 1

echo "== version sync =="
"$ROOT_DIR/scripts/release/check_version_sync.sh" --version 1.0.5 --allow-existing-tag >/dev/null

echo "Unsigned publish policy tests passed."
