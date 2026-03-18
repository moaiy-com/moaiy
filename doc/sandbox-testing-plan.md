# macOS 沙盒兼容性测试计划

> 验证 GPG 功能在 macOS App Sandbox 中的可行性

*测试日期: 2026-03-16*

---

## 一、测试目标

### 主要目标
1. **验证 GPG 命令行工具在沙盒中的可用性**
2. **测试文件访问权限和解决方案**
3. **评估安全作用域书签（Security-Scoped Bookmarks）的可行性**
4. **识别沙盒限制和潜在风险**

### 成功标准
- ✅ 可以在沙盒中调用 GPG 进行加密/解密
- ✅ 可以通过用户授权访问文件
- ✅ 可以保存和恢复文件访问权限
- ✅ 识别所有关键限制并有解决方案

---

## 二、macOS 沙盒限制概览

### 2.1 主要限制

| 限制类型 | 具体限制 | 影响 |
|---------|---------|------|
| **文件访问** | 只能访问应用容器目录 | 无法直接访问用户的文件 |
| **进程执行** | 只能执行应用包内的可执行文件 | 无法直接调用系统 GPG |
| **网络访问** | 传出连接需要权限 | 可能影响密钥服务器访问 |
| **硬件访问** | USB/蓝牙需要特殊权限 | 影响硬件密钥支持 |

### 2.2 解决方案选项

#### 方案 A：禁用沙盒（不推荐）
- ❌ 无法上架 App Store
- ✅ 功能完全无限制
- **适用场景**：仅通过 GitHub 发布

#### 方案 B：沙盒 + 用户授权（推荐）
- ✅ 可以上架 App Store
- ✅ 用户可以授权文件访问
- ⚠️ 需要用户交互
- **适用场景**：App Store + GitHub 双渠道

#### 方案 C：内置 GPG + 沙盒（推荐）
- ✅ 可以上架 App Store
- ✅ 不依赖系统 GPG
- ✅ 完全自包含
- ⚠️ 增加应用体积
- **适用场景**：最佳用户体验

---

## 三、测试计划

### 3.1 测试环境

#### 测试机器
- **macOS 版本**：macOS 12.0+ (Monterey) / macOS 13 (Ventura)
- **Xcode 版本**：14.0+
- **GPG 版本**：GnuPG 2.2.x 或 2.3.x

#### 测试项目
1. 基础沙盒项目（SwiftUI）
2. 启用 App Sandbox
3. 配置必要的 entitlements

### 3.2 测试用例

#### 测试用例 1：调用系统 GPG（预期失败）

**目的**：验证沙盒是否阻止调用系统 GPG

**步骤**：
```swift
import Foundation

func testSystemGPG() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gpg")
    process.arguments = ["--version"]
    
    do {
        try process.run()
        process.waitUntilExit()
        print("✅ 成功调用系统 GPG")
    } catch {
        print("❌ 无法调用系统 GPG: \(error)")
    }
}
```

**预期结果**：❌ 失败（沙盒限制）

---

#### 测试用例 2：应用包内 GPG（预期成功）

**目的**：验证是否可以调用应用包内的 GPG

**步骤**：
1. 将 GPG 二进制文件复制到应用包
2. 通过 Bundle.main.url 获取路径
3. 调用内置 GPG

```swift
func testBundledGPG() {
    guard let gpgURL = Bundle.main.url(forResource: "gpg", withExtension: nil, subdirectory: "Resources/bin") else {
        print("❌ 找不到内置 GPG")
        return
    }
    
    let process = Process()
    process.executableURL = gpgURL
    process.arguments = ["--version"]
    
    do {
        try process.run()
        process.waitUntilExit()
        print("✅ 成功调用内置 GPG")
    } catch {
        print("❌ 调用失败: \(error)")
    }
}
```

**预期结果**：✅ 成功

---

#### 测试用例 3：文件访问 - 无授权（预期失败）

**目的**：验证沙盒是否阻止访问用户文件

**步骤**：
```swift
func testFileAccessWithoutAuth() {
    let fileURL = URL(fileURLWithPath: "/Users/username/Desktop/test.txt")
    
    do {
        let data = try Data(contentsOf: fileURL)
        print("✅ 成功读取文件（不应发生）")
    } catch {
        print("❌ 无法读取文件（预期）: \(error)")
    }
}
```

**预期结果**：❌ 失败（沙盒限制）

---

#### 测试用例 4：文件访问 - NSOpenPanel 授权（预期成功）

**目的**：验证通过用户授权可以访问文件

**步骤**：
```swift
import AppKit

func testFileAccessWithAuth() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Moaiy 需要访问此文件进行加密"
    
    panel.begin { response in
        guard response == .OK, let url = panel.url else {
            print("❌ 用户取消")
            return
        }
        
        // 获取安全作用域
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("✅ 成功读取授权文件")
        } catch {
            print("❌ 读取失败: \(error)")
        }
    }
}
```

**预期结果**：✅ 成功

---

#### 测试用例 5：安全作用域书签（预期成功）

**目的**：验证可以保存和恢复文件访问权限

**步骤**：
```swift
// 1. 保存书签
func saveBookmark(for url: URL) -> Data? {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    do {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        // 保存到 UserDefaults 或文件
        return bookmarkData
    } catch {
        print("❌ 创建书签失败: \(error)")
        return nil
    }
}

// 2. 恢复书签
func loadBookmark(from data: Data) -> URL? {
    do {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            print("⚠️ 书签已过期，需要重新授权")
            return nil
        }
        
        return url
    } catch {
        print("❌ 恢复书签失败: \(error)")
        return nil
    }
}

// 3. 测试
func testSecurityScopedBookmark() {
    let panel = NSOpenPanel()
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        
        // 保存书签
        guard let bookmarkData = saveBookmark(for: url) else { return }
        
        // 恢复书签
        guard let restoredURL = loadBookmark(from: bookmarkData) else { return }
        
        // 访问文件
        let accessing = restoredURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                restoredURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: restoredURL)
            print("✅ 安全作用域书签测试成功")
        } catch {
            print("❌ 访问失败: \(error)")
        }
    }
}
```

**预期结果**：✅ 成功

---

#### 测试用例 6：GPG 加密/解密流程（关键测试）

**目的**：验证完整的加密/解密流程

**步骤**：
```swift
func testGPGEncryption() async throws {
    // 1. 用户选择文件
    let panel = NSOpenPanel()
    // ... 获取文件 URL
    
    // 2. 获取访问权限
    let accessing = fileURL.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            fileURL.stopAccessingSecurityScopedResource()
        }
    }
    
    // 3. 调用内置 GPG 加密
    let process = Process()
    process.executableURL = bundledGPGURL
    process.arguments = [
        "--encrypt",
        "--recipient", "user@example.com",
        "--always-trust",
        "--output", outputURL.path,
        fileURL.path
    ]
    
    try process.run()
    process.waitUntilExit()
    
    // 4. 验证输出文件
    if FileManager.default.fileExists(atPath: outputURL.path) {
        print("✅ 加密成功")
    } else {
        print("❌ 加密失败")
    }
}
```

**预期结果**：✅ 成功

---

#### 测试用例 7：应用容器目录访问（预期成功）

**目的**：验证可以自由访问应用容器目录

**步骤**：
```swift
func testContainerDirectory() {
    // 应用容器目录
    let containerURL = FileManager.default.homeDirectoryForCurrentUser
    print("容器目录: \(containerURL.path)")
    
    // 创建测试文件
    let testFile = containerURL.appendingPathComponent("test.txt")
    
    do {
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
        let content = try String(contentsOf: testFile)
        print("✅ 容器目录访问正常: \(content)")
    } catch {
        print("❌ 容器目录访问失败: \(error)")
    }
}
```

**预期结果**：✅ 成功

---

#### 测试用例 8：网络访问（密钥服务器）

**目的**：验证是否可以访问密钥服务器

**Entitlements 配置**：
```xml
<key>com.apple.security.network.client</key>
<true/>
```

**步骤**：
```swift
func testNetworkAccess() {
    let process = Process()
    process.executableURL = bundledGPGURL
    process.arguments = [
        "--keyserver", "hkps://keys.openpgp.org",
        "--search-keys", "test@example.com"
    ]
    
    do {
        try process.run()
        process.waitUntilExit()
        print("✅ 网络访问成功")
    } catch {
        print("❌ 网络访问失败: \(error)")
    }
}
```

**预期结果**：✅ 成功（需要 network entitlement）

---

### 3.3 Entitlements 配置

#### 最小权限配置（推荐）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 启用沙盒 -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- 网络访问（密钥服务器） -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- 文件读写（用户授权） -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- 文件下载访问 -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

#### Pro 版额外权限（硬件密钥）

```xml
<!-- USB 设备访问（硬件密钥） -->
<key>com.apple.security.device.usb</key>
<true/>
```

---

## 四、测试执行步骤

### 4.1 创建测试项目

1. **创建 Xcode 项目**
```bash
xcode-select --install  # 确保安装 Xcode 命令行工具
# 在 Xcode 中创建新项目：macOS App → SwiftUI
```

2. **启用沙盒**
   - 选择项目 target
   - Signing & Capabilities → + Capability → App Sandbox
   - 勾选必要的权限

3. **添加测试代码**
   - 创建 `SandboxTests.swift`
   - 添加上述测试用例

4. **准备内置 GPG**
   - 下载 GnuPG 二进制文件
   - 添加到项目：Resources/bin/gpg

### 4.2 执行测试

#### 阶段 1：基础测试（1-2小时）
```bash
# 1. 编译运行项目
# 2. 执行测试用例 1-4
# 3. 记录结果
```

#### 阶段 2：高级测试（2-3小时）
```bash
# 1. 测试安全作用域书签
# 2. 测试完整加密/解密流程
# 3. 测试网络访问
```

#### 阶段 3：压力测试（1-2小时）
```bash
# 1. 测试大文件加密（1GB+）
# 2. 测试多次文件访问
# 3. 测试书签过期场景
```

---

## 五、预期问题和解决方案

### 5.1 常见问题

#### 问题 1：无法调用系统 GPG
**现象**：`The file couldn't be opened because the specified URL type isn't supported.`

**原因**：沙盒限制，无法访问 /usr/local/bin

**解决方案**：
- ✅ 使用内置 GPG（推荐）
- ⚠️ 禁用沙盒（仅 GitHub 发布）

---

#### 问题 2：书签过期
**现象**：`bookmarkDataIsStale = true`

**原因**：文件被移动或重命名

**解决方案**：
```swift
if isStale {
    // 重新请求用户授权
    let panel = NSOpenPanel()
    // ...
}
```

---

#### 问题 3：GPG 配置文件位置
**现象**：GPG 无法找到配置文件

**原因**：沙盒限制了 ~/.gnupg 访问

**解决方案**：
```swift
// 使用应用容器目录
let gnupgDir = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent(".gnupg")

// 设置 GPGHOME 环境变量
process.environment = ["GNUPGHOME": gnupgDir.path]
```

---

#### 问题 4：临时文件访问
**现象**：GPG 无法创建临时文件

**原因**：无法访问系统临时目录

**解决方案**：
```swift
// 使用应用容器的临时目录
let tempDir = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent("tmp")

try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
```

---

## 六、测试结果记录模板

### 测试结果表

| 测试用例 | 预期结果 | 实际结果 | 状态 | 备注 |
|---------|---------|---------|------|------|
| 1. 调用系统 GPG | ❌ 失败 | ❌ 失败 | ✅ 符合预期 | 沙盒限制 |
| 2. 调用内置 GPG | ✅ 成功 | - | ⏳ 待测试 | |
| 3. 文件访问（无授权） | ❌ 失败 | - | ⏳ 待测试 | |
| 4. 文件访问（有授权） | ✅ 成功 | - | ⏳ 待测试 | |
| 5. 安全作用域书签 | ✅ 成功 | - | ⏳ 待测试 | |
| 6. GPG 加密/解密 | ✅ 成功 | - | ⏳ 待测试 | 关键测试 |
| 7. 容器目录访问 | ✅ 成功 | - | ⏳ 待测试 | |
| 8. 网络访问 | ✅ 成功 | - | ⏳ 待测试 | |

---

## 七、风险评估

### 高风险项
1. **内置 GPG 打包复杂度** - 需要编译静态链接版本
2. **沙盒限制变化** - Apple 可能收紧限制
3. **性能影响** - 沙盒可能影响 I/O 性能

### 中风险项
1. **用户体验** - 频繁的文件授权可能影响体验
2. **书签管理** - 需要妥善管理书签数据
3. **兼容性** - 不同 macOS 版本可能有差异

### 低风险项
1. **网络访问** - 已有成熟解决方案
2. **容器目录** - 完全可控

---

## 八、结论和建议

### 基于测试结果的建议

#### 如果测试全部通过：
✅ **采用方案 C（内置 GPG + 沙盒）**
- 准备上架 App Store
- 开始 MVP 开发
- 计划双渠道发布（App Store + GitHub）

#### 如果部分测试失败：
⚠️ **采用混合方案**
- App Store 版本：功能受限（仅支持用户授权文件）
- GitHub 版本：功能完整（禁用沙盒）
- 明确告知用户差异

#### 如果关键测试失败：
❌ **重新评估技术方案**
- 考虑其他加密库（不使用 GPG）
- 或者放弃 App Store，仅 GitHub 发布

---

## 九、下一步行动

### 立即执行（今天）
1. ✅ 创建测试项目
2. ✅ 配置沙盒和 entitlements
3. ⏳ 执行测试用例 1-4

### 本周完成
1. ⏳ 完成所有测试用例
2. ⏳ 记录测试结果
3. ⏳ 撰写测试报告

### 下周决策
1. 根据测试结果确定技术方案
2. 开始 MVP 开发
3. 准备内置 GPG 打包

---

**测试负责人**: AI Agent  
**测试环境**: macOS 开发环境  
**预计完成时间**: 2026-03-17

---

## 附录

### A. 参考文档

- [App Sandbox | Apple Developer Documentation](https://developer.apple.com/documentation/security/app_sandbox)
- [Enabling App Sandbox | Apple Developer](https://developer.apple.com/documentation/security/app_sandbox/enabling_app_sandbox)
- [Security-Scoped Bookmarks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AppSandboxInDepth/AppSandboxInDepth.html#//apple_ref/doc/uid/TP40011183-CH3-SW16)

### B. 相关工具

- **GnuPG 官网**: https://gnupg.org/
- **GPGTools**: https://gpgtools.org/
- **Entitlements 编辑器**: Xcode 内置

---

*最后更新: 2026-03-16*
