# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- OpenPGP card / YubiKey file decryption now asks for the User PIN in the app, uses a bundled `scdaemon` and pinentry so GnuPG `CONFIRM` is answered, and shows a specific smartcard, PIN, or missing-key error instead of a generic decryption failure when the cause is known.
- Sandboxed builds can reach a user-inserted card through `com.apple.security.device.usb` and `com.apple.security.smartcard` on the app and on `scdaemon` only. Other bundled helpers stay inherit-only so `gpg` does not SIGTRAP in `libsecinit`. A bare `bin/scdaemon` cannot apply a standalone sandbox profile, so `scdaemon` is packaged as `Contents/Helpers/MoaiyScdaemon.app` with an on-disk `Info.plist` (`CFBundleIdentifier` `com.moaiy.app.scdaemon`). That helper uses a standalone sandbox (not inherit), including a home-relative read-write exception for the app-managed `GNUPGHOME`, and ships its `@executable_path/../lib` dylibs in `Contents/lib` so dyld can load them after the binary moves out of `gpg.bundle/bin`. The app writes `scdaemon-program` to this helper and keeps `disable-ccid` and `pcsc-shared` in the managed `scdaemon.conf`. Ad-hoc local builds sign the helper and its copied dylibs without hardened runtime, because empty ad-hoc Team IDs are not treated as the same team under library validation. Team-signed App Store or Developer ID builds keep hardened runtime on the helper and those dylibs so the shared Team ID satisfies validation. Library validation is not disabled, and official signed builds still use hardened runtime on the main app.
- App-managed secret key listing reads secret stubs from `private-keys-v1.d` and public key metadata, with `--no-autostart`, so the key list does not start `gpg-agent` or `scdaemon` and does not wait on `SCD SERIALNO`. Card-path failures do not use exponential retries; a missing card still lets the key list appear.
- On decrypt and other card operations, Moaiy starts `MoaiyScdaemon.app` through Launch Services (`NSWorkspace.openApplication`) and waits until `S.scdaemon` accepts connections before starting or using `gpg-agent`. This keeps the helper from being born already sandboxed as a child of `gpg-agent`, which cannot apply a second sandbox profile. A sandboxed Moaiy is launched through CoreServicesUIAgent, which drops `OpenConfiguration` arguments and environment, so the helper's `CFBundleExecutable` is a thin supervisor that ignores Launch Services argv, resolves the real user home with `getpwuid`, and starts `scdaemon --multi-server --homedir` in the helper's own container (a standalone-sandboxed `scdaemon` cannot bind a unix socket in the Moaiy container). The supervisor stays in the foreground and proxies `S.scdaemon` into the app-managed `GNUPGHOME` without logging Assuan traffic. `gpg-agent` still pipe-connects `scdaemon-program --multi-server` on first use instead of attaching to that socket, so `scdaemon-program` points at the launcher, which relays that pipe and rewrites `GETINFO socket_name` to the published path. `--daemon` is not used; a held pipe prevents `--multi-server` from exiting on stdin EOF.

- Decrypting with a YubiKey stub no longer waits for the card helper, `gpg-agent`, or `SCD SERIALNO` before the save dialog. The helper is started in the background while the user picks a destination; presence is still checked before the PIN sheet. An empty reader now shows "No YubiKey detected. Please insert your YubiKey and try again." instead of "Smart card support is unavailable on this device." A missing `scdaemon` or a card error still uses the unavailable-support message.

### Fixed (zh-Hans)
- 智能卡 / YubiKey 文件解密会在应用内询问 User PIN，使用捆绑的 `scdaemon` 与 pinentry 应答 GnuPG `CONFIRM`，并在原因明确时显示智能卡、PIN 或缺少私钥的具体错误，而不是笼统的解密失败。
- 沙盒构建通过 `com.apple.security.device.usb` 与 `com.apple.security.smartcard` 访问用户插入的卡。这两项只签在主程序和 `scdaemon` 上；其余捆绑辅助程序仍只有 `inherit`，避免 `gpg` 在 `libsecinit` 里 SIGTRAP。裸的 `bin/scdaemon` 无法套用独立沙箱配置，因此 `scdaemon` 被打包为带磁盘 `Info.plist` 的 `Contents/Helpers/MoaiyScdaemon.app`（`CFBundleIdentifier` 为 `com.moaiy.app.scdaemon`）。该辅助程序使用独立沙箱（不用 inherit），并带有指向应用托管 `GNUPGHOME` 的 home-relative 读写例外，同时把 `@executable_path/../lib` 依赖库放到 `Contents/lib`，以免二进制从 `gpg.bundle/bin` 挪走后 dyld 找不到库。应用把 `scdaemon-program` 指向该辅助程序，并在托管的 `scdaemon.conf` 中保持 `disable-ccid` 与 `pcsc-shared`。本地 ad-hoc 构建给该辅助程序及其拷贝的动态库签名时不加 hardened runtime，因为空的 ad-hoc Team ID 在库校验里不会被当成同一团队。使用 Team 证书的 App Store 或 Developer ID 构建仍给辅助程序和这些库加上 hardened runtime，以便同一 Team ID 通过校验。不会关闭库校验，正式签名构建的主程序也仍使用 hardened runtime。
- 应用托管的秘密钥列表从 `private-keys-v1.d` 和公钥元数据读取秘密钥存根，并使用 `--no-autostart`，因此不会启动 `gpg-agent` 或 `scdaemon`，也不会等待 `SCD SERIALNO`。智能卡路径失败不会做指数重试；即使没有卡，密钥列表仍会显示。
- 解密及其他智能卡操作时，Moaiy 通过 Launch Services（`NSWorkspace.openApplication`）单独启动 `MoaiyScdaemon.app`，等到 `S.scdaemon` 开始接受连接后，再启动或使用 `gpg-agent`。这样辅助程序不会作为已继承沙箱的 `gpg-agent` 子进程出生，也就不会无法再套用自己的沙箱配置。沙箱内的 Moaiy 会经由 CoreServicesUIAgent 启动辅助程序，启动参数和环境会被丢掉，因此 helper 的 `CFBundleExecutable` 是一个薄监督进程：忽略 Launch Services 的 argv，用 `getpwuid` 解析真实用户家目录，再在 helper 自己的容器里启动 `scdaemon --multi-server --homedir`（独立沙箱中的 `scdaemon` 无法在 Moaiy 容器里 bind unix socket）。监督进程保持前台运行，并把 `S.scdaemon` 代理到应用托管的 `GNUPGHOME`，不记录 Assuan 数据。`gpg-agent` 第一次使用时仍会用管道拉起 `scdaemon-program --multi-server`，不会直接连已在监听的套接字，因此 `scdaemon-program` 指向启动器；启动器转发这条管道，并把 `GETINFO socket_name` 改写成已发布的路径。不使用 `--daemon`；用一根保持打开的管道避免 `--multi-server` 在标准输入遇到 EOF 时退出。
- 使用 YubiKey 存根解密时，不再在保存对话框之前等待智能卡助手、`gpg-agent` 或 `SCD SERIALNO`。用户选择保存位置时会在后台启动助手；仍会在 PIN 输入框之前检查卡片是否在位。读卡器为空时提示“未检测到 YubiKey。请先插入 YubiKey 后重试。”，而不再显示“当前设备不支持智能卡功能。”。缺少 `scdaemon` 或出现卡片错误时，仍使用设备不支持的提示。

## [1.0.2] - 2026-11-23

### Changed
- Bumped app marketing version to `1.0.2` and `CURRENT_PROJECT_VERSION` to `12`.
- Renamed the companion command-line tool from `moaiy-cli` to `moaiy` (Xcode product `MoaiyCLI` target now builds `moaiy`; help, usage and version output updated). Moaiy never installed `moaiy-cli` system-wide, so no migration is performed; users who copied or symlinked it manually can keep a compatibility alias with `ln -sf "$(command -v moaiy)" /usr/local/bin/moaiy-cli`.
- Extracted ZIP create/extract from `BackupManagerView` into `BackupArchiveService` with async pipe draining, timeout, and cancellation.

### Fixed
- Parsed GnuPG `VALIDSIG` unix timestamps from status-fd field 4 (`<sig-timestamp>`), instead of the human-readable `<sig_creation_date>`.

### Security
- Required `[GNUPG:]` `GOODSIG` and `VALIDSIG` together for verification success, and rejected spoofed plaintext, `BADSIG`, `REVKEYSIG`, and related failure signals.
- Stopped Release builds from falling back to a shared `/tmp` GnuPG home when the app-managed directory cannot be created.
- Zero-overwrite scrubbed operation staging directories through `SecureTempStorage.removeOperationDirectory` and `TransientFileRegistry` on exit.
- Killed `gpg-agent` for every homedir used in the session on app termination.
- Defaulted `scripts/verify_gpg_bundle.sh` to read-only SHA-256 verification of bundled GnuPG binaries against `manifest.json`.

### Changed (zh-Hans)
- 将应用营销版本号升级至 `1.0.2`，工程构建版本号递增至 `12`。
- 命令行伴侣工具由 `moaiy-cli` 更名为 `moaiy`。应用从未自动安装 `moaiy-cli`，因此不做迁移；手动安装过的用户可自行创建 `moaiy-cli` 兼容别名。
- 将备份 ZIP 的创建与解压从 `BackupManagerView` 下沉到 `BackupArchiveService`，并改为异步排空管道、超时与取消。

### Fixed (zh-Hans)
- 修正 GnuPG `VALIDSIG` 状态行时间戳解析，改为读取第 4 字段 unix 时间戳，而不再误读人类可读日期。

### Security (zh-Hans)
- 验签必须同时存在带 `[GNUPG:]` 前缀的 `GOODSIG` 与 `VALIDSIG`，并拒绝伪造明文、`BADSIG`、`REVKEYSIG` 等失败信号。
- Release 在无法创建应用托管 GnuPG 目录时直接失败，不再回退到共享 `/tmp` 路径。
- 通过 `SecureTempStorage.removeOperationDirectory` 与退出时的 `TransientFileRegistry` 对 staging 目录做零填充后删除。
- 应用退出时对会话中使用过的每个 homedir 终止 `gpg-agent`。
- `scripts/verify_gpg_bundle.sh` 默认只读校验捆绑 GnuPG 二进制与 `manifest.json` 的 SHA-256。

## [1.0.1] - 2026-10-22

### Added

- Added `GPGHelper.entitlements` (`com.apple.security.app-sandbox` + `com.apple.security.inherit`) and `scripts/sign_embedded_gpg_bundle.sh` build phase to sign embedded `gpg.bundle` helper executables for App Sandbox child process inheritance.
- Added Required Reason API declarations (`NSPrivacyAccessedAPICategoryDiskSpace` `E174.1` and `NSPrivacyAccessedAPICategoryFileTimestamp` `C617.1`) to `Moaiy/PrivacyInfo.xcprivacy`.
- Added `ITSAppUsesNonExemptEncryption` export compliance declaration to `Moaiy/Info.plist`.
- Added `gpgconf --kill gpg-agent` application termination cleanup hook via `TransientFileRegistry` and `GPGService`.
- Documented bundled GnuPG 2.5.21 runtime components, open-source licenses, and CLI process isolation boundary in `THIRD_PARTY_NOTICES.md`.

### Changed

- Bumped app marketing version to `1.0.1` and `CURRENT_PROJECT_VERSION` to `11`.
- Gated locked Pro placeholder UI in `SettingsView` and `KeyActionMenu` when `MoaiyProKit` is not linked while preserving `NoopProModule` contract descriptors.
- Locked target architecture to `arm64` (`Apple Silicon`) in `Moaiy.xcodeproj`, `scripts/package_dmg.sh`, and `scripts/release/run_release.sh`, and removed unused `gpg-wks-server` and `gpgtar` binaries from `gpg.bundle`.
- Updated `KeychainService` to allow safe fallback to macOS login Keychain on `errSecMissingEntitlement (-34018)` during unsigned/ad-hoc local builds when biometrics are not required.

### Added (zh-Hans)

- 新增 `GPGHelper.entitlements`（`com.apple.security.app-sandbox` + `com.apple.security.inherit`）及 `scripts/sign_embedded_gpg_bundle.sh` 构建阶段，为 `.app` 内嵌 `gpg.bundle` 可执行文件注入子进程沙盒继承签名。
- 在 `Moaiy/PrivacyInfo.xcprivacy` 中补齐 `NSPrivacyAccessedAPICategoryDiskSpace`（`E174.1`）与 `NSPrivacyAccessedAPICategoryFileTimestamp`（`C617.1`）必填原因 API 声明。
- 在 `Moaiy/Info.plist` 中新增 `ITSAppUsesNonExemptEncryption` 加密出口合规声明。
- 通过 `TransientFileRegistry` 与 `GPGService` 新增应用退出自动终止 `gpg-agent` 驻留守护进程的清理挂钩。
- 在 `THIRD_PARTY_NOTICES.md` 中完整声明内嵌 GnuPG 2.5.21 运行时各组件许可证及 CLI 进程边界。

### Changed (zh-Hans)

- 将应用营销版本号升级至 `1.0.1`，工程构建版本号递增至 `11`。
- 当未链接 `MoaiyProKit` 模块时自动隐藏 `SettingsView` 与 `KeyActionMenu` 中的锁定 Pro 占位入口，同时完整保留 `NoopProModule` 契约描述符。
- 在 `Moaiy.xcodeproj`、`scripts/package_dmg.sh` 与 `scripts/release/run_release.sh` 中统一锁定 `arm64`（Apple Silicon）构建架构，并从 `gpg.bundle` 中移除未使用的 `gpg-wks-server` 与 `gpgtar`。
- 优化 `KeychainService` 在本地无证书 Ad-hoc 构建下（返回 `-34018` 且未开启生物识别时）的登录钥匙串回退兼容性。

## [1.0.0] - 2026-10-17

### Added

- Added `StreamingCryptoPipeline` supporting 256KB chunked streaming I/O, independent `stdinQueue`/`stdoutQueue` backpressure throttling (8MB max in-flight buffer), per-chunk `autoreleasepool` drainage (<32MB Peak RSS delta on 64MB streams), non-blocking `readabilityHandler` IPC, and isolated `0600` passphrase token files.
- Added `CryptoProgress` and `StreamingProgressReporter` with 10Hz UI throttling for responsive progress callbacks.
- Added `SecureMemory` (`SecureBytes`, `SecureString`) providing best-effort internal buffer clearing via Darwin `memset_s` upon deallocation.
- Added `TransientFileRegistry` wired into `SecureTempStorage` and `NSApplication.willTerminateNotification` to zero-scrub and purge active scratch directories upon application exit, plus 24-hour stale directory cleanup on launch.
- Added `KeychainService` integrating macOS Data Protection Keychain with `LocalAuthentication` (`.userPresence`), supporting Touch ID, Apple Watch, and device passcode fallback with thread-safe background lookup and compile-time `#if DEBUG` legacy Keychain fallback isolation.
- Added single-pass `GPGService.resolvePrimaryFingerprint` (`--list-secret-keys --with-colons --fixed-list-mode`) and typed `GPGError.ambiguousKeyReference` to resolve 8-char short IDs, 16-char long IDs, primary fingerprints, and subkey fingerprints in a single subprocess call.
- Added standalone `moaiy-cli` companion command-line tool (`MoaiyCLI` target) with `SIGPIPE` protection and subcommands for `status` (including structured Kyber-768 algorithm detection), `list-keys`, `encrypt`, and `decrypt`.
- Integrated `encryptFileStreaming` and `decryptFileStreaming` into `GPGService` and `KeyActionMenu` with full `decryptFile` parity (`--status-fd 2`, `DECRYPTION_OKAY` verification, recipient key matching, and Keychain passphrase lookup).

### Changed

- Bumped app marketing version to `1.0.0` and `CURRENT_PROJECT_VERSION` to `10`.
- Hardened `SecureTempStorage.commitStagedFile` with POSIX `statfs` net disk-space calculation (`max(0, stagedSize - existingSize)`), `open(O_WRONLY)` permission preflight, container-backed rollback backup (`original.bak`) with zero-scrubbing, and in-place `ftruncate` + stream write + `fsync` to preserve `NSSavePanel` sandbox security scope and target inode without data loss.
- Initialized `TransientFileRegistry` lifecycle hooks in `MoaiyApp` startup sequence.

### Security

- Enforced strict `0600` permissions and zero-overwrite scrubbing before `unlink` on temporary passphrase token files and operation scratch directories.
- Restricted legacy macOS Keychain fallback in `KeychainService` strictly to `#if DEBUG` builds (`allowLegacyKeychainFallback`), ensuring Release builds fail closed on missing Data Protection Keychain entitlements.

### Added (zh-Hans)

- 新增 `StreamingCryptoPipeline` 流式加解密管道，支持 256KB 分块读写、独立 `stdinQueue`/`stdoutQueue` 双队列 8MB 背压限流、分块 `autoreleasepool` 内存及时释放（64MB 流式传输峰值 RSS 增量 `< 32MB`）、非阻塞 `readabilityHandler` 管道读取以及独立的 `0600` 权限口令令牌文件隔离。
- 新增 `CryptoProgress` 与 `StreamingProgressReporter` 进度通知器，支持 10Hz 防抖节流，避免大文件传输时 UI 渲染拥塞。
- 新增 `SecureMemory` 内存安全工具（`SecureBytes`、`SecureString`），在释放时通过 Darwin `memset_s` 尽力清零内部字节缓冲区。
- 新增 `TransientFileRegistry` 临时目录生命周期跟踪器，接入 `SecureTempStorage` 与 `NSApplication.willTerminateNotification`，在应用退出时自动清零并移除挂起目录，并在启动时清理超过 24 小时的陈旧残留目录。
- 新增 `KeychainService` 系统钥匙串服务，集成 macOS Data Protection Keychain 与 `LocalAuthentication`（`.userPresence`），支持 Touch ID、Apple Watch 与系统密码回退、后台线程非阻塞读取，以及仅限 `#if DEBUG` 编译期的旧版钥匙串受控回退。
- 新增单次子进程调用的 `GPGService.resolvePrimaryFingerprint`（基于 `--list-secret-keys --with-colons --fixed-list-mode`）与强类型错误 `GPGError.ambiguousKeyReference`，一次性解析 8 位短 ID、16 位长 ID、主钥指纹及子钥指纹。
- 新增独立 `moaiy-cli` 命令行伴侣工具（`MoaiyCLI` Target），内置 `SIGPIPE` 防护，完整支持 `status`（含 Kyber-768 算法探测）、`list-keys`、`encrypt` 与 `decrypt` 子命令。
- 在 `GPGService` 与 `KeyActionMenu` 中接入 `encryptFileStreaming` 与 `decryptFileStreaming`，并与 `decryptFile` 保持完整行为对齐（`--status-fd 2`、`DECRYPTION_OKAY` 校验、指定私钥匹配校验及钥匙串口令自动读取）。

### Changed (zh-Hans)

- 将应用营销版本号升级至 `1.0.0`，工程构建版本号递增至 `10`。
- 加固 `SecureTempStorage.commitStagedFile` 原地覆盖安全性：通过 POSIX `statfs` 计算扣除被覆盖文件后的净需空间（`max(0, stagedSize - existingSize)`），执行 `open(O_WRONLY)` 权限预检、回滚备份（`original.bak`）清零销毁，以及 `ftruncate` + 流式写入 + `fsync` 原地覆盖，在保留 `NSSavePanel` 沙盒授权与目标文件 inode 的同时杜绝权限或 I/O 错误导致的数据丢失。
- 在 `MoaiyApp` 启动入口中初始化 `TransientFileRegistry` 退出清理挂钩。

### Security (zh-Hans)

- 对临时口令令牌文件与操作暂存目录强制执行 `0600`/`0700` 权限，并在删除前执行清零覆写（`zeroScrubDirectoryContents` + `fsync`）。
- 将 `KeychainService` 的旧版钥匙串回退严格限制在 `#if DEBUG` 编译期（`allowLegacyKeychainFallback`），确保 Release 构建在缺失 Entitlement 时严格失败关闭。

## [0.9.0] - 2026-07-06

### Added

- Added Kyber-768 hybrid OpenPGP key generation support backed by bundled GnuPG 2.5.21.
- Added post-quantum capability detection, key classification, and PQC-aware encryption/decryption validation.
- Added UI, settings, and Pro policy gates for Kyber-768 availability with compatibility guidance.
- Added backup, restore, migration, and interoperability regression coverage for post-quantum keys.

### Changed

- Updated bundled `gpg.bundle` to GnuPG 2.5.21 after validating Kyber secret-key import behavior.
- Bumped app version metadata to `0.9.0`.
- Extended release validation gates and generated release metadata with post-quantum compatibility caveats.

### Fixed

- Prevented unavailable Kyber defaults from being applied when the active bundled GPG does not advertise post-quantum support.

### Added (zh-Hans)

- 新增基于内置 GnuPG 2.5.21 的 Kyber-768 混合 OpenPGP 密钥生成支持。
- 新增抗量子能力检测、密钥分类，以及面向 PQC 的加密/解密验证。
- 新增 Kyber-768 可用性相关的 UI、设置与 Pro 策略门禁，并提供兼容性提示。
- 新增抗量子密钥的备份、恢复、迁移与互操作回归覆盖。

### Changed (zh-Hans)

- 将内置 `gpg.bundle` 更新到 GnuPG 2.5.21，并验证 Kyber 私钥导入行为。
- 将应用版本元数据升级到 `0.9.0`。
- 扩展发布验证门禁与生成的发布元数据，加入抗量子兼容性说明。

### Fixed (zh-Hans)

- 当当前内置 GPG 未声明抗量子支持时，阻止应用不可用的 Kyber 默认策略。

## [0.8.2] - 2026-05-03

### Added

- Added runtime localization guard workflow (`.github/workflows/runtime-localization-guard.yml`) and validator script (`scripts/check_runtime_localization_keys.py`) to verify compiled `Localizable.strings` coverage against `Localizable.xcstrings`.
- Added localization placeholder completions for dynamic Pro/runtime keys across all supported locales to prevent `%@` / `%lld` runtime formatting regressions.

### Changed

- Bumped app version metadata to `0.8.2` and incremented `CURRENT_PROJECT_VERSION` to `9`.
- Hardened release execution scripts/workflows: enforced signed publish flow in release orchestration and aligned CI/release workflow dependencies with current stable GitHub Actions versions.
- Updated release and project documentation pointers for the 0.8.x hardening state and latest stable version references.

### Fixed

- Removed insecure `hkp://` / `http://` keyserver fallback path from keyserver defaults, keeping secure transport-only behavior in normal flows.
- Fixed app icon asset wiring so packaged apps correctly resolve the bundled icon resources.
- Fixed post-merge localization catalog consistency for the audit/release branch after mainline conflict resolution.

### Added (zh-Hans)

- 新增运行时本地化门禁工作流（`.github/workflows/runtime-localization-guard.yml`）与校验脚本（`scripts/check_runtime_localization_keys.py`），用于对比编译产物 `Localizable.strings` 与 `Localizable.xcstrings` 的覆盖一致性。
- 为动态 Pro/运行时文案 key 在全部已支持语种补齐占位符翻译，避免 `%@` / `%lld` 在运行时格式化回退或异常。

### Changed (zh-Hans)

- 将应用版本元数据升级到 `0.8.2`，并将 `CURRENT_PROJECT_VERSION` 递增到 `9`。
- 强化发布执行脚本与工作流：在发布编排中强制签名发布约束，并将 CI/发布工作流依赖统一到当前稳定版 GitHub Actions。
- 更新发布与项目文档中的版本状态说明，统一 0.8.x 加固阶段和最新稳定版本指引。

### Fixed (zh-Hans)

- 从 keyserver 默认链路中移除不安全的 `hkp://` / `http://` 回退，仅保留安全传输策略。
- 修复应用图标资源装配，确保打包后的 App 正确显示内置图标资源。
- 修复审计/发布分支与主干合并冲突后的本地化目录一致性问题。

## [0.8.1] - 2026-04-19

### Added

- Added v0.8.1 release hardening tracker (`doc/v0.8.1-release-hardening-tracker.md`) for branch execution and gate closure.
- Added comprehensive post-release audit briefing for v0.8.0 (`doc/v0.8.0-post-release-audit-2026-04-19.md`).

### Changed

- Updated release workflow tag SHA resolution to support both annotated and lightweight tags in preflight/publish checks.
- Upgraded GitHub Actions dependencies to current stable major versions in CI/release workflows (`checkout`, `upload-artifact`, `download-artifact`).
- Updated top-level documentation status pointers to reflect v0.8.0 as latest stable and v0.8.1 as active hardening rollout.
- Bumped app version metadata from `0.8.0` to `0.8.1` and incremented `CURRENT_PROJECT_VERSION` from `7` to `8`.

### Fixed

- Fixed release-note renderer behavior: missing `zh-Hans` detailed changelog sections now fail fast instead of silently falling back to English bodies.
- Added `zh-Hans` detailed update blocks to the v0.8.0 changelog section to keep bilingual release-note generation deterministic.

### Added (zh-Hans)

- 新增 v0.8.1 发布加固追踪文档（`doc/v0.8.1-release-hardening-tracker.md`），用于执行过程与门禁收口跟踪。
- 新增 v0.8.0 发布后全面审计简报（`doc/v0.8.0-post-release-audit-2026-04-19.md`）。

### Changed (zh-Hans)

- 更新发布工作流中的 tag SHA 解析逻辑，使 preflight/publish 阶段同时兼容 annotated 与 lightweight tag。
- 升级 CI/发布工作流中的 GitHub Actions 依赖到当前稳定主版本（`checkout`、`upload-artifact`、`download-artifact`）。
- 更新顶层文档中的版本状态指引：`v0.8.0` 为最新稳定版，`v0.8.1` 为当前加固迭代。
- 将应用版本元数据从 `0.8.0` 升级到 `0.8.1`，并将 `CURRENT_PROJECT_VERSION` 从 `7` 递增至 `8`。

### Fixed (zh-Hans)

- 修复发布说明渲染器行为：当缺失 `zh-Hans` 详细变更区块时改为快速失败，避免中文部分回退为英文正文。
- 为 `v0.8.0` 的 CHANGELOG 区块补齐 `zh-Hans` 详细变更，确保双语发布说明可稳定生成。

## [0.8.0] - 2026-04-18

### Added

- Added optional Pro binary adapter path (`ProModuleFactory` + `ProBinaryModuleAdapter`) so Core can run with injected `MoaiyProKit` while preserving Noop fallback in public CI.
- Added internal Pro injection workflow (`.github/workflows/internal-pro-injection-ci.yml`) for injected-mode build/test validation.
- Added v0.8.0 rollout tracker (`doc/v0.8.0-pro-rollout-tracker.md`) to track Pro-first release execution and audit gates.

### Changed

- Hardened Pro module fallback behavior: Core now falls back to `NoopProModule` when required injected descriptors are not present.
- Normalized injected settings descriptors to ensure full `ProFeature` coverage even when private module descriptors are partial.
- Improved Pro action execution UX in key menu: prevent duplicate trigger, refresh entitlements before execute, and surface running state icon.
- Updated Pro contracts documentation with private artifact pipeline and current HardwareKeyAdvanced v1 diagnostic flow.

### Fixed

- Fixed stale Pro availability edge case in action execution path by forcing entitlement refresh before dispatch.
- Fixed injected-module partial-descriptor risk that could leave Settings feature list incomplete.

### Added (zh-Hans)

- 新增可选 Pro 二进制适配路径（`ProModuleFactory` + `ProBinaryModuleAdapter`），使 Core 在保持 Noop 回退的前提下支持注入 `MoaiyProKit`，并继续兼容公共 CI。
- 新增内部 Pro 注入工作流（`.github/workflows/internal-pro-injection-ci.yml`），用于注入模式下的构建与测试验证。
- 新增 v0.8.0 推进追踪文档（`doc/v0.8.0-pro-rollout-tracker.md`），用于记录 Pro 优先发布的执行与审计关卡。

### Changed (zh-Hans)

- 强化 Pro 模块回退行为：当注入模块未提供必需 descriptor 时，Core 自动回退到 `NoopProModule`。
- 统一注入模式下的 Settings descriptor 归一化逻辑，确保 `ProFeature` 覆盖完整，即使私有模块只返回部分 descriptor。
- 优化钥匙菜单中的 Pro 动作执行体验：防重复触发、执行前刷新 entitlement、执行中显示运行状态图标。
- 更新 Pro 契约文档，补充私有产物发布链路与当前 HardwareKeyAdvanced v1 诊断流程。

### Fixed (zh-Hans)

- 修复 Pro 动作路径中的可用性缓存陈旧问题：在分发执行前强制刷新 entitlement。
- 修复注入模块 descriptor 不完整时可能导致 Settings 功能列表缺失的风险。

## [0.7.1] - 2026-04-16

### Added

- Expanded subkey lifecycle operations in the management sheet: revoke subkey, disable subkey, and re-enable subkey.
- Added subkey risk/rotation UX: high-risk and expiring indicators, filter and sort controls, and rotation guidance panel.
- Added service-layer APIs for subkey revoke/disable/enable and command-builder coverage for these paths.
- Added subkey lifecycle regression coverage in hardening flow tests (add/update/disable/enable/revoke end-to-end).

### Changed

- Refactored subkey management view model mutation flow to a unified lifecycle mutation pipeline with refresh-on-success.
- Updated release-note rendering flow to require detailed changelog-derived update sections in generated notes.

### Fixed

- Fixed subkey management passphrase handling and batch command sequencing for non-interactive subkey revocation.

### Added (zh-Hans)

- 在子密钥管理面板中扩展生命周期操作：吊销子密钥、禁用子密钥、重新启用子密钥。
- 新增子密钥风险与轮换体验：高风险与临期标记、筛选与排序控制、轮换建议面板。
- 服务层新增子密钥吊销/禁用/启用 API，并补充对应命令构建路径的测试覆盖。
- 在安全加固流程测试中新增子密钥生命周期回归覆盖（新增/更新/禁用/启用/吊销端到端）。

### Changed (zh-Hans)

- 重构子密钥管理状态变更流程为统一生命周期管线，操作成功后自动刷新界面。
- 更新发布说明渲染流程，要求生成内容必须包含从 CHANGELOG 派生的详细更新条目。

### Fixed (zh-Hans)

- 修复子密钥管理中的口令处理与批处理命令顺序，确保非交互子密钥吊销流程正确执行。

## [0.7.0] - 2026-04-16

### Added

- Added subkey management MVP for local secret keys (non smart-card stubs): list subkeys, add subkey, and update subkey expiration.
- Added ownertrust transfer flow: export ownertrust to file and import ownertrust from file.
- Added revocation management flow: generate ASCII-armored revocation certificate and import revocation certificate.
- Added service-layer command-builder coverage for ownertrust/revocation command construction.
- Added end-to-end hardening regression cases for ownertrust and revocation lifecycle + wrong-passphrase error mapping.
- Added release planning/task breakdown document for 0.7.x (`doc/v0.7.x-task-breakdown.md`).

### Changed

- Extended key action menu with trust operations entry points for ownertrust transfer and revocation center.
- Added Settings toggle for key-signing menu availability to reduce default action surface.
- Adjusted subkey card layout density to reduce card height and improve information scanning.
- Updated trust management sheet composition to host ownertrust/revocation sheets and align with actor-isolation requirements.
- Updated string catalog with new ownertrust/revocation/settings keys and 11-locale coverage.

### Fixed

- Fixed `TrustManagementSheet` default parameter actor-isolation warning by removing actor-isolated singleton from default argument context.
- Fixed ownertrust "none" downgrade command mapping to use gpg-compatible value for non-interactive trust updates.
- Fixed revocation certificate generation flow by removing unsupported batch flag from interactive revoke command path.

## [0.6.5] - 2026-04-15

### Added

- Expanded in-app language options to 11 locales (`en`, `zh-Hans`, `es`, `pt-BR`, `hi`, `ar`, `fr`, `de`, `ja`, `ko`, `ru`) while keeping default `Follow System`.
- Added localization integrity automation (`scripts/check_localization.py`) and CI hard-fail gate for missing keys/placeholder mismatches.

### Changed

- Refactored language metadata and dynamic bundle resolution for app-level localization selection in Settings.
- Updated project locale declarations (`knownRegions`) and completed string catalog coverage for newly supported locales.
- Bumped app marketing version from `0.6.1` to `0.6.5`.

### Fixed

- Fixed runtime language switching so main UI text updates immediately without app restart.
- Fixed Key Edit sheet layout overflow for long localized content (notably Japanese/Russian) with adaptive tab presentation.
- Right-aligned the Settings `Default Key Type` control for consistent form alignment.

## [0.6.1] - 2026-04-14

### Changed

- Updated release DMG naming to use hardware-friendly labels:
  - `Moaiy-X.Y.Z-macos-apple-silicon.dmg`
  - `Moaiy-X.Y.Z-macos-intel-chip.dmg`
- Bumped app marketing version from `0.6.0` to `0.6.1`.

## [0.5.3] - 2026-04-06

### Added

- Protected release workflow v2 (`.github/workflows/release.yml`) with manual dispatch inputs:
  - `version`
  - `mode (draft|publish)`
  - `signing (auto|unsigned|signed)`
  - `gate (balanced|strict|fast)`
- Release orchestration scripts under `scripts/release/`:
  - `run_release.sh`
  - `check_version_sync.sh`
  - `external_validation.sh`
  - `render_release_notes.sh`
  - `setup_tag_ruleset.sh`
  - release notes template

### Changed

- CI `build-and-test` now runs both build and tests, matching `main` protection semantics.
- `package_dmg.sh` now supports architecture-aware packaging, artifact naming, and explicit version consistency checks.
- Legacy `v050_external_validation.sh` now delegates to the version-agnostic validation script for backward compatibility.

### Security

- Introduced repository tag ruleset support script to protect `v*` tags from deletion and non-fast-forward rewrites.

## [0.5.1] - 2026-04-05

### Changed

- Hidden the `Backup/Restore` action-menu entry by default while keeping the full flow implementation behind a feature toggle.
- Centered create-key loading/success states for consistent modal feedback alignment.
- Moved the key-management footer brand logo/text note into a non-blocking background layer to prevent key-card content occlusion.

### Fixed

- Updated key action menu availability tests to verify backup menu is hidden by default and still restorable via flag.

## [0.5.0] - 2026-04-10

### Added

- D1-D6 minimal release execution artifacts:
  - `doc/v0.5.0-minimal-release-checklist.md`
  - `doc/v0.5.0-core-flow-validation.md`
  - `doc/v0.5.0-d4-regression-matrix.md`
  - `doc/v0.5.0-d4-manual-regression-script.md`
  - `doc/v0.5.0-release-blockers.md`
  - `doc/v0.5.0-security-audit.md`
  - `doc/v0.5.0-release-notes.md`
- Added text-flow integration tests (`TextEncryptionFlowTests`) covering:
  - encrypt/decrypt roundtrip
  - decrypt failure with invalid passphrase
  - encrypt failure with invalid recipient
- Added file-flow integration tests (`FileEncryptionFlowTests`) covering:
  - file encrypt/decrypt roundtrip
  - conflict-safe destination suffix behavior

### Changed

- Exposed Backup/Restore entry in key action menu for primary user path.
- Completed release i18n quick pass on `Views + App` UI keys with explicit `en` and `zh-Hans` coverage.
- Localized key-management footer tagline and app navigation title using symbol keys.
- Restored app icon build configuration to `moaiy_icon` and embedded Icon Composer asset under `Assets.xcassets`.

### Fixed

- Fixed `actool` crash in thinned asset compile by moving `moaiy_icon.icon` into `Assets.xcassets` and avoiding standalone icon catalog input.
- Fixed release-blocking backup entry visibility issue in primary key action flow (`RB-003`).

### Security

- Fixed newline/control-character injection surface in key generation batch payload (`SAF-001`).
- Removed sensitive identity details from logs and replaced with non-identifying messages (`SAF-002`).
