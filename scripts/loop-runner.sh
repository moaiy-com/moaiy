#!/usr/bin/env bash
# scripts/loop-runner.sh: 分层闭环验证脚本 (--fast [SuiteName] 快速内循环 / 默认 --full 全量门禁)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="full"
FAST_SUITE=""
SPEC_FILE="specs/WP1-streaming-io.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast)
      MODE="fast"
      if [[ $# -ge 2 && "$2" != --* && "$2" != specs/* ]]; then
        FAST_SUITE="$2"
        shift
      fi
      ;;
    --full)
      MODE="full"
      ;;
    -h|--help)
      echo "Usage: $0 [--fast [SuiteName] | --full] [spec_file]"
      echo "  --fast [Suite]  Inner loop: guards + SwiftLint + CLI + 64MB streaming/GPG + optional single XCTest suite"
      echo "  --full          Full gate (default): all guards + guard self-tests + Debug/Release builds + full MoaiyTests"
      exit 0
      ;;
    *)
      SPEC_FILE="$1"
      ;;
  esac
  shift
done

echo "=== [Moaiy Loop Harness] 启动闭环检查 (mode=${MODE}) ==="
echo "目标规约: ${SPEC_FILE}"

if [ ! -f "${REPO_ROOT}/${SPEC_FILE}" ]; then
  echo "警告: 规约文件未找到: ${SPEC_FILE}"
fi

cd "${REPO_ROOT}"

# 1. 零依赖确定性守卫 + SwiftLint 严格校验
echo "-> [1/5] 运行确定性架构与合规守卫..."
python3 scripts/check_architecture_guards.py --root "${REPO_ROOT}"
python3 scripts/check_pro_contracts.py
python3 scripts/check_localization.py --catalog Moaiy/Resources/Localizable.xcstrings

if [ "${MODE}" = "full" ]; then
  bash scripts/test_guards.sh >/dev/null
  echo "-> 门禁负例自检 (test_guards.sh) 通过"
  ./scripts/appstore-preflight.sh --allow-unsigned-ci >/dev/null
  echo "-> MAS 静态预检 (appstore-preflight.sh --allow-unsigned-ci) 通过"
fi

if command -v swiftlint >/dev/null 2>&1; then
  echo "-> 运行 SwiftLint 严格静态代码检查 (--strict)..."
  swiftlint lint --config .swiftlint.yml --strict
else
  echo "-> SwiftLint 未安装，跳过代码风格扫描（Python 架构守卫已执行）"
fi

# 2. Swift 语义类型检查与工程配置校验
if xcode-select -p 2>/dev/null | grep -qv "CommandLineTools" && xcodebuild -version >/dev/null 2>&1; then
  echo "-> [2/5] 检测到完整 Xcode 环境，全量 Core + UI 类型检查将由第 5 步 xcodebuild 权威执行；校验工程文件..."
  plutil -lint Moaiy/Moaiy.xcodeproj/project.pbxproj
else
  echo "-> [2/5] 当前为 CommandLineTools 环境，执行核心层尽力类型检查 (-typecheck) 与 UI/Tests 语法检查 (-parse)..."
  PLUGIN_ARGS=()
  if [ -d "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins" ]; then
    PLUGIN_ARGS=(-plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins)
  fi

  swiftc -j 8 -typecheck \
    -target arm64-apple-macosx14.0 \
    "${PLUGIN_ARGS[@]}" \
    Moaiy/Models/*.swift \
    Moaiy/Services/*.swift \
    Moaiy/Theme/*.swift \
    Moaiy/Utils/*.swift \
    Moaiy/ViewModels/*.swift

  swiftc -parse \
    Moaiy/App/*.swift \
    Moaiy/Views/*/*.swift \
    Moaiy/MoaiyTests/Services/StreamingCryptoPipelineTests.swift \
    Moaiy/MoaiyTests/Services/KeychainServiceTests.swift \
    Moaiy/MoaiyTests/Services/SecureMemoryAndResilienceTests.swift

  plutil -lint Moaiy/Moaiy.xcodeproj/project.pbxproj
fi

# 3. 编译并验证 MoaiyCLI 可执行程序
echo "-> [3/5] 编译并验证 MoaiyCLI 可执行二进制..."
BUILD_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/moaiy-loop-build.XXXXXX")"
trap 'rm -rf "${BUILD_TMP_DIR}"' EXIT

swiftc -j 8 -O -target arm64-apple-macosx14.0 \
  MoaiyCLI/main.swift \
  -o "${BUILD_TMP_DIR}/moaiy"

"${BUILD_TMP_DIR}/moaiy" --version | grep -q "moaiy version 1.0.2"
"${BUILD_TMP_DIR}/moaiy" --help >/dev/null

# 4. 编译并运行 64MB 流式管道 + GPG 集成验证套件 (含 -strict-concurrency=complete 检查)
echo "-> [4/5] 编译并运行 64MB 流式管道 + GPG 集成测试套件..."
PLUGIN_ARGS=()
if [ -d "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins" ]; then
  PLUGIN_ARGS=(-plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins)
fi

swiftc -j 8 -D DEBUG -strict-concurrency=complete -target arm64-apple-macosx14.0 \
  "${PLUGIN_ARGS[@]}" \
  Moaiy/Models/*.swift \
  Moaiy/Services/*.swift \
  Moaiy/Theme/*.swift \
  Moaiy/Utils/*.swift \
  Moaiy/ViewModels/*.swift \
  scripts/verify-streaming-and-gpg.swift \
  -o "${BUILD_TMP_DIR}/verify-streaming-and-gpg"

"${BUILD_TMP_DIR}/verify-streaming-and-gpg"

# 5. 运行 xcodebuild 工程构建与测试
if xcode-select -p 2>/dev/null | grep -qv "CommandLineTools" && xcodebuild -version >/dev/null 2>&1; then
  if [ "${MODE}" = "fast" ]; then
    echo "-> [5/5] (--fast) 执行 Debug 构建..."
    xcodebuild -project Moaiy/Moaiy.xcodeproj \
               -scheme Moaiy \
               -configuration Debug \
               -destination 'platform=macOS,arch=arm64' \
               build
    if [ -n "${FAST_SUITE}" ]; then
      echo "-> (--fast) 执行定向测试套件: MoaiyTests/${FAST_SUITE}..."
      xcodebuild -project Moaiy/Moaiy.xcodeproj \
                 -scheme MoaiyTests \
                 -destination 'platform=macOS,arch=arm64' \
                 test -only-testing:"MoaiyTests/${FAST_SUITE}"
    else
      echo "-> (--fast) 已跳过全量 MoaiyTests 与 Release 构建（未覆盖范围：其余 XCTest 套件、Release 编译宏）"
    fi
    echo "=== [Moaiy Loop Harness] 快速内循环 (--fast) 通过 ==="
  else
    echo "-> [5/5] 运行 Xcode 工程语义构建 (Moaiy Debug/Release & MoaiyCLI)..."
    xcodebuild -project Moaiy/Moaiy.xcodeproj \
               -scheme Moaiy \
               -configuration Debug \
               -destination 'platform=macOS,arch=arm64' \
               build

    xcodebuild -project Moaiy/Moaiy.xcodeproj \
               -scheme Moaiy \
               -configuration Release \
               -destination 'platform=macOS,arch=arm64' \
               build

    xcodebuild -project Moaiy/Moaiy.xcodeproj \
               -target MoaiyCLI \
               -configuration Debug \
               -arch arm64 \
               SYMROOT="${BUILD_TMP_DIR}/symroot" \
               OBJROOT="${BUILD_TMP_DIR}/objroot" \
               build

    echo "-> 执行 MoaiyTests 单元测试套件..."
    xcodebuild -project Moaiy/Moaiy.xcodeproj \
               -scheme MoaiyTests \
               -destination 'platform=macOS,arch=arm64' \
               test -only-testing:MoaiyTests

    if xcodebuild -list -project Moaiy/Moaiy.xcodeproj 2>/dev/null | grep -q "MoaiySandboxTest"; then
      echo "-> 执行 MoaiySandboxTest 沙盒权限回归验证..."
      xcodebuild -project Moaiy/Moaiy.xcodeproj \
                 -scheme MoaiySandboxTest \
                 -destination 'platform=macOS,arch=arm64' \
                 test
    fi
    echo "=== [Moaiy Loop Harness] Xcode 完整构建 (Debug/Release) 与全量宿主测试通过 ==="
  fi
else
  echo "-> [5/5] 提示: 当前处于 CommandLineTools 环境，仅完成核心层尽力 -typecheck、UI -parse、MoaiyCLI 编译与 7 组 64MB/GPG 集成实测；未执行完整 Xcode UI 类型检查与 XCTest 宿主测试。"
  echo "=== [Moaiy Loop Harness] CommandLineTools 尽力检查通过 (需在完整 Xcode 环境下执行 UI 编译与宿主测试) ==="
fi

exit 0
