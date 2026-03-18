# Release 模式沙盒测试指南

> **目的**: 验证在 App Store 严格沙盒环境下 GPG 是否正常工作
> **日期**: 2026-03-18

---

## 📋 测试步骤

### 1. 启动 Release 版本

Release 版本已自动启动，如果没有启动，请运行：

```bash
open "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Release/MoaiySandboxTest.app"
```

### 2. 运行测试

在应用窗口中点击 **"Run All Tests"** 按钮

### 3. 观察结果

特别关注以下测试：

| 测试项 | Debug 预期 | Release 预期 | 原因 |
|-------|-----------|-------------|------|
| **System GPG Call** | ⚠️ PASS (宽松) | ❌ **FAIL** | 严格沙盒阻止系统二进制 |
| **Bundled GPG Call** | ✅ PASS | ✅ **PASS** | 内置二进制允许执行 |
| **File Access (No Auth)** | ⚠️ PASS (宽松) | ❌ **FAIL** | 严格沙盒阻止未授权访问 |
| **Container Directory** | ✅ PASS | ✅ **PASS** | 容器目录始终可访问 |
| **Network Access** | ✅ PASS | ✅ **PASS** | 网络权限已启用 |

---

## 🔍 关键区别：Debug vs Release

### Debug 模式（开发时）
```
com.apple.security.get-task-allow = true
```
- ✅ 允许调试器附加
- ⚠️ 沙盒限制较宽松
- ⚠️ 可以访问某些系统资源

### Release 模式（App Store）
```
com.apple.security.get-task-allow = false (或不存在)
```
- ❌ 不允许调试器
- ✅ 完全的沙盒限制
- ✅ 严格的资源访问控制

---

## ✅ 预期结果

### 理想的测试结果（Release 模式）

```
============================================================
📊 Test Summary
============================================================
❌ FAIL - System GPG Call        ← 沙盒正常工作
✅ PASS - Bundled GPG Call       ← 核心功能正常 ✅
❌ FAIL - File Access (No Auth)  ← 沙盒正常工作
✅ PASS - Container Directory    ← 容器访问正常
✅ PASS - Network Access         ← 网络访问正常

Passed: 3/5
```

**注意**: 2 个 FAIL 是**正常的**，说明沙盒在正常工作！

### 最重要的验证

✅ **Bundled GPG Call 必须 PASS**

这是 Moaiy 的核心技术方案，如果这个通过，说明：
- ✅ 可以在 App Store 沙盒环境中使用 GPG
- ✅ 不需要用户单独安装 GPG
- ✅ 完全符合 Apple 的要求

---

## 📊 测试结果记录

请在此记录 Release 模式的测试结果：

### Test 1: System GPG Call
- **预期**: ❌ FAIL
- **实际**: _______
- **说明**: 如果 FAIL，说明沙盒正常阻止系统二进制访问

### Test 2: Bundled GPG Call
- **预期**: ✅ PASS
- **实际**: _______
- **说明**: 这是核心功能，必须 PASS

### Test 3: File Access (No Auth)
- **预期**: ❌ FAIL
- **实际**: _______
- **说明**: 如果 FAIL，说明沙盒正常阻止未授权文件访问

### Test 4: Container Directory
- **预期**: ✅ PASS
- **实际**: _______
- **说明**: 容器目录应该始终可访问

### Test 5: Network Access
- **预期**: ✅ PASS
- **实际**: _______
- **说明**: 网络访问应该正常（已启用 entitlement）

---

## 🎯 验证成功标准

**最低要求**（必须满足）:
- ✅ Bundled GPG Call = PASS
- ✅ Container Directory = PASS
- ✅ Network Access = PASS

**理想结果**（证明沙盒正常）:
- ❌ System GPG Call = FAIL
- ❌ File Access (No Auth) = FAIL

---

## 🔧 如果测试失败

### Bundled GPG Call 失败

1. 检查 GPG 文件是否存在：
   ```bash
   ls -lh "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Release/MoaiySandboxTest.app/Contents/Resources/gpg"
   ```

2. 手动测试 GPG：
   ```bash
   "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Release/MoaiySandboxTest.app/Contents/Resources/gpg" --version
   ```

3. 重新运行修复脚本：
   ```bash
   cd /Users/codingchef/Taugast/moaiy
   ./fix_gpg_deps.sh Release
   ```

### 所有测试都 PASS（包括 System GPG）

说明 Release 版本仍然使用了宽松的沙盒设置。

**解决方法**:
1. 在 Xcode 中检查 Build Settings
2. 确保 Release 配置没有 `get-task-allow`
3. 重新构建

---

## 📝 下一步

测试完成后：

1. **记录结果**: 填写上面的测试结果表格
2. **更新文档**: 更新 `technical-validation-status.md`
3. **继续验证**: 进行加密解密功能测试

---

**提示**: 如果 Bundled GPG Call 在 Release 模式下 PASS，说明 Moaiy 的技术方案完全可行！🎉
