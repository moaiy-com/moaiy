# Moaiy UI Components

SwiftUI 组件库，用于 Moaiy macOS 应用。

## 目录结构

```
MoaiyUI/
├── Theme/
│   └── Color+Theme.swift        # 颜色系统和主题
├── Components/
│   ├── Buttons/
│   │   └── ButtonStyles.swift   # 按钮样式
│   ├── Inputs/
│   │   └── InputFields.swift    # 输入框组件
│   ├── Cards/
│   │   └── Cards.swift          # 卡片组件
│   ├── Feedback/
│   │   └── StatusBadge.swift    # 状态徽章
│   └── Layout/
│       └── DropZone.swift       # 拖拽区域
└── Views/
    └── MainView.swift           # 主界面示例
```

## 使用方法

### 1. 颜色系统

```swift
import SwiftUI

// 使用预定义颜色
Text("Hello")
    .foregroundStyle(.securityGreen)
    .background(.moaiSurface)

// 自适应颜色（自动适配深浅模式）
.background(.moaiBackground)
.foregroundStyle(.moaiTextPrimary)
```

### 2. 按钮

```swift
// 主要按钮
PrimaryButton("Encrypt", systemImage: "lock.fill") {
    // action
}

// 次要按钮
SecondaryButton("Share") { }

// 图标按钮
IconButton(systemName: "gearshape.fill") { }

// 使用样式修饰符
Button("Cancel") { }
    .moaiyButtonStyle(.tertiary)
```

### 3. 输入框

```swift
// 基础输入框
MoaiyTextField("Name", text: $name, placeholder: "Enter name")

// 带图标的输入框
MoaiyTextField("Email", text: $email, leadingIcon: "envelope.fill")

// 密码输入框
MoaiySecureField("Password", text: $password)

// 搜索框
SearchField(text: $searchText)
```

### 4. 卡片

```swift
// 密钥卡片
KeyCard(
    key: myKey,
    onEncrypt: { },
    onShare: { },
    onBackup: { },
    onMore: { }
)

// 信息卡片
InfoCard(
    title: "Quick Tip",
    icon: "lightbulb.fill",
    content: "Tip content here"
)

// 空状态卡片
EmptyStateCard(
    icon: "key.slash",
    title: "No Keys Yet",
    description: "Create your first key",
    actionTitle: "Create Key",
    action: { }
)
```

### 5. 状态徽章

```swift
// 状态徽章
StatusBadge("Valid", type: .success)
StatusBadge("Warning", type: .warning)

// 密钥状态
KeyStatusBadge(status: .valid)

// Pro 徽章
ProBadge()
```

### 6. 拖拽区域

```swift
// 文件拖拽区
DropZone { urls in
    // 处理拖入的文件
}

// 紧凑型拖拽区
CompactDropZone { urls in }

// 文本输入区
TextDropZone(text: $content, placeholder: "Enter text...")

// 带预览的文件拖拽
FileDropZoneWithPreview { urls in }
```

## 在 Xcode 项目中使用

1. 创建新的 macOS App 项目（SwiftUI）
2. 将 `MoaiyUI` 文件夹拖入项目
3. 确保选择 "Copy items if needed"
4. 将 `MoaiyApp` 中的 `@main` 标记移动到你自己的 App 文件

## 预览

每个组件文件都包含 SwiftUI Preview，可以在 Xcode 中直接预览：

1. 打开任意组件文件
2. 按 `Cmd + Option + P` 运行预览
3. 或点击编辑器右上角的 Preview 按钮

## 依赖

- macOS 12.0+
- Swift 6.0+
- SwiftUI

无第三方依赖，完全使用系统原生组件。

## 颜色参考

| 颜色名称 | 用途 | 浅色模式 | 深色模式 |
|---------|------|----------|----------|
| `moaiBackground` | 背景色 | #F7FAFC | #1A202C |
| `moaiSurface` | 卡片背景 | #FFFFFF | #2D3748 |
| `securityGreen` | 强调色 | #48BB78 | #48BB78 |
| `moaiTextPrimary` | 主文字 | #1A202C | #F7FAFC |
| `moaiError` | 错误 | #FC8181 | #FC8181 |
| `moaiWarning` | 警告 | #F6AD55 | #F6AD55 |
| `moaiSuccess` | 成功 | #48BB78 | #48BB78 |

## 下一步

1. 在 Xcode 中创建项目
2. 集成这些组件
3. 根据 Figma 设计调整细节
4. 连接 GPG 服务层
