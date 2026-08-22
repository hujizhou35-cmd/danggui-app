# 当归 1.0.0 隐私与平台发布前审计

- 审计日期：2026-08-22
- 审计对象：Android 与 iOS 的已检入源配置、Dart 生产源码、`pubspec.lock`，以及执行 `flutter pub get` 后解析到的移动端原生插件元数据。
- 产品边界：本地优先；应用自身不联网，不包含账号、广告、分析、遥测、远程推送或云同步。

## 结论

当前源配置符合上述应用级离线边界。Android 源清单只有本地提醒所需的三个权限；iOS 没有 entitlement 文件、远程通知 entitlement、后台网络模式或联网能力；生产 Dart 与原生入口未发现网络 API 或硬编码远端地址；运行时依赖采用显式允许名单，锁文件中的托管包均带 SHA-256，且没有 git/path 依赖。

这一结论是“源配置验证”，不是对尚未生成的最终 APK、AAB 或未来签名 IPA 的替代证明。最终 Android APK 必须继续通过 `tool/verify_android_artifacts.ps1` 或 CI 中对应的 shell 检查；iOS 当前只交付源码和未签名编译证据，不声明已完成签名 IPA 审计。

## 审计矩阵

| 范围 | 验证结果 | 自动化门禁 |
| --- | --- | --- |
| 应用身份 | Android `namespace`/`applicationId` 与 iOS bundle ID 均为 `com.danggui.memo` | Dart 审计 + 平台静态测试 + APK 检查 |
| 版本 | `1.0.0+1`；平台构建值均来自 Flutter 版本变量 | Dart 审计 + APK 检查 + iOS 构建脚本 |
| Android SDK | min 24、target 36、compile 36；Java/Kotlin 17 | Dart 审计 + APK 检查 |
| iOS 目标 | iOS 15.0；iPhone/iPad 均只允许竖屏 | Dart 审计 + iOS 构建脚本 |
| Android 权限 | 仅 `POST_NOTIFICATIONS`、`VIBRATE`、`RECEIVE_BOOT_COMPLETED` | 源清单精确集合 + 解析插件清单 + 最终 APK 精确集合 |
| 提醒能力 | 使用 `inexactAllowWhileIdle`；无精确闹钟、全屏通知或前台服务权限 | 源码模式检查 + 最终 APK 权限检查 |
| iOS 通知 | 仅本地 `UserNotifications`；无 `aps-environment`、远程注册或 `remote-notification` 后台模式 | plist/pbxproj/entitlement/原生源码扫描 |
| 网络边界 | 无 INTERNET/网络状态权限，无 ATS 放宽，无 Dart/Android/iOS 网络 API，无远端端点 | 多语言静态扫描 + 最终 APK 权限检查 |
| 数据备份 | Android 系统云备份和设备迁移覆盖 root/file/database/sharedpref/external 全部排除；iOS 每次启动对 Application Support/danggui 设置排除提示 | 清单/XML、AppDelegate 与负向篡改检查 |
| 依赖 | 运行时依赖显式允许名单；锁文件无 Firebase/分析/广告/推送 SDK；托管依赖均有 SHA-256 | `pubspec.yaml`/`pubspec.lock` 解析 + 已解析原生插件扫描 |
| 原生暴露面 | 三个通知 receiver 均 `exported=false`；唯一导出 Activity 是系统启动入口 | 源清单检查 + 最终合并清单检查 |
| 清晰文本 | `usesCleartextTraffic=false`，且应用无联网权限 | 源清单 + 最终 APK 合并清单 |

## 权限合理性

- `POST_NOTIFICATIONS`：Android 13+ 首次创建未来提醒时由用户授权；拒绝后应用记录状态并继续提供无通知的本地功能。
- `VIBRATE`：实现用户可选的本地提醒振动。
- `RECEIVE_BOOT_COMPLETED`：设备重启或应用更新后恢复已排期的本地提醒。

未声明 `INTERNET`、`ACCESS_NETWORK_STATE`、`SCHEDULE_EXACT_ALARM`、`USE_EXACT_ALARM`、`USE_FULL_SCREEN_INTENT`、广告 ID、存储、定位、相机或麦克风权限。`PROCESS_TEXT` 的 `<queries>` 只是 Flutter 文本处理所需的包可见性声明，不是权限，也不提供网络访问。

## iOS 能力与备份说明

项目没有 `.entitlements`、`CODE_SIGN_ENTITLEMENTS` 或 Xcode `SystemCapabilities` 配置，也没有 `UIBackgroundModes`、ATS 放宽、Bonjour、本地网络或跟踪说明。`AppDelegate` 只设置本地通知 delegate 和插件注册，不调用远程通知注册 API。

iOS 没有启用 iCloud container/CloudKit 能力，应用代码也不调用上传 API。应用每次启动都会创建/定位 `Application Support/danggui`，并通过 `URLResourceValues.isExcludedFromBackup=true` 向系统标记整个应用私有数据目录；数据库和自动备份子目录均位于该目录下。自动备份口令使用 `first_unlock_this_device` Keychain 可访问性并明确 `synchronizable=false`，避免口令同步到 iCloud Keychain 或迁移到另一设备。

`isExcludedFromBackup` 是应用向 iOS 提交的最佳努力资源属性，不是对所有操作系统版本、用户工具或物理取证场景的绝对保证。审计器证明排除动作仍被调用并配置正确，未来还应在真机设备备份流程中抽查；产品文案应保持“应用自身不上载、尽力排除系统备份”，不应宣称能够控制系统和用户的所有备份行为。

## 依赖解释

锁文件可能包含测试/构建工具间接使用的 `http`，以及 `share_plus` 在 Linux/Web/Windows 的 `url_launcher_*` 联邦实现；它们不是 Android/iOS 的应用直接依赖，生产 Dart 也没有导入这些包。门禁会检查 Android/iOS 实际解析到的非 dev 插件生产清单：插件不能引入本地提醒允许名单以外的权限，iOS 插件生产元数据不能引入远程推送或网络 API。

系统分享页和系统文件选择器只在用户主动操作后接收本地文件。应用不选择分享目标、不在后台发送文件，也不把系统分享动作表述为应用上传。

## 自动化运行

Windows 一键源审计：

```powershell
pwsh -File tool/audit_privacy_platform.ps1
```

跨平台核心门禁（CI 工作流在 `flutter pub get` 后执行）：

```text
dart run tool/audit_offline_boundary.dart
flutter test test/platform/privacy_platform_config_test.dart --reporter expanded
```

静态测试还会在临时副本中主动注入 INTERNET/精确闹钟/全屏通知权限、Firebase 依赖、精确调度 API、HTTPS 端点和 iOS entitlement，并破坏 iOS 系统备份排除及 Keychain 本机限定选项，确认审计器会失败关闭，而不是只验证当前“恰好通过”的文件。

## 源配置与最终产物的边界

源审计能够证明：

- 已检入 manifest/plist/pbxproj/Gradle/备份规则符合合同；
- 已锁定依赖和当前解析到的插件元数据没有越界；
- 应用生产源码没有显式联网实现；
- 包名、版本、最低系统版本和方向配置一致。

源审计不能单独证明：

- Gradle manifest merger、代码压缩或未来插件版本不会改变最终包；
- 最终 APK/AAB 的签名证书就是官方证书；
- Apple 签名/描述文件不会在未来 IPA 中加入 entitlement；
- 操作系统、用户选择的分享目标或系统级设备备份永不联网。

因此 Android 构建后必须检查 universal APK 的最终合并清单、精确权限集合、ID/版本/SDK/debuggable、非导出 receiver 和签名证书；AAB 还要做 JAR 签名验证。iOS 未签名构建脚本会复查最终 `.app` 的 ID、版本、最低系统、方向、后台模式与远程通知标记；将来若制作签名 IPA，还必须对归档执行 `codesign -d --entitlements :-`、嵌入描述文件和最终 Privacy Manifest 的独立审计。

## 发布判定

- 源配置门禁：通过后才允许构建。
- Android 安装包：只有最终 APK 检查和签名指纹检查均通过，才可称为官方安装包。
- Android AAB：与已检查 APK 同一锁定源码/构建运行生成，并通过签名验证；若单独重建，需要重新生成 APK 做合并清单对照。
- iOS：当前仅源码与未签名编译证据；不把 `.app.zip` 描述为可安装 IPA，也不声称已完成 App Store/TestFlight 发布审计。
