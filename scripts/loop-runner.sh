#!/usr/bin/env bash
# scripts/loop-runner.sh: 驱动 Spec 编译与自愈验证的闭环脚本
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC_FILE="${1:-specs/WP1-streaming-io.md}"

echo "=== [Moaiy Loop Harness] 启动闭环检查: ${SPEC_FILE} ==="

cd "${REPO_ROOT}"

# 1. Swift 语法与格式检查
echo "-> 检查 Swift 源码与工程结构..."
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --strict || echo "SwiftLint 提示警告"
fi

# 2. 编译与单元测试验证
echo "-> 运行测试套件..."
if swift test 2>/dev/null || xcodebuild -workspace Moaiy/Moaiy.xcodeproj/project.xcworkspace -scheme Moaiy test -destination 'platform=macOS' -only-testing:MoaiyTests 2>&1; then
  echo "=== [Moaiy Loop Harness] 闭环验证全部通过 ==="
  exit 0
else
  echo "=== [Moaiy Loop Harness] 测试失败，需要执行自愈修复 ==="
  exit 1
fi
