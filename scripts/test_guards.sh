#!/usr/bin/env bash
# scripts/test_guards.sh: Positive + negative self-tests for deterministic repo guards.
# Ensures every guard script actually fails on known bad inputs (no silent-pass gates).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/moaiy-guard-tests.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

cd "${REPO_ROOT}"

assert_fails() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL [negative-gate]: '${label}' unexpectedly passed!"
    exit 1
  else
    echo "PASS [negative-gate]: '${label}' correctly rejected bad input."
  fi
}

echo "=== [Guard Self-Tests] Running positive baseline checks ==="
python3 scripts/check_architecture_guards.py --root "${REPO_ROOT}"
python3 scripts/check_pro_contracts.py
python3 scripts/check_localization.py --catalog Moaiy/Resources/Localizable.xcstrings

echo "=== [Guard Self-Tests] Running negative-case checks (must fail) ==="

# 1. Negative case: non-empty --passphrase in CLI arguments
NEG_PASS="${TMP_DIR}/neg-passphrase"
mkdir -p "${NEG_PASS}/Moaiy/Services"
cat > "${NEG_PASS}/Moaiy/Services/BadService.swift" << 'EOF'
let args = ["--passphrase", secretVariable]
EOF
assert_fails "nonempty-cli-passphrase" python3 scripts/check_architecture_guards.py --root "${NEG_PASS}"

# 2. Negative case: raw SecItemAdd in View layer
NEG_SEC="${TMP_DIR}/neg-secitem"
mkdir -p "${NEG_SEC}/Moaiy/Views/Settings"
cat > "${NEG_SEC}/Moaiy/Views/Settings/BadView.swift" << 'EOF'
let s = SecItemAdd(query as CFDictionary, nil)
EOF
assert_fails "secitem-in-views" python3 scripts/check_architecture_guards.py --root "${NEG_SEC}"

# 3. Negative case: Process() spawned directly in ViewModel
NEG_PROC="${TMP_DIR}/neg-process"
mkdir -p "${NEG_PROC}/Moaiy/ViewModels"
cat > "${NEG_PROC}/Moaiy/ViewModels/BadVM.swift" << 'EOF'
let p = Process()
EOF
assert_fails "process-in-viewmodel" python3 scripts/check_architecture_guards.py --root "${NEG_PROC}"

# 4. Negative case: hardcoded homebrew gpg path in StreamingCryptoPipeline
NEG_GPG="${TMP_DIR}/neg-gpg-path"
mkdir -p "${NEG_GPG}/Moaiy/Services"
cat > "${NEG_GPG}/Moaiy/Services/StreamingCryptoPipeline.swift" << 'EOF'
let bin = "/opt/homebrew/bin/gpg"
EOF
assert_fails "hardcoded-external-gpg-path" python3 scripts/check_architecture_guards.py --root "${NEG_GPG}"

# 5. Negative case: force try! in Services
NEG_FORCE="${TMP_DIR}/neg-force-try"
mkdir -p "${NEG_FORCE}/Moaiy/Services"
cat > "${NEG_FORCE}/Moaiy/Services/BadForce.swift" << 'EOF'
let data = try! Data(contentsOf: url)
EOF
assert_fails "force-try-in-services" python3 scripts/check_architecture_guards.py --root "${NEG_FORCE}"

# 6. Negative case: Pro contract mismatch
BAD_CONSTANTS="${TMP_DIR}/Constants.swift"
cat > "${BAD_CONSTANTS}" << 'EOF'
enum Pro {
    static let contractsSemanticVersion = "1.0.0"
    static let featureToProductID: [ProFeature: String] = [
        .hardwareKeyAdvanced: "com.moaiy.pro.hardware_key_advanced"
    ]
}
EOF
assert_fails "pro-contracts-missing-mapping" python3 scripts/check_pro_contracts.py --constants "${BAD_CONSTANTS}"

# 7. Negative case: Localization missing translation
BAD_LOC="${TMP_DIR}/Localizable.xcstrings"
cat > "${BAD_LOC}" << 'EOF'
{
  "sourceLanguage": "en",
  "strings": {
    "broken_key": {
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Hello" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "" } }
      }
    }
  }
}
EOF
assert_fails "localization-empty-translation" python3 scripts/check_localization.py --catalog "${BAD_LOC}"

echo "✅ All guard positive & negative self-tests passed!"
