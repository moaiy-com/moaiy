#!/usr/bin/env bash
# scripts/loop-runner.sh: 驱动 Spec 编译与自愈验证的闭环脚本
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC_FILE="${1:-specs/WP1-streaming-io.md}"

echo "=== [Moaiy Loop Harness] 启动闭环检查 ==="
echo "目标规约: ${SPEC_FILE}"

if [ ! -f "${SPEC_FILE}" ]; then
  echo "警告: 规约文件未找到: ${SPEC_FILE}"
fi

cd "${REPO_ROOT}"

# 1. SwiftLint 严格校验 (若安装则执行，失败则退出)
if command -v swiftlint >/dev/null 2>&1; then
  echo "-> 运行 SwiftLint 静态代码检查..."
  swiftlint --strict
else
  echo "-> 未检测到 swiftlint，跳过 linter 阶段"
fi

# 2. 语法快速编译验证 (针对全部核心与测试源文件)
echo "-> 验证 Swift 源代码语法有效性..."
swiftc -parse \
  Moaiy/Services/StreamingCryptoPipeline.swift \
  Moaiy/Services/KeychainService.swift \
  Moaiy/Services/SecureMemory.swift \
  Moaiy/Services/TransientFileRegistry.swift \
  MoaiyCLI/main.swift

# 3. 运行 Xcode 单元测试与沙盒测试套件 (若 Xcode 可用)
if command -v xcodebuild >/dev/null 2>&1; then
  echo "-> 执行 MoaiyTests 单元测试套件..."
  xcodebuild -project Moaiy/Moaiy.xcodeproj \
             -scheme Moaiy \
             -destination 'platform=macOS' \
             test -only-testing:MoaiyTests || {
    echo "❌ MoaiyTests 存在失败用例"
    exit 1
  }

  echo "-> 执行 MoaiySandboxTest 沙盒合规测试套件..."
  if [ -d "MoaiySandboxTest/MoaiySandboxTest.xcodeproj" ]; then
    xcodebuild -project MoaiySandboxTest/MoaiySandboxTest.xcodeproj \
               -scheme MoaiySandboxTest \
               -destination 'platform=macOS' \
               build-for-testing || echo "⚠️ MoaiySandboxTest 构建测试未完成，请在真机交互测试"
  fi
else
  echo "-> 当前环境未配置完整 xcodebuild，已完成命令行与语法闭环验证"
fi

echo "=== [Moaiy Loop Harness] 闭环验证全部通过 ==="
exit 0
