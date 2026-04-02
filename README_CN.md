# Moaiy

> 通过拖放，保护你最重要的信息。

Moaiy 帮你通过简单、易操作的步骤保护重要信息。

Moaiy 是一个开源的 macOS 原生应用，专注于信息保护与恢复工作流，使用 SwiftUI 构建。

**[English Version](./README.md)**

## 功能特性

- 生成、导入、导出和删除密钥
- 文本加密与解密
- 文件加密与解密
- 信任管理、密钥签名与密钥编辑流程
- 备份与恢复流程
- 支持在沙盒环境中使用内置 GPG 运行时

## 环境要求

- macOS 14.0+（应用运行环境）
- 支持 macOS 14 SDK 的 Xcode（建议使用最新稳定版）

## 快速开始

### 方式 1：下载发布版本

- 从 [GitHub Releases](https://github.com/moaiy-com/moaiy/releases) 下载最新 `.dmg`

### 方式 2：源码构建

```bash
git clone https://github.com/moaiy-com/moaiy.git
cd moaiy
open Moaiy/Moaiy.xcodeproj
```

或使用命令行构建：

```bash
xcodebuild -project Moaiy/Moaiy.xcodeproj \
           -scheme Moaiy \
           -destination 'platform=macOS' \
           build
```

## 运行测试

```bash
xcodebuild test -project Moaiy/Moaiy.xcodeproj \
                -scheme Moaiy \
                -destination 'platform=macOS'
```

## 内置 GPG 工作流

如果需要刷新内置 GPG bundle，可执行：

```bash
./scripts/prepare_gpg_bundle.sh
./scripts/verify_gpg_bundle.sh
```

如果尚未将 bundle 添加到 Xcode，可执行：

```bash
./scripts/add_gpg_bundle_to_xcode.sh
```

## 仓库结构

```text
moaiy/
├── Moaiy/                  # 主 macOS 应用
├── MoaiySandboxTest/       # 沙盒验证项目
├── scripts/                # 构建与打包脚本
├── doc/                    # 技术文档
├── CONTRIBUTING.md
├── DISCLAIMER.md
├── README.md
└── LICENSE
```

## 文档

- [贡献指南](./CONTRIBUTING.md)
- [文档索引](./doc/README.md)
- [技术架构](./doc/technical-architecture.md)
- [Xcode 集成指南](./doc/xcode-integration-guide.md)
- [内置 GPG 概览](./doc/bundled-gpg-summary.md)

## 本地化

- UI 语言：English + 简体中文
- 字符串资源：`Moaiy/Resources/Localizable.xcstrings`

## 安全

如果发现安全问题，建议优先通过 GitHub Security Advisories 进行私下披露，而不是先公开提交 Issue。

## 许可证

MIT，详见 [LICENSE](./LICENSE)。

## 免责声明

关于密钥管理、密钥泄漏、信息暴露与财产损失等责任边界，请查看英文版 [DISCLAIMER.md](./DISCLAIMER.md)。
