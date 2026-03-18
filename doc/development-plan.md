# Moaiy 开发计划

> **制定日期**: 2026-03-18
> **技术验证状态**: 95% 完成 ✅
> **项目阶段**: 准备开始正式开发

---

## 📊 当前状态总结

### ✅ 已完成
- 技术架构设计
- 产品功能规划
- 品牌和设计系统
- 技术验证（Bundled GPG 在沙盒中可运行）
- 沙盒兼容性测试

### 🎯 核心技术方案确认
✅ **内置 GPG 在沙盒环境中完美运行** - 这是 Moaiy 的核心技术基础

---

## 🚀 Phase 1: 项目初始化（第 1-2 周）

### 1.1 Git 仓库设置

#### 仓库结构
```
moaiy/
├── .github/
│   ├── workflows/           # GitHub Actions CI/CD
│   │   ├── build.yml        # 自动构建
│   │   ├── test.yml         # 自动测试
│   │   └── release.yml      # 自动发布
│   ├── ISSUE_TEMPLATE/      # Issue 模板
│   └── PULL_REQUEST_TEMPLATE.md
├── Moaiy/                   # 主应用（App Store 版本）
│   ├── App/
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   ├── Services/
│   └── Resources/
│       └── gpg.bundle/      # 内置 GPG 工具
├── MoaiyCore/               # 核心库（可复用）
│   ├── GPGService.swift
│   ├── HardwareKeyService.swift
│   └── FileService.swift
├── MoaiyTests/              # 单元测试
├── MoaiyUITests/            # UI 测试
├── SandboxTests/            # 沙盒测试（已存在）
├── docs/                    # 文档（已存在）
├── scripts/                 # 构建脚本
│   ├── bundle_gpg.sh        # 打包 GPG 脚本
│   └── release.sh           # 发布脚本
├── .gitignore
├── .swiftlint.yml           # SwiftLint 配置
├── LICENSE                  # 开源许可证
└── README.md
```

#### Git 分支策略
```
main          # 稳定的发布版本
├── develop   # 开发主分支
│   ├── feature/key-management      # 功能分支
│   ├── feature/encryption          # 功能分支
│   ├── feature/hardware-key        # 功能分支
│   └── bugfix/xxx                  # Bug 修复分支
└── release/v1.0.0   # 发布分支
```

#### 初始化步骤
```bash
# 1. 创建远程仓库（GitHub）
# 2. 本地初始化
cd /Users/codingchef/Taugast/moaiy
git init
git add .
git commit -m "chore: initial commit - technical validation complete"

# 3. 关联远程仓库
git remote add origin https://github.com/your-username/moaiy.git
git push -u origin main

# 4. 创建开发分支
git checkout -b develop
git push -u origin develop
```

#### GitHub Actions CI/CD 配置
```yaml
# .github/workflows/build.yml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode_15.0.app
    
    - name: Build
      run: |
        xcodebuild clean build \
          -project Moaiy.xcodeproj \
          -scheme Moaiy \
          -destination 'platform=macOS' \
          | xcpretty
    
    - name: Run Tests
      run: |
        xcodebuild test \
          -project Moaiy.xcodeproj \
          -scheme Moaiy \
          -destination 'platform=macOS' \
          | xcpretty
```

---

### 1.2 UI 设计路线图

#### 设计系统建立（第 1 周）

基于已有的设计系统文档，创建完整的 UI 组件库：

**1. 色彩系统**
```swift
// Theme/Color+Theme.swift（已存在）
extension Color {
    // Brand Colors
    static let moaiyPrimary = Color("MoaiyPrimary")    // 深蓝灰
    static let moaiySecondary = Color("MoaiySecondary") // 浅灰
    static let moaiyAccent = Color("MoaiyAccent")       // 金色强调
    
    // Semantic Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
}
```

**2. 组件库**
```
MoaiyUI/Components/
├── Buttons/
│   ├── PrimaryButton.swift      # 主要操作按钮
│   ├── SecondaryButton.swift    # 次要操作按钮
│   └── IconButton.swift         # 图标按钮
├── Inputs/
│   ├── SecureInputField.swift   # 密码输入框
│   ├── TextArea.swift           # 多行文本框
│   └── FileDropZone.swift       # 文件拖放区域
├── Cards/
│   ├── KeyCard.swift            # 密钥卡片
│   ├── InfoCard.swift           # 信息卡片
│   └── ActionCard.swift         # 操作卡片
└── Feedback/
    ├── StatusBadge.swift        # 状态徽章（已存在）
    ├── LoadingView.swift        # 加载视图
    └── ErrorView.swift          # 错误视图
```

**3. Figma 设计文件**
- 创建完整的 UI 设计系统
- 包含所有组件的设计规范
- 交互动画和过渡效果

#### 关键界面设计（第 2 周）

**设计策略**: ✅ **Figma 先行** - 先完成所有界面设计，再开始开发

**1. 主界面布局**
```
┌─────────────────────────────────────────────────┐
│  🗿 Moaiy                    [窗口控制按钮]      │
├──────────┬──────────────────────────────────────┤
│          │                                       │
│  密钥管理 │     [主内容区域]                      │
│  加密解密 │                                       │
│  硬件密钥 │     - 密钥列表                        │
│  设置     │     - 操作按钮                        │
│          │     - 详细信息                        │
│          │                                       │
└──────────┴──────────────────────────────────────┘
```

**2. 核心流程设计**
- 密钥生成向导（3 步）
- 加密解密流程（拖拽式）
- 硬件密钥配置（Pro 功能）

**3. Figma 设计清单**
- [ ] 设计系统（色彩、字体、组件）
- [ ] 主界面布局
- [ ] 密钥管理界面
- [ ] 加密解密界面
- [ ] 设置界面
- [ ] 所有对话框和提示
- [ ] 深色模式设计
- [ ] 交互动画

---

## 💻 Phase 2: 核心功能开发（第 3-8 周）

### 开发里程碑

#### Sprint 1（第 3-4 周）：基础架构和密钥管理

**Week 3: 项目架构搭建**
- [ ] 创建 Xcode 项目结构
- [ ] 实现 GPGService 核心类
- [ ] 实现 FileService 文件服务
- [ ] 创建基础 ViewModel
- [ ] 搭建测试框架

**Week 4: 密钥管理功能**
- [ ] 密钥列表显示
- [ ] 密钥生成功能
- [ ] 密钥导入/导出
- [ ] 密钥详情查看
- [ ] 密钥搜索和过滤

**交付物**:
- ✅ 可运行的密钥管理界面
- ✅ 基础的 GPG 命令封装
- ✅ 单元测试覆盖

---

#### Sprint 2（第 5-6 周）：加密解密功能

**Week 5: 文本加密解密**
- [ ] 文本加密界面
- [ ] 文本解密界面
- [ ] 剪贴板集成
- [ ] 收件人选择器
- [ ] 加密结果预览

**Week 6: 文件加密解密**
- [ ] 文件拖放加密
- [ ] 文件拖放解密
- [ ] 批量文件操作
- [ ] 进度显示
- [ ] 安全作用域书签

**交付物**:
- ✅ 完整的文本加密解密功能
- ✅ 完整的文件加密解密功能
- ✅ 用户体验优化

---

#### Sprint 3（第 7-8 周）：高级功能和优化

**Week 7: 智能化和自动化**
- [ ] 智能默认值系统
- [ ] 自动备份功能
- [ ] 错误自动修复
- [ ] 操作历史记录
- [ ] 快捷键支持

**Week 8: 性能优化和测试**
- [ ] 性能分析和优化
- [ ] 内存泄漏检测
- [ ] 完整的测试覆盖
- [ ] UI/UX 打磨
- [ ] Bug 修复

**交付物**:
- ✅ 功能完整的 Beta 版本
- ✅ 测试覆盖率 > 80%
- ✅ 性能优化完成

---

## 🎨 Phase 3: Pro 功能和发布准备（第 9-12 周）

### Sprint 4（第 9-10 周）：硬件密钥支持（Pro）

**Week 9: 硬件密钥基础**
- [ ] YubiKey/CanoKey 检测
- [ ] 硬件密钥状态监控
- [ ] PIN 码管理
- [ ] 密钥槽位管理

**Week 10: 硬件密钥高级功能**
- [ ] 密钥导入到硬件
- [ ] 硬件密钥认证
- [ ] 硬件密钥加密/解密
- [ ] 备份和恢复

**交付物**:
- ✅ 完整的硬件密钥支持
- ✅ Pro 功能完整实现

---

### Sprint 5（第 11-12 周）：发布准备

**Week 11: App Store 准备**
- [ ] 应用图标设计
- [ ] App Store 截图
- [ ] App Store 描述文案
- [ ] 隐私政策和服务条款
- [ ] 代码签名和公证

**Week 12: Beta 测试和发布**
- [ ] 内部 Beta 测试（TestFlight）
- [ ] 外部 Beta 测试（用户测试）
- [ ] Bug 修复和优化
- [ ] App Store 提交
- [ ] 发布准备

**交付物**:
- ✅ App Store 审核通过
- ✅ 正式发布

---

## 📋 优先级排序

### P0 - 必须有（MVP）
1. **Git 仓库设置** - 开发基础
2. **GPGService 实现** - 核心功能
3. **密钥管理** - 基础功能
4. **文本加密解密** - 核心功能
5. **基础 UI** - 用户界面

### P1 - 重要
6. **文件加密解密** - 重要功能
7. **UI 组件库** - 开发效率
8. **测试框架** - 质量保证
9. **错误处理** - 用户体验
10. **性能优化** - 用户体验

### P2 - 可选
11. **硬件密钥支持** - Pro 功能
12. **自动备份** - 便利功能
13. **快捷键** - 效率功能
14. **云端同步** - Pro 功能

---

## 🛠️ 技术栈和工具

### 开发工具
- **Xcode 15+** - 主要 IDE
- **Swift 6.2** - 开发语言
- **SwiftUI** - UI 框架
- **Git/GitHub** - 版本控制
- **GitHub Actions** - CI/CD

### 辅助工具
- **SwiftLint** - 代码风格检查
- **SwiftFormat** - 代码格式化
- **Figma** - UI 设计
- **TestFlight** - Beta 测试

### 第三方库（最小化）
- **尽量避免**第三方依赖
- 如果必须使用，选择：
  - 活跃维护的库
  - 兼容 App Store 沙盒
  - 开源许可证兼容

---

## 📊 资源需求评估

### 时间评估
- **项目初始化**: 2 周
- **核心功能开发**: 6 周
- **Pro 功能和发布**: 4 周
- **总计**: **12 周（3 个月）**

### 人力需求
- **全职开发者**: 1 人
- **UI/UX 设计师**: 兼职或外包（2-3 周）
- **测试人员**: Beta 测试阶段（2-3 周）

### 技能要求
- **Swift/SwiftUI** - 精通
- **macOS 开发** - 熟悉
- **GPG/OpenPGP** - 了解
- **加密技术** - 了解
- **App Store 流程** - 熟悉

---

## 🎯 关键里程碑

| 里程碑 | 时间 | 交付物 | 状态 |
|-------|------|--------|------|
| **项目启动** | 第 1 周 | Git 仓库、开发环境 | ⏳ |
| **架构完成** | 第 3 周 | 基础架构、GPGService | ⏳ |
| **密钥管理** | 第 4 周 | 密钥管理功能完整 | ⏳ |
| **加密解密** | 第 6 周 | 加密解密功能完整 | ⏳ |
| **Beta 版本** | 第 8 周 | 功能完整、可测试 | ⏳ |
| **Pro 功能** | 第 10 周 | 硬件密钥支持 | ⏳ |
| **App Store** | 第 12 周 | 审核通过、正式发布 | ⏳ |

---

## ⚠️ 风险和应对

### 技术风险
- **GPG 集成复杂度**: 已验证，风险低 ✅
- **沙盒限制**: 已验证，风险低 ✅
- **硬件密钥兼容性**: 需要实际设备测试

### 时间风险
- **功能范围蔓延**: 严格控制 MVP 范围
- **技术难题**: 预留缓冲时间（20%）
- **测试不充分**: 自动化测试 + 充分 Beta 测试

### 质量风险
- **代码质量**: Code Review + SwiftLint
- **用户体验**: 可用性测试
- **安全性**: 安全审计 + 加密专家 Review

---

## 💡 其他建议

### 1. 开源策略
- **核心功能开源**（GPLv3）
- **Pro 功能闭源**（商业版）
- **建立社区**：GitHub Discussions

### 2. 文档策略
- **开发者文档**: 代码注释 + README
- **用户文档**: 帮助中心 + FAQ
- **API 文档**: 如果提供 SDK

### 3. 营销准备
- **产品网站**: moaiy.com
- **社交媒体**: Twitter/X、Product Hunt
- **技术博客**: 开发日志、技术分享

### 4. 社区建设
- **早期用户**: Beta 测试群
- **反馈渠道**: GitHub Issues
- **贡献指南**: CONTRIBUTING.md

### 5. 商业模式
- **免费版**: 基础功能，开源
- **Pro 版**: $9.99-19.99，App Store
- **企业版**: 定制服务

---

## 📞 下一步行动

### 立即执行（本周）
1. ✅ 创建 Git 仓库
2. ✅ 设置 GitHub Actions CI/CD
3. ✅ 创建 Xcode 项目结构
4. ✅ 开始 GPGService 实现

### 本月完成
1. ✅ 基础架构搭建
2. ✅ UI 组件库建立
3. ✅ 核心功能开发启动

### 季度目标
1. ✅ MVP 功能完成
2. ✅ Beta 版本发布
3. ✅ 开始 App Store 准备

---

**准备充分，现在开始行动！** 🚀

*最后更新: 2026-03-18*
