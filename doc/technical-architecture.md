# Moaiy 技术架构设计

> **项目**: Moaiy - 像摩艾一样守护您的秘密
> 
> 源自摩艾石像，象征神秘感、安全性、长久性

## 技术栈选择

### 核心技术

| 技术 | 版本 | 选择理由 |
|------|------|---------|
| **Swift** | 6.2 | 最新版本，性能优秀，安全特性强 |
| **SwiftUI** | 最新 | 现代UI框架，开发效率高，原生体验 |
| **Combine** | 最新 | 响应式编程，简化异步处理 |
| **GPG** | 2.2+ | 成熟稳定的加密工具，功能完整 |
| **macOS** | 12.0+ | 支持 SwiftUI 新特性，市场覆盖率高 |

### 辅助技术

| 技术 | 用途 |
|------|------|
| **Keychain Services** | 安全存储密码和密钥 |
| **FileManager** | 文件系统操作 |
| **Process** | 命令行工具调用 |
| **UserNotifications** | 系统通知 |
| **AppKit** | 部分高级UI组件 |

## 系统架构

### 分层架构图

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  ┌───────────────────────────────────┐  │
│  │      Views (SwiftUI)              │  │
│  │  - MainView                       │  │
│  │  - KeyManagementView              │  │
│  │  - EncryptionView                 │  │
│  │  - SettingsView                   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Business Logic Layer           │
│  ┌───────────────────────────────────┐  │
│  │      ViewModels                   │  │
│  │  - KeyManagementViewModel         │  │
│  │  - EncryptionViewModel            │  │
│  │  - HardwareKeyViewModel (Pro)     │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│            Service Layer                │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │  GPGService  │  │ HardwareService │  │
│  │              │  │    (Pro)        │  │
│  └──────────────┘  └─────────────────┘  │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │ FileService  │  │ BackupService   │  │
│  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│             Data Layer                  │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │  Keychain    │  │  UserDefaults   │  │
│  │  Storage     │  │  (Preferences)  │  │
│  └──────────────┘  └─────────────────┘  │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │  File        │  │  Cache          │  │
│  │  Storage     │  │  Manager        │  │
│  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          External Dependencies           │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │   GPG        │  │   PCSC          │  │
│  │  Binary      │  │  Framework      │  │
│  │  (内置)      │  │   (系统)        │  │
│  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
```

## 核心模块设计

### 1. GPGService（核心服务）

**职责**: 封装所有 GPG 命令行操作

```swift
class GPGService {
    // 单例模式
    static let shared = GPGService()
    private init() {}
    
    // 密钥管理
    func generateKeyPair(config: KeyConfig) async throws -> Key
    func listKeys() async throws -> [Key]
    func importKey(armored: String) async throws -> Key
    func exportPublicKey(keyId: String) async throws -> String
    func exportPrivateKey(keyId: String, password: String) async throws -> String
    func deleteKey(keyId: String) async throws
    
    // 加密解密
    func encrypt(text: String, recipients: [String]) async throws -> String
    func decrypt(ciphertext: String, password: String) async throws -> String
    func encryptFile(url: URL, recipients: [String]) async throws -> URL
    func decryptFile(url: URL, password: String) async throws -> URL
    
    // 签名验证
    func sign(text: String, keyId: String, password: String) async throws -> String
    func verify(signature: String, text: String) async throws -> Bool
    
    // 系统信息
    func getGPGVersion() async throws -> String
    func checkGPGInstallation() -> Bool
}
```

**技术实现**:
```swift
// 通过 Process 调用内置 GPG
private func executeGPGCommand(_ arguments: [String]) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        process.executableURL = Bundle.main.url(forResource: "gpg", withExtension: nil)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                continuation.resume(returning: output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                continuation.resume(throwing: GPGError.executionFailed(error))
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
```

### 2. HardwareKeyService（Pro版）

**职责**: 硬件密钥管理和操作

```swift
class HardwareKeyService {
    // 设备检测
    func detectDevices() async throws -> [HardwareDevice]
    func getDeviceInfo(_ device: HardwareDevice) async throws -> DeviceInfo
    
    // 初始化
    func initializeOpenPGP(_ device: HardwareDevice, 
                          adminPin: String, 
                          userPin: String) async throws
    
    // 密钥操作
    func generateKeyInDevice(_ device: HardwareDevice,
                           config: KeyConfig,
                           adminPin: String) async throws -> Key
    func importKeyToDevice(_ key: Key,
                         device: HardwareDevice,
                         adminPin: String) async throws
    
    // PIN 管理
    func changeUserPin(_ device: HardwareDevice,
                      oldPin: String,
                      newPin: String) async throws
    func changeAdminPin(_ device: HardwareDevice,
                       oldPin: String,
                       newPin: String) async throws
    func resetPin(_ device: HardwareDevice,
                 adminPin: String,
                 newUserPin: String) async throws
    
    // 状态监控
    func getDeviceStatus(_ device: HardwareDevice) async throws -> DeviceStatus
    func verifyPin(_ device: HardwareDevice, pin: String) async throws -> Bool
}
```

**技术实现**:
```swift
// 使用 PCSC 框架访问智能卡
import CryptoTokenKit

private func accessSmartCard() throws -> TKSmartCard {
    let manager = TKSmartCardSlotManager.default
    
    guard let slot = manager.slotNames.first else {
        throw HardwareKeyError.noDeviceFound
    }
    
    guard let smartCard = manager.slotNamed(slot)?.makeSmartCard() else {
        throw HardwareKeyError.deviceAccessFailed
    }
    
    return smartCard
}
```

### 3. FileService（文件服务）

**职责**: 文件系统操作和管理

```swift
class FileService {
    // 文件选择
    func selectFile(types: [String]) async -> URL?
    func selectFolder() async -> URL?
    func selectMultipleFiles(types: [String]) async -> [URL]
    
    // 文件操作
    func readFile(_ url: URL) async throws -> Data
    func writeFile(_ data: Data, to url: URL) async throws
    func copyFile(from: URL, to: URL) async throws
    func deleteFile(_ url: URL) async throws
    
    // 权限管理（沙盒兼容）
    func requestAccess(to url: URL) -> Bool
    func saveBookmark(for url: URL) throws
    func loadBookmark(for key: String) -> URL?
    
    // 临时文件
    func createTempFile(data: Data) throws -> URL
    func cleanupTempFiles()
}
```

### 4. BackupService（备份服务）

**职责**: 自动备份和恢复

```swift
class BackupService {
    // 自动备份
    func scheduleAutoBackup(interval: TimeInterval)
    func performBackup() async throws -> URL
    
    // 手动备份
    func backupKeys(to url: URL) async throws
    func backupSettings(to url: URL) async throws
    
    // 恢复
    func restore(from url: URL) async throws
    func listBackups() -> [BackupInfo]
    
    // 云同步（Pro版）
    func syncToCloud() async throws  // iCloud
    func restoreFromCloud() async throws
}
```

### 5. SmartDefaults（智能默认值）

**职责**: 提供智能配置和推荐

```swift
class SmartDefaults {
    // 用户信息检测
    func detectUserInfo() -> UserInfo
    func detectSystemLocale() -> Locale
    
    // 智能推荐
    func recommendKeyConfig(for purpose: UseCase) -> KeyConfig
    func recommendBackupLocation() -> URL
    func recommendEncryptionSettings() -> EncryptionSettings
    
    // 自动生成
    func generateSecurePassword() -> String
    func generateKeyName() -> String
}
```

## 数据模型设计

### 核心数据模型

```swift
// 密钥模型
struct Key: Identifiable, Codable {
    let id: String
    let keyId: String
    let userId: String
    let email: String
    let createdAt: Date
    let expiresAt: Date?
    let type: KeyType
    let length: Int
    let capabilities: [KeyCapability]
    let trust: TrustLevel
    let isRevoked: Bool
    let isExpired: Bool
}

enum KeyType: String, Codable {
    case rsa = "RSA"
    case ecc = "ECC"
    case dsa = "DSA"
}

enum KeyCapability: String, Codable {
    case encrypt = "E"
    case sign = "S"
    case certify = "C"
    case authenticate = "A"
}

// 硬件设备模型
struct HardwareDevice: Identifiable {
    let id: String
    let name: String
    let manufacturer: String
    let serialNumber: String
    let type: DeviceType
    let status: DeviceStatus
}

enum DeviceType: String {
    case yubikey = "YubiKey"
    case canokey = "CanoKey"
    case nitrokey = "NitroKey"
    case other = "Other"
}

// 加密配置
struct EncryptionSettings: Codable {
    let defaultKeyType: KeyType
    let defaultKeyLength: Int
    let defaultExpiration: ExpirationPolicy
    let autoBackup: Bool
    let cloudSync: Bool
}

enum ExpirationPolicy: String, Codable {
    case never = "Never"
    case oneYear = "1 Year"
    case twoYears = "2 Years"
    case custom = "Custom"
}
```

## 错误处理架构

### 错误类型定义

```swift
enum GPGError: Error, LocalizedError {
    case gpgNotInstalled
    case executionFailed(String)
    case invalidOutput
    case keyNotFound(String)
    case encryptionFailed
    case decryptionFailed
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .gpgNotInstalled:
            return "GPG工具未安装"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .invalidOutput:
            return "GPG输出格式错误"
        case .keyNotFound(let keyId):
            return "找不到密钥: \(keyId)"
        case .encryptionFailed:
            return "加密失败"
        case .decryptionFailed:
            return "解密失败"
        case .invalidPassword:
            return "密码错误"
        }
    }
}

enum HardwareKeyError: Error, LocalizedError {
    case noDeviceFound
    case deviceAccessFailed
    case pinIncorrect
    case deviceLocked
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .noDeviceFound:
            return "未检测到硬件密钥"
        case .deviceAccessFailed:
            return "无法访问硬件密钥"
        case .pinIncorrect:
            return "PIN码错误"
        case .deviceLocked:
            return "设备已锁定"
        case .unsupportedOperation:
            return "不支持的操作"
        }
    }
}
```

### 智能错误恢复

```swift
class ErrorRecovery {
    static func handle(_ error: Error) -> RecoveryAction {
        switch error {
        case GPGError.gpgNotInstalled:
            return .installGPG
            
        case GPGError.invalidPassword:
            return .showPasswordHint
            
        case HardwareKeyError.noDeviceFound:
            return .showDeviceConnectionGuide
            
        case HardwareKeyError.pinIncorrect:
            return .showPinResetGuide
            
        default:
            return .showGenericHelp
        }
    }
}

enum RecoveryAction {
    case installGPG
    case showPasswordHint
    case showDeviceConnectionGuide
    case showPinResetGuide
    case showGenericHelp
    case contactSupport
}
```

## 性能优化策略

### 1. 异步处理

```swift
// 所有耗时操作异步执行
class GPGService {
    func encrypt(largeFile url: URL, 
                progress: @escaping (Double) -> Void) async throws -> URL {
        try await withTaskCancellationHandler {
            // 异步加密大文件
            // 实时报告进度
        } onCancel: {
            // 支持取消操作
        }
    }
}
```

### 2. 缓存策略

```swift
class CacheManager {
    // 缓存密钥列表
    private var keyListCache: [Key]?
    private var cacheExpiry: Date?
    
    func getCachedKeys() async throws -> [Key] {
        if let cache = keyListCache, 
           let expiry = cacheExpiry, 
           Date() < expiry {
            return cache
        }
        
        let keys = try await GPGService.shared.listKeys()
        keyListCache = keys
        cacheExpiry = Date().addingTimeInterval(300) // 5分钟缓存
        
        return keys
    }
}
```

### 3. 内存管理

```swift
// 及时释放大对象
class FileEncryptionViewModel: ObservableObject {
    private var tempFileURL: URL?
    
    deinit {
        // 清理临时文件
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

## 安全考虑

### 1. 密码存储

```swift
class SecurePasswordStorage {
    // 使用 Keychain 存储密码
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
    
    func getPassword(for keyId: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyId,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
}
```

### 2. 内存安全

```swift
// 敏感数据处理后立即清零
func processSensitiveData(_ data: Data) {
    defer {
        // 确保数据被清零
        data.resetBytes(in: 0..<data.count)
    }
    
    // 处理数据...
}
```

### 3. 沙盒兼容

```swift
// 使用安全作用域书签访问文件
class SandboxAccess {
    func saveAccess(to url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // 保存书签到 UserDefaults
        UserDefaults.standard.set(bookmark, forKey: url.path)
    }
    
    func accessFile(at url: URL) -> Bool {
        guard let bookmark = UserDefaults.standard.data(forKey: url.path),
              let newURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: nil
              ) else {
            return false
        }
        
        return newURL.startAccessingSecurityScopedResource()
    }
}
```

## 测试策略

### 单元测试

```swift
class GPGServiceTests: XCTestCase {
    var sut: GPGService!
    
    override func setUp() {
        sut = GPGService.shared
    }
    
    func testGenerateKeyPair() async throws {
        let config = KeyConfig(
            name: "Test User",
            email: "test@example.com",
            type: .rsa,
            length: 2048
        )
        
        let key = try await sut.generateKeyPair(config: config)
        
        XCTAssertNotNil(key.id)
        XCTAssertEqual(key.email, "test@example.com")
    }
}
```

### 集成测试

```swift
class EncryptionTests: XCTestCase {
    func testEncryptDecrypt() async throws {
        let originalText = "Hello, World!"
        
        // 加密
        let encrypted = try await GPGService.shared.encrypt(
            text: originalText,
            recipients: [testKeyId]
        )
        
        XCTAssertNotEqual(originalText, encrypted)
        
        // 解密
        let decrypted = try await GPGService.shared.decrypt(
            ciphertext: encrypted,
            password: testPassword
        )
        
        XCTAssertEqual(originalText, decrypted)
    }
}
```

## 部署架构

### 内置GPG打包

```
应用结构：
Moaiy.app/
├── Contents/
│   ├── MacOS/
│   │   └── Moaiy
│   ├── Resources/
│   │   ├── gpg.bundle/          # GPG二进制和依赖
│   │   │   ├── bin/gpg
│   │   │   ├── lib/libgcrypt.20.dylib
│   │   │   ├── lib/libgpg-error.0.dylib
│   │   │   └── share/gnupg/     # 配置文件
│   │   └── Assets.car
│   └── Info.plist

编译GPG：
1. 下载 GPG 源码
2. 配置静态链接
3. 编译为通用二进制（arm64 + x86_64）
4. 打包到应用资源中
```

---

*最后更新: 2026-03-08*
