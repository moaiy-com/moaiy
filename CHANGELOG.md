# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release execution checklist for v0.5.0 (`doc/v0.5.0-minimal-release-checklist.md`)
- Core flow validation list for v0.5.0 (`doc/v0.5.0-core-flow-validation.md`)

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
