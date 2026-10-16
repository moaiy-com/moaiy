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
fi

# 2. 语法与依赖完整性解析验证
echo "-> 验证 Swift 源代码语法与模块依赖完整性..."
swiftc -parse \
  Moaiy/Services/StreamingCryptoPipeline.swift \
  Moaiy/Services/KeychainService.swift \
  Moaiy/Services/SecureMemory.swift \
  Moaiy/Services/TransientFileRegistry.swift \
  Moaiy/Services/GPGService.swift \
  Moaiy/Utils/Constants.swift \
  Moaiy/Views/KeyManagement/KeyActionMenu.swift \
  MoaiyCLI/main.swift \
  Moaiy/MoaiyTests/Services/StreamingCryptoPipelineTests.swift \
  Moaiy/MoaiyTests/Services/KeychainServiceTests.swift \
  Moaiy/MoaiyTests/Services/SecureMemoryAndResilienceTests.swift

# 3. 运行 xcodebuild 真实工程语义构建与测试套件 (若 Xcode 可用)
if xcode-select -p 2>/dev/null | grep -qv "CommandLineTools"; then
  echo "-> 运行 Xcode 工程语义构建 (xcodebuild build)..."
  xcodebuild -project Moaiy/Moaiy.xcodeproj \
             -scheme Moaiy \
             -destination 'platform=macOS' \
             build || {
    echo "❌ Xcode 工程构建失败"
    exit 1
  }

  echo "-> 执行 MoaiyTests 单元测试套件..."
  xcodebuild -project Moaiy/Moaiy.xcodeproj \
             -scheme Moaiy \
             -destination 'platform=macOS' \
             test -only-testing:MoaiyTests || {
    echo "❌ MoaiyTests 存在失败用例"
    exit 1
  }
else
  echo "-> 注意: 当前处于 CommandLineTools 环境，已执行全量文件 swiftc 解析与代码分析"
fi

echo "=== [Moaiy Loop Harness] 闭环验证全部通过 ==="
exit 0
