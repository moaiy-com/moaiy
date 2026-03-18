# Git 仓库设置指南

> **GitHub 仓库**: https://github.com/moaiy-com/moaiy.git
> **日期**: 2026-03-18

---

## 📊 当前项目结构分析

### ✅ 应该加入代码库的文件

#### 1. 文档（重要！）
```
✅ doc/                          # 所有设计文档（已完成的准备工作）
✅ README.md                     # 项目主 README
✅ README_CN.md                  # 中文版 README
✅ AGENTS.md                     # 开发指南（重要！）
```

**原因**: 这些文档包含了完整的产品设计、技术架构、用户体验设计等，是项目的核心资产。

#### 2. 测试项目（已完成的技术验证）
```
✅ MoaiySandboxTest/             # 沙盒测试项目
   ✅ SandboxTestRunner.swift     # 测试代码
   ✅ ContentView.swift           # UI 代码
   ✅ *.xcodeproj/               # Xcode 项目文件
   ✅ Entitlements.entitlements   # 沙盒配置

✅ SandboxTests/                 # 早期测试代码
```

**原因**: 已验证的技术方案，证明 Bundled GPG 在沙盒中可以运行。

#### 3. UI 组件（已完成的部分）
```
✅ MoaiyUI/                      # UI 组件库
   ✅ Components/                # 可复用组件
   ✅ Theme/                     # 主题系统
   ✅ Views/                     # 视图
```

**原因**: 已经开发的基础 UI 组件，可以直接复用。

#### 4. 构建脚本（重要！）
```
✅ fix_gpg_deps.sh               # GPG 依赖修复脚本（核心技术）
✅ scripts/                      # 新创建的脚本目录
   ✅ bundle_gpg.sh              # GPG 打包脚本
   ✅ release.sh                 # 发布脚本
```

#### 5. 配置文件
```
✅ .factory/                     # Factory AI 配置（开发工具）
   ✅ settings.json
   ✅ skills/                    # 自定义技能
```

#### 6. 工作文件
```
⚠️  VERIFICATION_STEPS.md        # 验证步骤（可以加入）
⚠️  RELEASE_SANDBOX_TEST.md      # 测试记录（可以加入）
```

---

### ❌ 应该忽略的文件

#### 1. GPG 二进制文件（不应该加入代码库）
```
❌ MoaiySandboxTest/Resources/bin/gpg    # 1.0 MB
❌ MoaiySandboxTest/Resources/lib/*.dylib # ~3 MB
❌ MoaiySandboxTest/Resources/share/*     # 配置文件
```

**原因**:
- 文件太大（~4 MB）
- 是编译产物，不是源代码
- 可以通过 `scripts/bundle_gpg.sh` 自动生成
- 每个开发者可以从 Homebrew 复制

#### 2. Xcode 构建产物
```
❌ build/
❌ DerivedData/
❌ *.app
❌ *.dSYM
```

#### 3. 临时文件
```
❌ .DS_Store
❌ *.swp
❌ *~
```

---

## 🎯 推荐的代码库结构

### 方案 A: 扁平结构（推荐）

```
moaiy/
├── .github/                    # GitHub 配置
│   └── workflows/              # CI/CD
├── .factory/                   # Factory AI 配置
│   ├── settings.json
│   └── skills/
├── doc/                        # 文档（保留）
│   ├── technical-architecture.md
│   ├── product-design.md
│   └── ...
├── MoaiySandboxTest/           # 沙盒测试项目（保留）
│   ├── MoaiySandboxTest.xcodeproj
│   ├── MoaiySandboxTest/
│   │   ├── SandboxTestRunner.swift
│   │   └── ContentView.swift
│   └── Resources/              # 在 .gitignore 中排除
├── MoaiyUI/                    # UI 组件（保留）
│   ├── Components/
│   ├── Theme/
│   └── Views/
├── scripts/                    # 构建脚本（新增）
│   ├── bundle_gpg.sh
│   └── release.sh
├── .gitignore                  # 忽略规则
├── AGENTS.md                   # 开发指南
├── README.md                   # 项目说明
└── README_CN.md                # 中文说明
```

**优点**:
- ✅ 简单清晰
- ✅ 保留所有已完成的工作
- ✅ 方便继续开发

**缺点**:
- ⚠️ 根目录文件较多

---

### 方案 B: 分离结构（可选）

```
moaiy/
├── .github/
├── .factory/
├── docs/                       # 所有文档移到这里
│   ├── design/                 # 设计文档
│   │   ├── technical-architecture.md
│   │   └── product-design.md
│   └── development/            # 开发文档
│       ├── AGENTS.md
│       └── README.md
├── experiments/                # 实验性项目
│   ├── SandboxTest/           # 沙盒测试
│   └── MoaiyUI/               # UI 原型
├── scripts/
├── src/                        # 主应用代码（未来）
│   └── Moaiy/
└── .gitignore
```

**优点**:
- ✅ 结构更清晰
- ✅ 文档和代码分离

**缺点**:
- ❌ 需要移动很多文件
- ❌ 可能破坏现有路径

---

## 💡 我的建议：使用方案 A

**理由**:
1. ✅ **保留所有已完成的工作** - 文档、测试、UI 组件都是宝贵资产
2. ✅ **最小化破坏** - 不需要移动文件，保持现有路径
3. ✅ **渐进式重构** - 未来可以在不破坏历史的情况下重构
4. ✅ **清晰的 .gitignore** - 排除二进制文件和构建产物

---

## 🚀 执行步骤

### Step 1: 初始化 Git 仓库（5 分钟）

```bash
cd /Users/codingchef/Taugast/moaiy

# 1. 初始化 Git
git init

# 2. 添加远程仓库
git remote add origin https://github.com/moaiy-com/moaiy.git

# 3. 检查状态
git status

# 4. 添加文件（会自动应用 .gitignore）
git add .

# 5. 查看将要提交的文件
git status
```

### Step 2: 验证 .gitignore（2 分钟）

```bash
# 确认 GPG 二进制文件不会被加入
git status | grep -i "gpg\|dylib\|Resources/bin\|Resources/lib" && echo "❌ 错误：二进制文件被包含" || echo "✅ 正确：二进制文件已排除"
```

### Step 3: 创建初始提交（3 分钟）

```bash
# 提交
git commit -m "chore: initial commit

- Add project documentation (design, architecture, usability)
- Add sandbox test project (GPG validation complete)
- Add UI component library (MoaiyUI)
- Add build scripts for GPG bundling
- Configure .gitignore for macOS/Swift projects"

# 推送到 GitHub
git push -u origin main
```

---

## 📊 预期结果

### 将会加入代码库的文件（~50 个文件）

**文档** (~20 个 .md 文件):
- doc/ 下的所有设计文档
- README.md, README_CN.md
- AGENTS.md

**代码** (~30 个 .swift 文件):
- MoaiySandboxTest/ 测试项目
- MoaiyUI/ UI 组件库

**配置** (~5 个文件):
- .factory/ 配置
- .gitignore
- scripts/ 脚本

### 不会加入的文件（已被 .gitignore 排除）

- ❌ MoaiySandboxTest/Resources/bin/gpg (1.0 MB)
- ❌ MoaiySandboxTest/Resources/lib/*.dylib (~3 MB)
- ❌ Xcode DerivedData/ (构建产物)
- ❌ .DS_Store 等系统文件

**总代码库大小**: 预计 ~500 KB（非常合理！）

---

## ✅ 验证清单

- [ ] Git 仓库初始化成功
- [ ] .gitignore 正确排除二进制文件
- [ ] 所有文档都加入代码库
- [ ] 测试项目加入代码库
- [ ] UI 组件加入代码库
- [ ] 构建脚本加入代码库
- [ ] 推送到 GitHub 成功
- [ ] GitHub 仓库显示正确

---

## 🎯 后续步骤

1. **完成 Git 设置**（10 分钟）
   - 执行上述步骤
   - 验证推送成功

2. **开始 Figma 设计**（本周）
   - 基于现有设计系统文档
   - 创建完整的 UI 设计

3. **开始开发**（下周）
   - 创建主应用项目
   - 实现 GPGService
   - 复用 MoaiyUI 组件

---

**准备好了吗？让我们开始设置 Git 仓库！** 🚀
