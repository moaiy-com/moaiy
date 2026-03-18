# Moaiy App Store 审核合规方案

> **项目**: Moaiy - 像摩艾一样守护您的秘密
> 
> 源自摩艾石像，象征神秘感、安全性、长久性

## 审核风险总览

### 风险等级评估

| 风险项 | 风险等级 | 影响范围 | 解决难度 | 优先级 |
|--------|---------|---------|---------|--------|
| **加密软件出口合规** | 🟡 中 | 必须通过 | 低 | 高 |
| **macOS 沙盒限制** | 🔴 高 | 核心功能 | 高 | 高 |
| **硬件访问权限** | 🟡 中 | Pro功能 | 中 | 中 |
| **命令行工具调用** | 🟡 中 | 核心功能 | 高 | 高 |
| **免费vs付费模式** | 🔴 高 | 商业模式 | 高 | 高 |
| **UI/UX 合规** | 🟢 低 | 易修复 | 低 | 低 |
| **隐私政策** | 🟡 中 | 必须通过 | 低 | 中 |
| **开源许可证** | 🟢 低 | 易处理 | 低 | 低 |

**总体风险评估**: ⭐⭐⭐☆☆ (3/5)

## 1. 加密软件出口合规

### Apple 要求

所有使用加密功能的应用必须：
1. 在 App Store Connect 填写加密合规问卷
2. 声明加密功能的用途和类型
3. 遵守美国出口管理条例 (EAR)

### 合规要点

#### 加密功能声明
```
应用使用加密功能：
✅ 数据加密 (Data Encryption)
✅ 密钥管理 (Key Management)
✅ 数字签名 (Digital Signatures)

加密算法：
- RSA (2048/4096 位)
- AES (256 位)
- SHA-2 (256/512 位)
- ECC (椭圆曲线)

用途：
✅ 保护用户数据
✅ 密钥存储和管理
✅ 文件加密
✅ 通信加密
```

#### 需要提交的信息
- **加密类型**: 对称加密、非对称加密、哈希算法
- **密钥长度**: RSA-2048/4096, AES-256
- **使用场景**: 数据保护、身份验证
- **是否开源**: 部分开源（核心算法）

### 解决方案

1. **准确填写问卷**
   - 在 App Store Connect 提交时填写 "Encryption" 部分
   - 选择 "Yes, my app uses encryption"
   - 详细说明加密用途

2. **准备支持文档**
   ```
   文档内容：
   - 加密功能详细说明
   - 使用的加密算法列表
   - 加密在应用中的作用
   - 不涉及军事或政府用途的声明
   ```

3. **合规检查清单**
   - [ ] 确认使用的加密算法在允许列表中
   - [ ] 准备加密功能说明文档
   - [ ] 填写 App Store Connect 加密问卷
   - [ ] 保存所有相关文档以备审查

## 2. macOS 沙盒限制

### 沙盒限制影响

#### 受影响的功能

| 功能 | 沙盒限制 | 影响程度 | 解决方案 |
|------|---------|---------|---------|
| **访问任意文件** | ❌ 受限 | 高 | 安全作用域书签 |
| **访问 ~/.gnupg** | ❌ 受限 | 高 | 应用专属目录 |
| **调用系统 GPG** | ⚠️ 部分受限 | 中 | 内置 GPG |
| **访问 USB 设备** | ⚠️ 需要权限 | 中 | 正确声明权限 |
| **开机自启动** | ❌ 受限 | 低 | 不支持（可接受） |

### 解决方案

#### 方案 1: 安全作用域书签

```swift
// 文件访问权限管理
class FileAccessManager {
    // 请求文件访问权限
    func requestFileAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.message = "GPG Manager 需要访问此文件夹来管理您的加密文件"
        
        if panel.runModal() == .OK, let url = panel.url {
            // 保存安全作用域书签
            saveBookmark(for: url)
            return url
        }
        return nil
    }
    
    // 保存书签
    private func saveBookmark(for url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: "fileAccess_\(url.path)")
        } catch {
            print("保存书签失败: \(error)")
        }
    }
    
    // 恢复访问权限
    func restoreAccess(for key: String) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // 书签过期，重新请求
                return nil
            }
            
            if url.startAccessingSecurityScopedResource() {
                return url
            }
        } catch {
            print("恢复书签失败: \(error)")
        }
        
        return nil
    }
}
```

#### 方案 2: 应用专属目录

```swift
// 使用应用容器目录
class StorageManager {
    // 获取应用专属目录
    var appContainerURL: URL {
        let containerURL = FileManager.default.homeDirectoryForCurrentUser
        return containerURL.appendingPathComponent("Library/Containers/com.moaiy.app")
    }
    
    // 密钥存储目录
    var keyringURL: URL {
        return appContainerURL.appendingPathComponent("Data/gnupg")
    }
    
    // 初始化目录结构
    func initializeDirectories() throws {
        let directories = [
            keyringURL,
            appContainerURL.appendingPathComponent("Backups"),
            appContainerURL.appendingPathComponent("Encrypted"),
            appContainerURL.appendingPathComponent("Temp")
        ]
        
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
```

#### 方案 3: 内置 GPG（推荐）

**优势**:
- ✅ 完全控制环境
- ✅ 不依赖系统
- ✅ 符合沙盒要求
- ✅ 跨版本兼容

**实现步骤**:
1. **编译 GPG 为嵌入式库**
   ```bash
   # 下载 GPG 源码
   wget https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.3.tar.bz2
   
   # 配置编译选项
   ./configure --prefix=/usr/local/gpg-embedded \
               --disable-doc \
               --enable-static \
               --disable-dependency-tracking
   
   # 编译
   make && make install
   ```

2. **打包到应用资源**
   ```
   Moaiy.app/Contents/Resources/gpg.bundle/
   ├── bin/gpg
   ├── lib/libgcrypt.20.dylib
   ├── lib/libgpg-error.0.dylib
   └── share/gnupg/
   ```

3. **调用内置 GPG**
   ```swift
   class EmbeddedGPGService {
       private var gpgURL: URL {
           Bundle.main.url(forResource: "gpg", withExtension: nil, subdirectory: "gpg.bundle/bin")!
       }
       
       func executeGPG(_ arguments: [String]) async throws -> String {
           let process = Process()
           process.executableURL = gpgURL
           process.arguments = arguments
           
           // 设置环境变量
           let homeDir = Bundle.main.resourcePath! + "/gpg.bundle"
           process.environment = [
               "GNUPGHOME": StorageManager.shared.keyringURL.path,
               "PATH": homeDir + "/bin"
           ]
           
           return try await runProcess(process)
       }
   }
   ```

### Info.plist 配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 沙盒权限 -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- 文件访问权限 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- USB 设备访问（Pro版） -->
    <key>com.apple.security.device.usb</key>
    <true/>
    
    <!-- 智能卡访问（Pro版） -->
    <key>com.apple.security.smartcard</key>
    <true/>
    
    <!-- 网络访问（云同步，Pro版） -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- 应用描述 -->
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    
    <!-- 使用说明 -->
    <key>NSUSBDeviceUsageDescription</key>
    <string>GPG Manager 需要访问 USB 设备来管理硬件密钥（如 YubiKey）</string>
    
    <key>NSCameraUsageDescription</key>
    <string>GPG Manager 不需要访问摄像头</string>
</dict>
</plist>
```

## 3. 硬件访问权限（Pro版）

### 智能卡访问

#### 权限要求
- `com.apple.security.smartcard`: 访问智能卡
- `com.apple.security.device.usb`: 访问 USB 设备

#### 实现方案

```swift
import CryptoTokenKit

class HardwareKeyManager {
    private let slotManager = TKSmartCardSlotManager.default
    
    // 检测硬件密钥
    func detectDevices() -> [HardwareDevice] {
        var devices: [HardwareDevice] = []
        
        for slotName in slotManager.slotNames {
            if let slot = slotManager.slotNamed(slotName),
               let smartCard = slot.makeSmartCard() {
                
                // 识别设备类型
                let device = HardwareDevice(
                    name: getDeviceName(smartCard),
                    type: detectDeviceType(smartCard),
                    slotName: slotName
                )
                devices.append(device)
            }
        }
        
        return devices
    }
    
    // 访问设备
    func accessDevice(_ device: HardwareDevice) throws -> TKSmartCard {
        guard let slot = slotManager.slotNamed(device.slotName),
              let smartCard = slot.makeSmartCard() else {
            throw HardwareKeyError.deviceAccessFailed
        }
        
        return smartCard
    }
}
```

#### 审核关注点

1. **为什么需要硬件访问？**
   ```
   说明：应用需要访问硬件密钥（如 YubiKey）来提供高级安全功能。
   这些设备用于存储加密密钥，提供比软件密钥更高的安全性。
   ```

2. **如何保护用户隐私？**
   ```
   措施：
   - 仅在用户明确操作时访问设备
   - 不收集或传输任何设备信息
   - 所有操作在本地完成
   ```

3. **是否有滥用风险？**
   ```
   保护：
   - 需要用户确认才能访问设备
   - 每次操作都需要 PIN 码验证
   - 提供详细的操作日志
   ```

## 4. 商业模式合规

### App Store 政策分析

#### 禁止行为
❌ 在 App Store 版本中显示外部购买链接  
❌ App Store 版本功能比其他渠道少  
❌ 绕过 Apple IAP 系统  

#### 允许行为
✅ 提供免费版本  
✅ 通过 IAP 解锁功能  
✅ 在应用外提供其他版本  

### 合规方案

#### 方案 A: 统一 App Store 版本（推荐）

```
策略：
1. GitHub: 完全免费，所有功能
2. App Store: 免费 + IAP

GitHub 版本：
✅ 基础密钥管理
✅ 文本/文件加密
✅ 硬件密钥管理（开源）
✅ 所有功能免费

App Store 版本：
✅ 基础密钥管理（免费）
✅ 文本/文件加密（免费）
⭐ 硬件密钥管理（IAP: $9.99）
⭐ 云同步（IAP: $4.99）
⭐ 高级功能包（IAP: $14.99）

优势：
✅ 符合 App Store 政策
✅ 收入稳定
✅ 用户选择多样

劣势：
❌ Apple 抽成 30%
❌ 定价不够灵活
```

#### 方案 B: 分离版本

```
策略：
1. GitHub: 免费版（基础功能）
2. App Store: Pro 版（付费，完整功能）

GitHub 免费版：
✅ 基础密钥管理
✅ 文本/文件加密
❌ 无硬件密钥管理
❌ 无云同步

App Store Pro 版：
✅ 所有功能
💰 一次性购买 $19.99

优势：
✅ 避免 IAP 限制
✅ 定价灵活

劣势：
❌ 无法通过 App Store 吸引免费用户
❌ 竞争力下降
```

#### 方案 C: 功能差异化

```
策略：功能真正差异化

GitHub 版本：
✅ 基础密钥管理
✅ 文本/文件加密
✅ 硬件密钥管理（基础）
❌ 无云同步
❌ 无自动化

App Store Pro 版：
✅ GitHub 版本所有功能
⭐ 硬件密钥管理（高级）
⭐ iCloud 同步
⭐ 自动化脚本
⭐ 优先支持

定价：
- App Store: 免费下载
- IAP Pro 功能: $14.99

优势：
✅ 功能真正差异化
✅ 符合 App Store 政策
✅ 通过免费版吸引用户

劣势：
❌ 需要精心设计功能差异
```

### 推荐方案：方案 A（统一版本）

**理由**:
1. 完全符合 App Store 政策
2. 保持开源精神
3. 收入模式清晰
4. 用户体验一致

## 5. 隐私和数据保护

### 数据收集声明

#### 收集的数据
```
应用访问的数据：
1. 文件系统（用户选择的文件）
2. 密钥和密码（仅本地存储）
3. 硬件设备信息（仅用于管理）
4. 应用使用偏好（本地存储）

不收集的数据：
❌ 用户个人信息
❌ 密钥内容
❌ 加密的文件内容
❌ 设备标识符
❌ 使用统计数据
```

#### 隐私政策要点

```
隐私政策摘要：

1. 数据收集
   - 我们不收集任何个人数据
   - 所有数据仅存储在您的设备上
   - 加密密钥和密码仅存储在您的 Mac 上

2. 数据使用
   - 数据仅用于应用功能
   - 不用于广告或分析
   - 不与第三方共享

3. 数据存储
   - 所有数据存储在应用沙盒内
   - 使用 macOS Keychain 安全存储密码
   - 用户可以随时删除所有数据

4. 云同步（Pro功能）
   - 仅在用户明确启用时使用
   - 使用 Apple iCloud 服务
   - 数据端到端加密
```

### App Store Connect 配置

#### 数据类型声明

```
在 App Store Connect 中声明：

联系信息：
❌ 不收集

健康和健身：
❌ 不收集

财务信息：
❌ 不收集

位置：
❌ 不收集

敏感信息：
✅ 收集（用于加密功能）
  - 密钥和密码
  - 仅本地存储

联系人：
❌ 不收集

用户内容：
✅ 收集（用户选择的文件）
  - 仅用于加密/解密
  - 不上传到服务器

浏览历史：
❌ 不收集

使用数据：
❌ 不收集

诊断：
❌ 不收集（可选，用户可禁用）

其他数据：
❌ 不收集
```

## 6. 开源许可证合规

### 使用的开源组件

| 组件 | 许可证 | 要求 | 影响 |
|------|--------|------|------|
| **GPG** | GPLv3 | 衍生作品必须开源 | ⚠️ 需要开源核心代码 |
| **libgcrypt** | LGPLv2.1 | 允许动态链接 | ✅ 无影响 |
| **SwiftUI** | Apple License | 允许使用 | ✅ 无影响 |

### 合规策略

#### 1. GPG 许可证处理

**问题**: GPG 使用 GPLv3 许可证

**要求**:
- 使用 GPG 的应用必须开源
- 必须提供源代码
- 必须使用相同许可证

**解决方案**:
```
方案 1: 完全开源（推荐）
- 核心代码在 GitHub 开源
- 使用 GPLv3 许可证
- Pro 功能单独闭源模块

方案 2: 动态链接
- 将 GPG 作为独立进程调用
- 通过命令行交互
- 可能存在法律风险
```

#### 2. 许可证声明

在应用中包含许可证声明：

```
关于 GPG Manager

本应用使用以下开源组件：

GNU Privacy Guard (GPG)
Copyright © 1997-2024 Free Software Foundation, Inc.
Licensed under GPLv3

libgcrypt
Copyright © 1998-2024 Free Software Foundation, Inc.
Licensed under LGPLv2.1

[查看完整许可证](link-to-license)
```

## 7. 审核通过检查清单

### 提交前检查

#### 技术合规
- [ ] 应用正确沙盒化
- [ ] 所有权限在 Info.plist 中声明
- [ ] 使用安全作用域书签访问文件
- [ ] 实现正确的错误处理
- [ ] 内置 GPG 工具（不依赖系统）
- [ ] 所有功能在沙盒环境可用

#### 法律合规
- [ ] 填写加密合规问卷
- [ ] 准备隐私政策
- [ ] 检查所有开源许可证
- [ ] 准备应用说明文档
- [ ] 准备硬件访问说明（Pro版）

#### 功能完整性
- [ ] 不依赖外部命令行工具
- [ ] 提供离线功能
- [ ] 实现优雅降级
- [ ] 符合 App Store 政策

#### 用户体验
- [ ] 界面符合 macOS 设计规范
- [ ] 提供帮助文档
- [ ] 错误提示友好
- [ ] 支持深色模式
- [ ] 支持辅助功能

#### 元数据
- [ ] 准备应用截图（至少5张）
- [ ] 编写应用描述
- [ ] 准备关键词
- [ ] 设置正确的年龄分级
- [ ] 准备宣传图片

### 审核后应对

#### 常见审核反馈

1. **沙盒权限问题**
   ```
   反馈：应用访问了未授权的文件
   解决：使用安全作用域书签，添加权限说明
   ```

2. **加密合规问题**
   ```
   反馈：需要更多加密功能说明
   解决：提供详细的加密用途文档
   ```

3. **UI 问题**
   ```
   反馈：界面不符合设计规范
   解决：调整 UI，使用原生组件
   ```

4. **隐私问题**
   ```
   反馈：数据收集说明不清楚
   解决：更新隐私政策，明确说明
   ```

## 8. 替代分发方案

### 如果 App Store 审核不通过

#### 方案 1: 直接分发（公证）
```
流程：
1. 在 Apple Developer 账号中申请公证
2. 上传应用到 Apple 服务器检查
3. 获得公证证书
4. 直接分发 .app 文件

优势：
✅ 无审核限制
✅ 功能完整
✅ 定价自由

劣势：
❌ 需要公证（$99/年）
❌ 用户信任度低
❌ 分发渠道有限
```

#### 方案 2: 混合分发
```
策略：
- App Store: 基础免费版
- 网站: Pro 版本下载

注意：必须确保 App Store 版本功能足够完整
```

#### 方案 3: TestFlight 公开测试
```
流程：
1. 上传到 TestFlight
2. 开启公开测试
3. 分享测试链接

优势：
✅ 可以快速分发
✅ 收集用户反馈
✅ 绕过部分审核限制

劣势：
❌ 最多 90 天测试期
❌ 需要 Apple Developer 账号
```

---

## 总结

### 关键成功因素

1. **技术准备充分**
   - 完全自包含架构
   - 沙盒兼容设计
   - 智能权限管理

2. **合规文档完整**
   - 加密合规问卷
   - 隐私政策
   - 许可证声明

3. **用户体验优秀**
   - 符合设计规范
   - 友好错误处理
   - 清晰的帮助文档

4. **商业模式合理**
   - 符合 App Store 政策
   - 功能差异化明显
   - 用户选择多样

### 下一步行动

1. ✅ 完成技术方案设计
2. ✅ 准备合规文档模板
3. ⏳ 开发 MVP 版本
4. ⏳ 内部测试和优化
5. ⏳ 准备审核材料
6. ⏳ 提交 App Store 审核

---

*最后更新: 2026-03-08*
