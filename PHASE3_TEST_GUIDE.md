# 🧪 Phase 3 测试指南

## ⚠️ 构建前准备：添加文件到 Xcode

### 方法一：使用 Xcode GUI（推荐）

1. **打开 Xcode 项目**
   ```bash
   open /Users/codingchef/Taugast/moaiy/Moaiy/Moaiy.xcodeproj
   ```

2. **添加三个新文件**
   
   **文件 1: TrustManagementSheet.swift**
   - 在 Xcode 左侧项目导航器中，右键点击 `Moaiy` → `Views` → `KeyManagement` 文件夹
   - 选择 "Add Files to 'Moaiy'..."
   - 导航到并选择：`Views/KeyManagement/TrustManagementSheet.swift`
   - 确保选项：
     - ✅ "Copy items if needed" **不勾选**（文件已存在）
     - ✅ "Create groups" 选中
     - ✅ "Add to targets: Moaiy" 勾选
   - 点击 "Add"
   
   **文件 2: KeySigningSheet.swift**
   - 重复上述步骤，选择 `KeySigningSheet.swift`
   
   **文件 3: KeyEditSheet.swift**
   - 重复上述步骤，选择 `KeyEditSheet.swift`

3. **验证文件已添加**
   - 在项目导航器中应该看到三个新文件
   - 文件应该显示在 `Views/KeyManagement` 文件夹下
   - 文件图标应该是 Swift 文件图标（不是灰色文本文件）

4. **构建项目**
   - 按 `⌘ + B` 或点击 Product → Build
   - 应该显示 "Build Succeeded"

---

### 方法二：使用命令行脚本（快速）

如果 Xcode GUI 方法不工作，可以使用这个脚本：

```bash
cd /Users/codingchef/Taugast/moaiy/Moaiy

# 备份项目文件
cp Moaiy.xcodeproj/project.pbxproj Moaiy.xcodeproj/project.pbxproj.backup

# 使用 Ruby 脚本添加文件（需要安装 xcodeproj gem）
# 如果没有安装：gem install xcodeproj
ruby << 'EOF'
require 'xcodeproj'

project_path = 'Moaiy.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Moaiy' }
main_group = project.main_group

# 找到 Views/KeyManagement 组
views_group = main_group.find_subpath('Views', false)
keymanagement_group = views_group.find_subpath('KeyManagement', false)

# 添加文件
files = [
  'TrustManagementSheet.swift',
  'KeySigningSheet.swift',
  'KeyEditSheet.swift'
]

files.each do |file|
  file_ref = keymanagement_group.new_file("../Views/KeyManagement/#{file}")
  target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "✅ Files added successfully"
EOF

# 验证
xcodebuild -project Moaiy.xcodeproj -scheme Moaiy clean build | grep BUILD
```

---

## 🧪 测试清单

### 测试环境准备

```bash
# 1. 确保有可用的 GPG 密钥
gpg --list-keys

# 如果没有密钥，创建一个测试密钥
gpg --quick-generate-key "Test User <test@example.com>" rsa4096 default 0

# 2. 启动应用
open -a Moaiy
```

---

### 测试 1: 信任管理功能

**前置条件**: 至少有一个密钥

**测试步骤**:

1. **打开信任管理**
   - [ ] 启动 Moaiy 应用
   - [ ] 导航到 Key Management
   - [ ] 点击任意密钥查看详情
   - [ ] 在 Status Section 找到 "Manage" 按钮
   - [ ] 点击 "Manage" 按钮

2. **查看当前信任级别**
   - [ ] Sheet 显示当前信任级别
   - [ ] 显示信任图标和颜色
   - [ ] 显示签名数和最后检查时间

3. **修改信任级别**
   - [ ] 点击不同的信任级别选项
   - [ ] 观察选中状态变化
   - [ ] 点击 "Save" 按钮
   - [ ] 验证保存成功
   - [ ] Sheet 自动关闭
   - [ ] 返回详情页，信任级别已更新

4. **测试 Ultimate 警告**
   - [ ] 再次打开信任管理
   - [ ] 选择 "Ultimate" 级别
   - [ ] 观察警告提示出现
   - [ ] 警告内容正确

**预期结果**: 所有步骤正常工作，信任级别可以成功修改

---

### 测试 2: 密钥签名功能

**前置条件**: 
- 至少有两个密钥（一个用于签名，一个被签名）
- 其中至少有一个私钥

**测试步骤**:

1. **打开签名界面**
   - [ ] 在密钥详情页，找到 Actions Section
   - [ ] 点击 "Sign Key" 按钮
   - [ ] 签名 Sheet 打开

2. **查看被签名密钥信息**
   - [ ] 显示密钥名称、邮箱
   - [ ] 显示指纹（格式化）
   - [ ] 显示当前信任级别徽章

3. **选择签名密钥**
   - [ ] 下拉菜单显示所有私钥
   - [ ] 选择一个签名密钥
   - [ ] 或选择 "Default Key"

4. **输入密码**
   - [ ] 在密码输入框输入密码
   - [ ] 密码显示为隐藏字符

5. **设置信任级别**
   - [ ] Toggle "Set trust level after signing"
   - [ ] 选择 Marginal / Full / Ultimate
   - [ ] 观察选中状态

6. **完成签名**
   - [ ] 点击 "Sign Key" 按钮
   - [ ] 显示进度指示器
   - [ ] 成功后显示成功提示
   - [ ] 点击 OK 关闭

**预期结果**: 签名成功，信任级别更新

---

### 测试 3: 密钥编辑功能

**前置条件**: 有一个可编辑的私钥

#### 3.1 编辑过期时间

**测试步骤**:

1. **打开编辑界面**
   - [ ] 在密钥详情页工具栏，点击 "Edit" 按钮
   - [ ] 编辑 Sheet 打开，默认显示 Expiration 标签

2. **查看当前过期时间**
   - [ ] 如果有设置过期时间，显示当前值
   - [ ] 如果没有，显示说明文字

3. **选择新的过期选项**
   - [ ] 测试 "Never" 选项
   - [ ] 测试 "1 Year" 选项
   - [ ] 测试 "2 Years" 选项
   - [ ] 测试 "5 Years" 选项
   - [ ] 测试 "Custom Date" 选项
     - [ ] Date picker 出现
     - [ ] 可以选择未来日期

4. **应用更改**
   - [ ] 点击 "Apply" 按钮
   - [ ] 显示成功提示
   - [ ] Sheet 关闭

**注意**: 当前是模拟实现，实际 GPG 操作需要后端支持

#### 3.2 添加用户 ID

**测试步骤**:

1. **切换到 User IDs 标签**
   - [ ] 点击 "User IDs" 标签
   - [ ] 显示当前用户 ID 列表
   - [ ] 主 ID 有 "primary" 标记

2. **添加新用户 ID**
   - [ ] 输入新名称
   - [ ] 输入新邮箱
   - [ ] 点击 "Add" 按钮
   - [ ] 显示成功提示

3. **验证输入验证**
   - [ ] 空名称时按钮禁用
   - [ ] 空邮箱时按钮禁用

**注意**: 当前是模拟实现

#### 3.3 更改密码

**测试步骤**:

1. **切换到 Passphrase 标签**
   - [ ] 点击 "Passphrase" 标签
   - [ ] 显示三个密码输入框

2. **输入密码**
   - [ ] 输入当前密码
   - [ ] 输入新密码
   - [ ] 确认新密码

3. **测试验证**
   - [ ] 新密码不匹配时显示错误
   - [ ] 新密码不匹配时按钮禁用
   - [ ] 所有字段填写后按钮启用

4. **保存更改**
   - [ ] 点击 "Save" 按钮
   - [ ] 显示成功提示

**注意**: 当前是模拟实现

---

### 测试 4: 本地化测试

**测试步骤**:

1. **切换到中文**
   ```bash
   defaults write NSGlobalDomain AppleLanguages -array zh-Hans
   killall cfprefsd
   killall Moaiy
   open -a Moaiy
   ```

2. **验证中文显示**
   - [ ] 信任管理界面：所有文本显示中文
   - [ ] 签名界面：所有文本显示中文
   - [ ] 编辑界面：所有文本显示中文
   - [ ] 按钮文本：中文
   - [ ] 错误消息：中文

3. **切换回英文**
   ```bash
   defaults write NSGlobalDomain AppleLanguages -array en
   killall cfprefsd
   killall Moaiy
   open -a Moaiy
   ```

4. **验证英文显示**
   - [ ] 所有界面显示英文
   - [ ] 无中文残留

---

### 测试 5: 错误处理测试

**测试场景**:

1. **无私钥时的签名**
   - [ ] 只保留公钥
   - [ ] 尝试打开签名界面
   - [ ] 显示 "No secret keys available" 警告
   - [ ] Sign 按钮禁用

2. **密码错误**
   - [ ] 在签名界面输入错误密码
   - [ ] 点击 Sign
   - [ ] 显示错误提示
   - [ ] 可以重试

3. **网络或 GPG 错误**
   - [ ] 模拟 GPG 命令失败
   - [ ] 显示友好的错误消息
   - [ ] 提供重试选项

---

## 📊 测试结果记录

### 测试总结表

| 功能模块 | 测试项 | 状态 | 备注 |
|---------|-------|------|------|
| **信任管理** | 打开 Sheet | ⬜ | |
| | 查看当前级别 | ⬜ | |
| | 修改级别 | ⬜ | |
| | Ultimate 警告 | ⬜ | |
| **密钥签名** | 打开 Sheet | ⬜ | |
| | 选择签名密钥 | ⬜ | |
| | 输入密码 | ⬜ | |
| | 设置信任 | ⬜ | |
| | 完成签名 | ⬜ | |
| **密钥编辑** | Expiration 标签 | ⬜ | |
| | User IDs 标签 | ⬜ | |
| | Passphrase 标签 | ⬜ | |
| | 输入验证 | ⬜ | |
| **本地化** | 中文显示 | ⬜ | |
| | 英文显示 | ⬜ | |
| **错误处理** | 无私钥警告 | ⬜ | |
| | 密码错误 | ⬜ | |

**图例**: ✅ PASS | ❌ FAIL | ⬜ NOT TESTED

---

## 🐛 问题跟踪

### 问题 1
**描述**: 
**严重性**: Critical / High / Medium / Low
**重现步骤**:
1. 
2. 
**预期**: 
**实际**: 
**解决方案**: 

### 问题 2
**描述**: 
**严重性**: 
**重现步骤**:
**预期**: 
**实际**: 
**解决方案**: 

---

## ✅ 测试完成标准

- [ ] 所有核心功能测试通过
- [ ] 无 Critical 或 High 严重性问题
- [ ] 本地化完整（中英文）
- [ ] 错误处理正常
- [ ] 构建成功，无编译错误

---

## 📝 测试报告模板

**测试日期**: 
**测试人员**: 
**测试环境**:
- macOS 版本: 
- Xcode 版本: 
- Moaiy 版本: 

**总体评估**: ⬜ READY FOR RELEASE / ⬜ NEEDS FIXES / ⬜ BLOCKED

**关键发现**:
1. 
2. 
3. 

**建议**:
1. 
2. 
3. 

---

**创建日期**: 2026-03-22
**最后更新**: 2026-03-22
