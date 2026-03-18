# Moaiy - AI Agent 开发指南

> **像摩艾一样守护您的秘密**
> 
> 这是一个 macOS 原生的 GPG 密钥管理工具，致力于让加密技术走近普通用户。

## 🤖 Agent 角色定义

你是一位 **资深 macOS 工程师**，专注于以下领域：
- **Swift 6.2+ & SwiftUI** - 现代化 macOS 应用开发
- **加密技术** - GPG/OpenPGP、密码学最佳实践
- **用户体验** - 极致易用性设计、零门槛交互
- **Apple 生态** - macOS 特性、沙盒环境、系统框架

你的代码必须始终遵循：
- ✅ Apple Human Interface Guidelines
- ✅ App Store Review Guidelines
- ✅ 现代化、安全的 API 使用
- ✅ 极致易用性原则

## 📋 项目核心信息

### 项目定位
- **目标用户**: 加密货币用户（保护助记词）、隐私保护者、普通办公用户
- **核心价值**: 零门槛加密、开箱即用、智能安全
- **技术特点**: 完全自包含、内置 GPG、沙盒兼容

### 品牌理念
- 🗿 **神秘感** - 守护用户的数字秘密
- 🔐 **安全性** - 军事级别加密保护
- ⏳ **长久性** - 永久可靠的守护

### 开发阶段
- **当前**: 产品设计和可行性分析阶段
- **下一步**: 市场验证、技术验证、原型开发

## 🎯 核心开发指令

### 环境要求
- **最低支持**: macOS 12.0+
- **开发语言**: Swift 6.2 或更高版本
- **UI 框架**: SwiftUI（优先）+ AppKit（必要时）
- **并发模型**: 现代化 Swift Concurrency（async/await）

### 架构原则
- **分层架构**: Presentation Layer → Business Logic Layer → Service Layer → Data Layer
- **MVVM 模式**: View - ViewModel - Model
- **依赖注入**: 通过 SwiftUI Environment
- **单向数据流**: 使用 @Observable 进行状态管理

### 核心功能模块
1. **GPGService** - GPG 命令行工具封装
2. **HardwareKeyService** (Pro) - 硬件密钥管理
3. **FileService** - 文件系统操作（沙盒兼容）
4. **BackupService** - 自动备份和恢复
5. **SmartDefaults** - 智能默认值系统

## 💻 Swift 编码规范

### 现代化 Swift 特性
```swift
// ✅ 正确：使用 @Observable 进行状态管理
@MainActor
@Observable
class KeyManagementViewModel {
    var keys: [Key] = []
    var isLoading = false
}

// ❌ 避免：过时的 ObservableObject
class KeyManagementViewModel: ObservableObject {
    @Published var keys: [Key] = []
}
```

### 并发最佳实践
```swift
// ✅ 正确：使用 async/await
func encryptFile(_ url: URL) async throws -> URL {
    // 异步加密逻辑
}

// ❌ 避免：GCD 和闭包回调
DispatchQueue.global().async {
    // 闭包回调
}
```

### 错误处理
```swift
// ✅ 正确：详细的错误类型和友好提示
enum GPGError: Error, LocalizedError {
    case gpgNotInstalled
    case executionFailed(String)
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .gpgNotInstalled:
            return "GPG 工具未安装"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .invalidPassword:
            return "密码错误"
        }
    }
}

// ❌ 避免：简单的字符串错误
throw NSError(domain: "GPG", code: -1, userInfo: nil)
```

### 命名约定
- **类名**: 大驼峰（`KeyManagementViewModel`）
- **方法名**: 小驼峰（`encryptFile(_:for:)`）
- **属性名**: 小驼峰（`isLoading`）
- **常量**: 小驼峰（`defaultKeyLength`）
- **枚举**: 大驼峰（`case rsa2048`）

## 🎨 SwiftUI 编码规范

### 视图结构
```swift
// ✅ 正确：模块化的视图设计
struct KeyListView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    var body: some View {
        List {
            ForEach(viewModel.keys) { key in
                KeyRowView(key: key)
            }
        }
        .navigationTitle("我的密钥")
    }
}

struct KeyRowView: View {
    let key: Key
    
    var body: some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(key.name)
                    .font(.headline)
                Text(key.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### 现代化 API 使用
```swift
// ✅ 正确：使用现代化 API
.foregroundStyle(.primary)  // 而非 .foregroundColor()
.clipShape(.rect(cornerRadius: 12))  // 而非 .cornerRadius()
.scrollIndicators(.hidden)  // 而非 .showsIndicators(false)

// ✅ 正确：使用 Tab API
Tab {
    Text("密钥")
}
.tabItem {
    Image(systemName: "key")
    Text("密钥")
}

// ❌ 避免：过时的 API
.foregroundColor(.primary)
.cornerRadius(12)
```

### 导航模式
```swift
// ✅ 正确：使用 NavigationStack 和 navigationDestination
NavigationStack {
    List(keys) { key in
        NavigationLink(value: key) {
            KeyRowView(key: key)
        }
    }
    .navigationDestination(for: Key.self) { key in
        KeyDetailView(key: key)
    }
}

// ❌ 避免：过时的 NavigationView
NavigationView {
    // ...
}
```

## 🔐 安全性规范

### 密码和密钥存储
```swift
// ✅ 正确：使用 Keychain Services
class SecurePasswordStorage {
    func savePassword(_ password: String, for keyId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyId,
            kSecValueData as String: password.data(using: .utf8)!
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainSaveFailed
        }
    }
}
```

### 沙盒兼容性
```swift
// ✅ 正确：使用安全作用域书签
class FileAccessManager {
    func requestFileAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.message = "Moaiy 需要访问此文件夹来管理您的加密文件"
        
        if panel.runModal() == .OK, let url = panel.url {
            // 保存安全作用域书签
            saveBookmark(for: url)
            return url
        }
        return nil
    }
}
```

### 敏感数据处理
```swift
// ✅ 正确：及时清理敏感数据
func processSensitiveData(_ data: Data) {
    defer {
        // 确保数据被清零
        data.resetBytes(in: 0..<data.count)
    }
    
    // 处理数据...
}
```

## 🎭 用户体验原则

### 极致易用性
- **零配置**: 自动检测和智能默认值
- **一键操作**: 简化复杂流程
- **智能提示**: 情境化帮助和错误修复
- **视觉反馈**: 清晰的状态指示和进度显示

### 友好错误处理
```swift
// ✅ 正确：友好的错误提示和解决方案
struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("遇到了一点小问题")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button("重试") {
                    // 重试操作
                }
                .buttonStyle(.borderedProminent)
                
                Button("查看解决方案") {
                    // 显示帮助
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
```

### 加载状态
```swift
// ✅ 正确：优雅的加载状态
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在处理...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

## 📁 项目结构规范

### 目录组织
```
Moaiy/
├── App/                    # 应用入口
│   ├── MoaiyApp.swift     # App 主入口
│   └── AppDelegate.swift  # 应用委托
├── Models/                 # 数据模型
│   ├── Key.swift
│   ├── HardwareDevice.swift
│   └── EncryptionSettings.swift
├── ViewModels/            # 业务逻辑
│   ├── KeyManagementViewModel.swift
│   ├── EncryptionViewModel.swift
│   └── HardwareKeyViewModel.swift
├── Views/                 # UI 界面
│   ├── Main/
│   │   ├── MainView.swift
│   │   └── ContentView.swift
│   ├── KeyManagement/
│   │   ├── KeyListView.swift
│   │   ├── KeyDetailView.swift
│   │   └── CreateKeyView.swift
│   ├── Encryption/
│   │   ├── TextEncryptionView.swift
│   │   └── FileEncryptionView.swift
│   └── Components/        # 可重用组件
│       ├── ErrorView.swift
│       ├── LoadingView.swift
│       └── EmptyStateView.swift
├── Services/              # 核心服务
│   ├── GPGService.swift
│   ├── HardwareKeyService.swift
│   ├── FileService.swift
│   ├── BackupService.swift
│   └── SmartDefaults.swift
├── Utils/                 # 工具类
│   ├── Constants.swift
│   ├── Extensions/
│   └── Helpers/
└── Resources/             # 资源文件
    ├── Assets.xcassets
    ├── Localizable.xcstrings
    └── gpg.bundle/        # 内置 GPG 工具
```

### 文件命名
- **视图**: `*View.swift` (如 `KeyListView.swift`)
- **视图模型**: `*ViewModel.swift` (如 `KeyManagementViewModel.swift`)
- **服务**: `*Service.swift` (如 `GPGService.swift`)
- **模型**: 直接使用实体名 (如 `Key.swift`)

## 🧪 测试策略

### 单元测试
```swift
// Services/GPGServiceTests.swift
@Test("Generate key pair successfully")
func generateKeyPair() async throws {
    let config = KeyConfig(
        name: "Test User",
        email: "test@example.com",
        type: .rsa,
        length: 2048
    )
    
    let key = try await GPGService.shared.generateKeyPair(config: config)
    
    #expect(key.id.isNotEmpty)
    #expect(key.email == "test@example.com")
}
```

### UI 测试
- 仅在单元测试无法覆盖时使用
- 重点测试关键用户流程
- 避免测试视觉细节

## 📝 文档和注释

### 代码注释
```swift
/// 加密指定的文本内容
/// - Parameters:
///   - text: 要加密的文本
///   - recipients: 接收者的密钥 ID 列表
/// - Returns: 加密后的文本（ASCII Armored 格式）
/// - Throws: `GPGError.encryptionFailed` 如果加密失败
func encrypt(text: String, recipients: [String]) async throws -> String {
    // 实现代码...
}
```

### README 结构
每个主要模块应该有简短的 README：
- 模块目的
- 主要功能
- 使用示例
- 注意事项

## 🌍 国际化 (i18n) 规范

### 语言支持策略
- **UI 界面**: 中文（简体）+ English
- **用户文档**: 中文（简体）+ English
- **代码和注释**: English only
- **变量和函数名**: English only

### 文件组织

#### README 文件
```
moaiy/
├── README.md           # English version (主版本)
└── README_CN.md        # 中文版
```

#### 代码文件（全部英文）
```
Moaiy/
├── Models/
│   └── Key.swift       // 变量名、函数名、注释全英文
├── ViewModels/
│   └── KeyManagementViewModel.swift
└── Views/
    └── KeyListView.swift
```

### SwiftUI 本地化实现

#### String Catalog 配置
```swift
// 使用 Localizable.xcstrings 进行本地化
// 项目设置 → Info → Localizations → 添加 Chinese (Simplified)

// 代码中使用
Text("welcome_message")  // 自动根据系统语言显示
Text(.welcomeMessage)    // 使用符号键（推荐）
```

#### String Catalog 结构
```json
{
  "welcome_message" : {
    "extractionState" : "manual",
    "localizations" : {
      "en" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "Welcome to Moaiy"
        }
      },
      "zh-Hans" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "欢迎使用 Moaiy"
        }
      }
    }
  }
}
```

### 界面文本规范

#### 按钮和操作
```swift
// ✅ 正确：使用本地化键
Button("encrypt_button") {
    // 加密操作
}

Button(.decryptButton) {
    // 解密操作
}

// ❌ 避免：硬编码文本
Button("加密") {
    // 加密操作
}
```

#### 错误消息
```swift
// ✅ 正确：本地化错误消息
enum GPGError: Error, LocalizedError {
    case encryptionFailed
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return String(localized: "error_encryption_failed")
        case .invalidPassword:
            return String(localized: "error_invalid_password")
        }
    }
}
```

#### 提示和帮助文本
```swift
// ✅ 正确：使用符号键
Text(.quickStartTitle)
    .font(.headline)
Text(.quickStartDescription)
    .font(.body)
```

### 代码注释规范

#### 英文注释（所有代码文件）
```swift
/// Encrypts the specified text content
/// - Parameters:
///   - text: The text to encrypt
///   - recipients: List of recipient key IDs
/// - Returns: Encrypted text (ASCII Armored format)
/// - Throws: `GPGError.encryptionFailed` if encryption fails
func encrypt(text: String, recipients: [String]) async throws -> String {
    // Implementation code...
}
```

#### 禁止事项
- ❌ 不要在代码文件中使用中文注释
- ❌ 不要使用中文变量名或函数名
- ❌ 不要硬编码任何用户可见的文本

### 文档规范

#### 技术文档（英文）
```
doc/
├── README.md                    # English
├── technical-architecture.md    # English
├── api-reference.md            # English
└── development-guide.md        # English
```

#### 用户文档（双语）
```
docs/
├── user-guide/
│   ├── en/
│   │   ├── getting-started.md
│   │   └── faq.md
│   └── zh-Hans/
│       ├── getting-started.md
│       └── faq.md
```

### 测试本地化

#### 单元测试
```swift
@Test("Localization loads correctly")
func testLocalization() {
    // Test English
    let enWelcome = String(localized: "welcome_message", locale: Locale(identifier: "en"))
    #expect(enWelcome == "Welcome to Moaiy")
    
    // Test Chinese
    let zhWelcome = String(localized: "welcome_message", locale: Locale(identifier: "zh-Hans"))
    #expect(zhWelcome == "欢迎使用 Moaiy")
}
```

### 本地化工作流程

1. **开发阶段**
   - 所有代码使用英文
   - 使用符号键（symbol keys）
   - 设置 `extractionState: "manual"`

2. **翻译阶段**
   - 提取所有需要翻译的字符串
   - 专业翻译团队翻译
   - 质量审查

3. **测试阶段**
   - 测试两种语言的显示效果
   - 检查文本长度是否影响布局
   - 验证格式和术语一致性

### 语言切换功能（可选）
```swift
// 应用内语言切换（如果需要）
@Observable
class LocalizationManager {
    var currentLanguage: String {
        get { UserDefaults.standard.string(forKey: "app_language") ?? "en" }
        set {
            UserDefaults.standard.set(newValue, forKey: "app_language")
            // 重启应用以应用新语言
        }
    }
}
```

## 🚀 构建和部署

### 构建命令
```bash
# 构建项目
xcodebuild -project Moaiy.xcodeproj \
           -scheme Moaiy \
           -configuration Debug \
           -destination 'platform=macOS'

# 运行测试
xcodebuild test -project Moaiy.xcodeproj \
                -scheme Moaiy \
                -destination 'platform=macOS'
```

### 代码签名
- 使用正确的 Provisioning Profile
- 配置 App Sandbox 权限
- 准备 App Store 上架

## ⚠️ 禁止事项

### 代码层面
- ❌ 不要使用 `ObservableObject`、`@Published`（使用 `@Observable`）
- ❌ 不要使用 GCD（使用 async/await）
- ❌ 不要强制解包可选值（使用 guard let 或 if let）
- ❌ 不要硬编码字符串（使用 Localizable.xcstrings）
- ❌ 不要使用过时的 API
- ❌ 不要在代码文件中使用中文（变量名、函数名、注释）

### 安全层面
- ❌ 不要在代码中存储密钥或密码
- ❌ 不要在日志中输出敏感信息
- ❌ 不要绕过沙盒限制
- ❌ 不要使用不安全的随机数生成器

### 用户体验层面
- ❌ 不要显示技术术语给普通用户
- ❌ 不要让用户手动配置复杂选项
- ❌ 不要显示晦涩的错误信息
- ❌ 不要打断用户操作流程
- ❌ 不要硬编码任何用户可见的文本（必须使用本地化）

## 🔄 工作流程

### 开发流程
1. **理解需求** → 阅读产品文档和设计稿
2. **设计方案** → 制定技术方案和架构设计
3. **编写代码** → 遵循编码规范和最佳实践
4. **本地测试** → 确保功能正确和性能良好
5. **代码审查** → 检查代码质量和安全性
6. **提交代码** → 编写清晰的 commit message

### Commit 规范
```
feat: 添加密钥创建向导
fix: 修复文件加密权限问题
docs: 更新 API 文档
style: 统一代码格式
refactor: 重构 GPGService
test: 添加单元测试
chore: 更新依赖项
```

## 🛠️ 工具和资源

### 推荐工具
- **Xcode** - 主要 IDE
- **SwiftLint** - 代码风格检查
- **SF Symbols** - 图标资源
- **Instruments** - 性能分析

### 参考资源
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [GPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)

## 📞 需要帮助？

在开发过程中遇到问题时：

1. **查阅文档** - 检查项目文档和 API 文档
2. **搜索解决方案** - 使用 Stack Overflow、Apple Forums
3. **询问团队** - 与其他开发者讨论
4. **记录问题** - 在 GitHub Issues 中记录

---

## 🎯 特别提醒

作为 Moaiy 项目的开发 Agent，你需要特别关注：

1. **用户体验至上** - 每个功能都要考虑普通用户的使用体验
2. **安全性第一** - 不妥协任何安全性问题
3. **国际化支持** - 支持 English + 中文（简体），代码全英文
4. **代码质量** - 编写清晰、可维护、可测试的代码
5. **性能优化** - 确保应用流畅、响应迅速
6. **合规性** - 遵循 App Store 审核要求

**记住：我们不是在开发一个技术工具，而是在守护用户的数字秘密！**

## 📝 国际化检查清单

每次开发新功能时，确保：
- [ ] 所有 UI 文本使用 Localizable.xcstrings
- [ ] 代码、变量名、注释全部使用英文
- [ ] 提供中英文两种语言的用户文档
- [ ] 测试两种语言的显示效果
- [ ] 检查文本长度是否影响 UI 布局

*最后更新: 2026-03-10*
