# Bundled GPG 人工验证步骤

> **目的**: 验证 Bundled GPG 在沙盒环境中可以正常运行
> **日期**: 2026-03-18

---

## ✅ 验证清单

### 1. 验证 GPG 二进制文件

**在终端运行**:
```bash
# 检查 GPG 是否存在
ls -lh "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg"

# 测试 GPG 版本
"/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg" --version
```

**预期结果**:
```
gpg (GnuPG) 2.5.18
libgcrypt 1.12.1
...
```

---

### 2. 验证依赖库

**在终端运行**:
```bash
# 检查所有库文件
ls -lh "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/lib/"
```

**预期结果**: 应该看到 7 个 .dylib 文件：
- libassuan.9.dylib
- libgcrypt.20.dylib
- libgpg-error.0.dylib
- libintl.8.dylib
- libncurses.5.4.dylib
- libnpth.0.dylib
- libreadline.8.dylib

---

### 3. 验证依赖路径

**在终端运行**:
```bash
# 检查 GPG 的依赖路径
otool -L "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg" | grep "@executable_path"
```

**预期结果**: 所有库路径应该指向 `@executable_path/../Resources/lib/`

---

### 4. 在沙盒应用中验证（最重要）

**步骤**:
1. 打开 Xcode 项目:
   ```bash
   open /Users/codingchef/Taugast/moaiy/MoaiySandboxTest/MoaiySandboxTest.xcodeproj
   ```

2. 在 Xcode 中运行应用（Cmd+R）

3. 点击 "Run All Tests" 按钮

4. 观察 "Bundled GPG Call" 测试结果

**预期结果**: ✅ PASS

---

### 5. 验证实际加密功能（可选）

**在终端运行**:
```bash
# 设置 GPG 路径
export GPG="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg"

# 列出现有密钥
$GPG --list-keys

# 测试加密（如果有密钥）
echo "Hello Moaiy" | $GPG --armor --encrypt --recipient <your-email> | head -10
```

---

## 🔍 验证沙盒是否真正生效

### 方法 A: 检查 Entitlements

```bash
codesign -d --entitlements - "/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app"
```

**应该看到**:
```
com.apple.security.app-sandbox = true
```

### 方法 B: 尝试访问禁止的资源

在沙盒应用中，尝试：
1. 访问 `/etc/passwd` - 应该失败
2. 访问 `~/Desktop/test.txt` - 应该失败（未授权）
3. 访问应用容器目录 - 应该成功

---

## 📊 验证结果记录表

| 验证项 | 命令 | 预期结果 | 实际结果 | 状态 |
|-------|------|---------|---------|------|
| GPG 版本 | `gpg --version` | 显示 2.5.18 | | |
| 依赖库存在 | `ls lib/` | 7 个 .dylib | | |
| 依赖路径正确 | `otool -L` | @executable_path | | |
| 沙盒测试 PASS | Xcode 运行 | ✅ PASS | | |
| 沙盒已启用 | `codesign -d` | app-sandbox=true | | |

---

## 🎯 快速验证脚本

**一键验证**:
```bash
bash /tmp/verify_bundled_gpg.sh
```

这个脚本会自动执行所有验证步骤。

---

## ⚠️ 常见问题

### Q1: GPG 执行失败 "Killed: 9"
**原因**: 代码签名损坏
**解决**: 运行 `./fix_gpg_deps.sh` 重新签名

### Q2: 库加载失败 "Library not loaded"
**原因**: 依赖路径不正确
**解决**: 检查 `otool -L` 输出，确保路径指向 `@executable_path`

### Q3: 沙盒测试失败
**原因**: 可能沙盒配置问题
**解决**: 检查 `Entitlements.entitlements` 文件

---

## 📝 验证完成签名

- [ ] 已验证 GPG 版本输出正确
- [ ] 已验证所有依赖库存在
- [ ] 已验证依赖路径正确
- [ ] 已在沙盒应用中测试通过
- [ ] 已验证沙盒配置正确

**验证人**: _______________
**日期**: _______________
