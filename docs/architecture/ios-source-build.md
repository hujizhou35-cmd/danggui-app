# iOS 源码包构建说明

`danggui-ios-source-v1.1.5.zip` 是可审计、可复现解包的 Flutter/iOS 源码交付，不是 IPA，也不能直接安装到普通 iPhone。为了让接收者能运行与标签 CI 相同的完整测试和平台审计，压缩包保留全部已跟踪的 Flutter 项目源码（包括 Android 平台源码、`test/`、`integration_test/` 与 `RunnerUITests`），但不包含签名证书、描述文件、密钥、构建缓存、`dist` 或用户数据。v1.1.4 及更早 Release、标签和历史附件继续保留。

## 环境

- 回退门禁固定标准 `macos-15`、Xcode 16.4、iOS 18.5；AlarmKit 门禁固定标准 `macos-26`、Xcode 26.6、iOS 26.5。实际版本记录在同一发布的证据文件中。
- Flutter `3.47.1` stable 与其自带 Dart。
- iOS 15.0 或更高版本的模拟器/设备；iOS 26+ 有声提醒使用 AlarmKit，iOS 15–25 使用 Time Sensitive 本地通知回退。真机安装需要使用者自己的 Apple 签名身份和描述文件。

## 校验与构建

```bash
grep '  danggui-ios-source-v1.1.5.zip$' SHA256SUMS | shasum -a 256 -c -
unzip danggui-ios-source-v1.1.5.zip
cd danggui-ios-source-v1.1.5
flutter config --no-analytics --enable-swift-package-manager
flutter pub get --enforce-lockfile
bash tool/prefetch_sqlite_ios.sh
flutter analyze --fatal-infos
flutter test --concurrency=1
bash tool/build_ios_unsigned.sh
```

`prefetch_sqlite_ios.sh` 只下载锁定版本的 macOS/iOS 原生 SQLite 文件，并逐个校验仓库固定的 SHA-256。`build_ios_unsigned.sh` 从 `pubspec.yaml` 读取 `1.1.5+6`，生成 `dist/ios/danggui-ios-unsigned.app.zip` 并复查 Bundle ID、最低系统版本、竖屏限制、后台模式和远程通知 entitlement。平台静态审计另会核对 `NSAlarmKitUsageDescription`、AlarmKit 的 iOS 26 可用性保护、受保护文件策略，以及唯一允许的 `com.apple.developer.usernotifications.time-sensitive` entitlement。该 `.app.zip` 只用于证明源码可构建，仍不是 IPA。

标签 CI 还会通过 `tool/run_ios_simulator_tests.sh` 在上述两个固定运行时执行 RunnerTests 和两条 RunnerUITests；这些结果只能标记为 `simulator-proven`，不能替代实体 iPhone 的声音、触感、静音/专注、隔夜或进程终止验收。

AlarmKit 与 Time Sensitive 授权都由应用在用户明确开启未来提醒或在设置页操作时发起，受保护能力仍必须由用户在系统界面确认；应用不能也不会静默授予权限。项目不申请 Critical Alerts、远程推送或联网后台模式。

如需在真机运行，请在 Xcode 中打开 `ios/Runner.xcworkspace`，选择自己的 Development Team 后构建。不要把个人证书、描述文件或签名后的产物提交回仓库。
