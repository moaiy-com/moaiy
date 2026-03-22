# 🧪 简化手动测试指南

## ✅ 自动化测试结果
```
Build: SUCCESS
Files: 1004 行新代码
Keys: 3 个可用密钥
```

---

## 📱 测试流程（15分钟）

### 第一步：启动应用
```bash
open -a Moaiy
```

### 第二步：导航测试 (2分钟)

**测试 1: 密钥列表导航到详情页**

1. 打开应用，点击左侧 "Key Management"
2. ✅ 看到：密钥列表（至少1个密钥）
3. ✅ 点击：任意一个密钥
4. ✅ 验证：进入详情页面（显示详细信息）
5. ✅ 测试：点击左上角返回按钮或侧边栏返回列表

**结果**: ⬜ PASS  /  ⬜ FAIL

---

### 第三步：详情页测试 (5分钟)

**测试 2: 查看密钥详细信息**

在详情页滚动查看所有内容：

✅ **Header Section**:
- 密钥图标（钥匙形状）
- 密钥名称
- 电子邮件
- 密钥类型标签（Private/Public）
- 状态标签（如果有：Expired/Trusted）

✅ **Basic Information**:
- Key ID
- Fingerprint（40个字符，有空格分隔）
- Created 日期
- Expires 日期或 "No Expiration"

✅ **Trust Level**:
- 信任级别图标
- 信任级别名称和描述
- 信任级别指示器（5个级别列表）

✅ **Technical Details**:
- Algorithm（如：RSA）
- Key Length（如：4096 bits）
- Key Type（如：RSA-4096）
- Capabilities badges（Encrypt、Sign、Certify）

**测试指纹复制**:
1. 点击 Fingerprint 文本
2. 打开文本编辑器粘贴
3. ✅ 验证：指纹被正确复制

**结果**: ⬜ PASS  /  ⬜ FAIL

---

### 第四步：导出测试 (3分钟)

**测试 3: 导出公钥到文件**

1. 在详情页点击 "Export Public Key" 按钮
2. ✅ 弹出导出对话框
3. 点击 "Save to File"
4. ✅ 弹出文件保存对话框
5. 保存到桌面（文件名如：Test_User_public.asc）
6. ✅ 验证文件已创建

**验证导出文件**:
```bash
cat ~/Desktop/*_public.asc | head -5
# 应该看到：
# -----BEGIN PGP PUBLIC KEY BLOCK-----
```

**结果**: ⬜ PASS  /  ⬜ FAIL

---

**测试 4: 复制公钥到剪贴板**

1. 再次点击 "Export Public Key"
2. 点击 "Copy to Clipboard"
3. ✅ 对话框关闭
4. 打开文本编辑器粘贴
5. ✅ 验证：看到完整的 PGP PUBLIC KEY BLOCK

**验证剪贴板**:
```bash
pbpaste | head -5
# 应该看到：
# -----BEGIN PGP PUBLIC KEY BLOCK-----
```

**结果**: ⬜ PASS  /  ⬜ FAIL

---

### 第五步：导入测试 (3分钟)

**测试 5: 导入密钥**

**准备工作**（导出一个测试密钥）:
```bash
# 导出一个测试密钥
gpg --armor --export test@example.com > ~/Desktop/test_key.asc
# 或者使用之前导出的密钥
```

1. 返回密钥列表页
2. 点击右上角 "Import Key" 按钮（下载图标）
3. ✅ 弹出导入对话框

**方法 A: 文件选择**
1. 点击 "Select Files"
2. 选择刚才导出的密钥文件
3. ✅ 文件预览显示
4. 点击 "Import Key"
5. ✅ 显示成功消息（绿色横幅）
6. ✅ 2秒后自动关闭

**方法 B: 拖拽导入**
1. 从 Finder 拖拽一个 .asc 文件到导入对话框
2. ✅ 文件预览显示
3. 点击 "Import Key"
4. ✅ 显示成功消息

**结果**: ⬜ PASS  /  ⬜ FAIL

---

### 第六步：删除测试 (2分钟)

**测试 6: 删除密钥**

⚠️ **警告**: 此测试会实际删除密钥！建议使用测试密钥。

1. 进入某个密钥的详情页
2. 滚动到底部 "Actions" 区域
3. 点击红色 "Delete Key" 按钮
4. ✅ 弹出确认对话框："Are you sure..."
5. 点击 "Delete" 确认
6. ✅ 密钥被删除
7. ✅ 自动返回密钥列表
8. ✅ 密钥不再显示在列表中

**如果取消删除**:
5. 点击 "Cancel"
6. ✅ 对话框关闭，密钥仍然存在

**结果**: ⬜ PASS  /  ⬜ FAIL

---

### 第七步：国际化测试 (可选，2分钟)

**测试 7: 中英文切换显示**

**切换到中文**:
```bash
defaults write NSGlobalDomain AppleLanguages -array zh-Hans
killall cfprefsd
killall Moaiy
open -a Moaiy
```

1. ✅ 验证：UI 显示中文
2. ✅ 检查几个关键文本：
   - "密钥管理" (Key Management)
   - "创建密钥" (Create Key)
   - "导入密钥" (Import Key)
   - "导出公钥" (Export Public Key)

**切换回英文**:
```bash
defaults write NSGlobalDomain AppleLanguages -array en
killall cfprefsd
killall Moaiy
open -a Moaiy
```

3. ✅ 验证：UI 显示英文

**结果**: ⬜ PASS  /  ⬜ FAIL

---

## 📊 测试总结

填写测试结果：

| 测试项 | 结果 | 备注 |
|--------|------|------|
| 1. 导航到详情页 | ⬜ PASS / ⬜ FAIL | |
| 2. 查看详细信息 | ⬜ PASS / ⬜ FAIL | |
| 3. 导出公钥到文件 | ⬜ PASS / ⬜ FAIL | |
| 4. 复制公钥到剪贴板 | ⬜ PASS / ⬜ FAIL | |
| 5. 导入密钥 | ⬜ PASS / ⬜ FAIL | |
| 6. 删除密钥 | ⬜ PASS / ⬜ FAIL | |
| 7. 中英文切换 | ⬜ PASS / ⬜ FAIL | |

**总体评估**: ⬜ READY TO COMMIT  /  ⬜ NEEDS FIXES

---

## 🐛 发现的问题

如果发现问题，请记录：

### Issue 1:
**描述**:
**重现步骤**:
**期望行为**:
**实际行为**:

### Issue 2:
**描述**:
**重现步骤**:
**期望行为**:
**实际行为**:

---

## ✅ 完成测试后

如果所有测试通过，执行：

```bash
cd /Users/codingchef/Taugast/moaiy
git add .
git commit -m "feat: implement Key Management Phase 1

- Add KeyDetailView with comprehensive key information display
- Implement key export/import functionality with drag-drop support
- Add key delete functionality with confirmation dialog
- Fix NavigationSplitView configuration for proper navigation
- Add 40+ localization keys for English and Chinese
- Improve navigation and user experience

✅ All manual tests passed
Build Status: SUCCESS
Runtime Status: VERIFIED"
```
