# Moaiy 开源 UI/UX 快速构建方案

> 利用开源资源加速 macOS SwiftUI 应用开发

## 推荐方案概览

| 类别 | 推荐方案 | 用途 |
|------|----------|------|
| **SwiftUI 组件库** | 系统原生 + 少量增强 | 基础 UI 构建 |
| **图标** | SF Symbols (免费) | 所有图标需求 |
| **动画** | Lottie / SwiftUI 动画 | 高质量动画效果 |
| **Figma 设计系统** | 免费模板 | 快速开始设计 |
| **代码模板** | macOS App 模板 | 项目脚手架 |

---

## 1. SwiftUI 组件库推荐

### 1.1 为什么推荐系统原生？

对于 macOS 应用，**强烈推荐优先使用 SwiftUI 原生组件**：

| 优势 | 说明 |
|------|------|
| ✅ 原生体验 | 完美符合 macOS Human Interface Guidelines |
| ✅ 自动适配 | 深色模式、辅助功能、系统偏好 |
| ✅ 零依赖 | 不增加包体积，不会过时 |
| ✅ App Store 友好 | 审核无风险 |

### 1.2 推荐的增强库

#### A. SwiftUI-Introspect ⭐⭐⭐⭐⭐
**用途**: 访问底层 UIKit/AppKit 组件进行精细控制

```swift
// GitHub: siteline/swiftui-introspect
// 安装: Swift Package Manager
.url("https://github.com/siteline/swiftui-introspect")

// 示例：自定义 List 外观
List {
    // ...
}
.introspect(.list, on: .macOS(.v12)) { scrollView in
    scrollView.backgroundColor = NSColor.windowBackgroundColor
}
```

#### B. Lottie for Swift ⭐⭐⭐⭐
**用途**: 播放 After Effects 动画

```swift
// GitHub: airbnb/lottie-ios
// 安装: Swift Package Manager
.url("https://github.com/airbnb/lottie-ios")

// 示例：播放动画
LottieView(animation: .named("success"))
    .playing()
    .looping(false)
```

**免费动画资源**: [LottieFiles.com](https://lottiefiles.com)

#### C. MarkdownUI ⭐⭐⭐⭐
**用途**: 渲染 Markdown 内容（用于帮助文档、提示等）

```swift
// GitHub: gonzalezreal/swift-markdown-ui
.url("https://github.com/gonzalezreal/swift-markdown-ui")

// 示例
Markdown("""
# 欢迎使用 Moaiy
    
这是 **加密** 工具，保护您的秘密。
""")
```

#### D. FloatingLabelTextFieldSwiftUI ⭐⭐⭐
**用途**: 带浮动标签的输入框（更现代的 UI）

```swift
// GitHub: kudoleh/iOS-Clean-Architecture-MVVM
// 或自行实现（SwiftUI 原生可以实现类似效果）
```

### 1.3 不推荐的库（避坑指南）

| 库名 | 原因 |
|------|------|
| Material 设计风格库 | 不符合 macOS 风格 |
| 重量级 UI 框架 | 增加包体积，可能与系统冲突 |
| 仅支持 iOS 的库 | 无法在 macOS 使用 |

---

## 2. SF Symbols - 免费图标库

### 2.1 简介
Apple 官方提供的图标库，**完全免费**，包含 **5000+ 图标**。

### 2.2 使用方式

```swift
// 基础使用
Image(systemName: "lock.fill")

// 自定义样式
Image(systemName: "key.fill")
    .font(.title)
    .foregroundStyle(.securityGreen)

// 渲染模式
Image(systemName: "lock.shield")
    .symbolRenderingMode(.multicolor)  // 自动着色
```

### 2.3 Moaiy 常用图标

| 用途 | SF Symbol 名称 |
|------|----------------|
| 密钥 | `key.fill`, `key` |
| 加密 | `lock.fill`, `lock.shield.fill` |
| 解密 | `lock.open.fill` |
| 安全 | `shield.fill`, `checkmark.shield.fill` |
| 警告 | `exclamationmark.triangle.fill` |
| 成功 | `checkmark.circle.fill` |
| 设置 | `gearshape.fill` |
| 文件 | `doc.fill`, `folder.fill` |
| 分享 | `square.and.arrow.up` |
| 备份 | `externaldrive.fill` |

### 2.4 下载地址
[developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols/)

### 2.5 SF Symbols App
下载官方 App，可以：
- 浏览所有图标
- 搜索图标
- 查看不同渲染效果
- 导出 SVG（用于 Figma）

---

## 3. 免费动画资源

### 3.1 LottieFiles（推荐）

**网站**: [lottiefiles.com](https://lottiefiles.com)

**免费动画示例**:
| 动画类型 | 用途 |
|----------|------|
| 成功勾选 | 加密/解密完成 |
| 加载动画 | 等待处理 |
| 盾牌保护 | 安全提示 |
| 锁定动画 | 加密过程 |

**使用步骤**:
1. 在 LottieFiles 搜索动画（如 "success", "lock"）
2. 下载 JSON 格式
3. 添加到 Xcode 项目
4. 使用 Lottie 库播放

### 3.2 SwiftUI 原生动画

```swift
// 简单缩放动画
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(response: 0.3), value: isPressed)

// 渐变出现
.opacity(isVisible ? 1 : 0)
.animation(.easeInOut(duration: 0.3), value: isVisible)

// 组合动画
.transition(.opacity.combined(with: .scale(scale: 0.9)))
```

---

## 4. 免费 Figma 设计系统模板

### 4.1 推荐模板

#### A. Apple Human Interface Guidelines Kit
**地址**: [figma.com/community/file/1177796543009188168](https://www.figma.com/community/file/1177796543009188168)

**特点**:
- Apple 官方风格
- 包含 macOS 组件
- 完全免费

#### B. Carbon Design System
**地址**: [figma.com/community/file/1070489114773865456](https://www.figma.com/community/file/1070489114773865456)

**特点**:
- IBM 开源设计系统
- 企业级组件
- 可借鉴色彩和排版

#### C. Night Shift (macOS 风格)
**地址**: 在 Figma Community 搜索 "macOS"

**特点**:
- macOS 风格 UI Kit
- 免费
- 可直接修改使用

### 4.2 如何使用 Figma 模板

1. **打开链接** → 点击 "Duplicate" 复制到你的工作区
2. **提取颜色** → 从模板中提取你需要的颜色
3. **学习组件结构** → 看看专业团队如何组织组件
4. **修改适配** → 根据 Moaiy 品牌调整

### 4.3 Figma Community 搜索关键词

```
"macOS"
"SwiftUI"
"Apple"
"Design System"
"Dark Mode"
"Security App"
```

---

## 5. macOS App 模板/脚手架

### 5.1 推荐模板

#### A. Create ML Template
Apple 官方模板，展示现代 macOS SwiftUI 架构

**特点**:
- MVVM 架构
- 现代化 UI
- 多窗口支持

#### B. SwiftUI-Mac-App-Template
在 GitHub 搜索 "macOS SwiftUI template"

**推荐仓库**:
```
github.com/search?q=macos+swiftui+template
```

### 5.2 自建模板结构

```
Moaiy/
├── App/
│   └── MoaiyApp.swift          # @main 入口
├── Models/
│   ├── Key.swift
│   └── EncryptionResult.swift
├── ViewModels/
│   ├── KeyListViewModel.swift
│   └── EncryptionViewModel.swift
├── Views/
│   ├── Main/
│   │   ├── MainView.swift
│   │   └── SidebarView.swift
│   ├── KeyManagement/
│   │   └── KeyListView.swift
│   └── Components/
│       ├── Buttons/
│       ├── Cards/
│       └── Inputs/
├── Services/
│   ├── GPGService.swift
│   └── FileService.swift
├── Utils/
│   ├── Constants.swift
│   └── Extensions/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

---

## 6. 实际实施建议

### 6.1 最小依赖策略

```
优先级:
1. SwiftUI 原生组件（90%需求）
2. SF Symbols 图标（100%图标需求）
3. Lottie 动画（仅关键动画）
4. 其他库（仅必要时）
```

### 6.2 依赖清单

```swift
// Package.swift 推荐依赖
dependencies: [
    // 可选：动画
    .package(url: "https://github.com/airbnb/lottie-ios", from: "4.0.0"),
    
    // 可选：Markdown 渲染
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
    
    // 可选：底层控制
    .package(url: "https://github.com/siteline/swiftui-introspect", from: "1.0.0"),
]
```

### 6.3 开发流程

```
第1周：使用 SwiftUI 原生组件搭建基础 UI
     ↓
第2周：集成 SF Symbols，完善图标
     ↓
第3周：添加关键动画（Lottie 或原生）
     ↓
第4周：优化细节，按需引入其他库
```

---

## 7. SwiftUI 原生组件对照表

| 需求 | SwiftUI 原生方案 |
|------|------------------|
| 按钮 | `Button` + `.buttonStyle()` |
| 输入框 | `TextField`, `SecureField` |
| 列表 | `List`, `Table` |
| 卡片 | 自定义 `View` + `.background()` |
| 导航 | `NavigationSplitView` (侧边栏) |
| 标签页 | `TabView` |
| 工具栏 | `.toolbar { }` |
| 警告框 | `.alert()` |
| 弹窗 | `.sheet()`, `.popover()` |
| 菜单 | `Menu`, `ContextMenu` |
| 进度条 | `ProgressView` |
| 开关 | `Toggle` |
| 徽章 | 自定义 `Text` + 背景色 |

### 7.1 按钮样式示例

```swift
// 主要按钮
Button("加密") { }
    .buttonStyle(.borderedProminent)
    .tint(.green)  // 自定义颜色

// 次要按钮
Button("取消") { }
    .buttonStyle(.bordered)

// 文字按钮
Button("了解更多") { }
    .buttonStyle(.plain)
    .foregroundStyle(.blue)
```

### 7.2 现代化列表

```swift
List(keys) { key in
    KeyRow(key: key)
}
.listStyle(.sidebar)  // macOS 侧边栏风格
```

### 7.3 卡片实现

```swift
struct KeyCard: View {
    let key: Key
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(.green)
                Text(key.name)
                    .font(.headline)
                Spacer()
                Button(action: { }) {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            Text(key.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("加密") { }
                    .buttonStyle(.borderedProminent)
                Button("分享") { }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}
```

---

## 8. 快速启动清单

### Figma 设计阶段

- [ ] 下载 [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [ ] 在 Figma Community 搜索 "macOS" 找模板
- [ ] 复制喜欢的模板到工作区
- [ ] 根据 Moaiy 品牌调整颜色
- [ ] 创建核心界面（密钥列表、加密界面）

### Xcode 开发阶段

- [ ] 创建新项目，选择 macOS App
- [ ] 项目结构按推荐模板组织
- [ ] 使用 SwiftUI 原生组件构建 UI
- [ ] 集成 SF Symbols 图标
- [ ] 按需添加 Lottie 动画

---

## 9. 资源链接汇总

### 官方资源
| 资源 | 链接 |
|------|------|
| SF Symbols | [developer.apple.com/sf-symbols](https://developer.apple.com/sf-symbols/) |
| Apple HIG | [developer.apple.com/design/human-interface-guidelines](https://developer.apple.com/design/human-interface-guidelines/macos) |
| SwiftUI Tutorials | [developer.apple.com/tutorials/swiftui](https://developer.apple.com/tutorials/swiftui) |

### 第三方资源
| 资源 | 链接 |
|------|------|
| LottieFiles | [lottiefiles.com](https://lottiefiles.com) |
| Figma Community | [figma.com/community](https://www.figma.com/community) |
| GitHub SwiftUI | [github.com/topics/swiftui](https://github.com/topics/swiftui) |

### 开源库
| 库 | GitHub |
|-----|--------|
| Lottie | [airbnb/lottie-ios](https://github.com/airbnb/lottie-ios) |
| MarkdownUI | [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) |
| SwiftUI-Introspect | [siteline/swiftui-introspect](https://github.com/siteline/swiftui-introspect) |

---

## 10. 总结

### 最佳实践

```
┌─────────────────────────────────────────────────────────┐
│                    Moaiy UI 构建策略                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │ SwiftUI     │    │ SF Symbols  │    │ Figma       │ │
│  │ 原生组件    │ +  │ 图标        │ +  │ 模板        │ │
│  │ (90%)       │    │ (100%)      │    │ (快速启动)  │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
│         ↓                  ↓                  ↓         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            零依赖 + 原生体验 + 快速开发          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 核心原则

1. **原生优先** - SwiftUI 原生组件已足够强大
2. **最小依赖** - 只引入真正需要的库
3. **Apple 风格** - 遵循 macOS 设计规范
4. **免费资源** - SF Symbols + Figma 免费模板

---

*最后更新: 2026-03-12*
