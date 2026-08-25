# iOS 源码包构建说明

`danggui-ios-source-v1.1.3.zip` 是可审计、可复现解包的 Flutter/iOS 源码交付，不是 IPA，也不能直接安装到普通 iPhone。为了让接收者能运行与标签 CI 相同的完整测试和平台审计，压缩包保留全部已跟踪的 Flutter 项目源码（包括 Android 平台源码、`test/` 和 `integration_test/`），但不包含签名证书、描述文件、密钥、构建缓存、`dist` 或用户数据。既有 v1.1.2、v1.1.0 与 v1.0.0 Release 及其历史附件继续保留。

## 环境

- macOS 与带 iOS 26 SDK 的 Xcode（CI 使用 `macos-26`，实际 Xcode 版本记录在同一发布的 `XCODE.txt`）。
- Flutter `3.47.1` stable 与其自带 Dart。
- iOS 15.0 或更高版本的模拟器/设备；iOS 26+ 有声提醒使用 AlarmKit，iOS 15–25 使用 Time Sensitive 本地通知回退。真机安装需要使用者自己的 Apple 签名身份和描述文件。

## 校验与构建

```bash
grep '  ./danggui-ios-source-v1.1.3.zip$' SHA256SUMS | shasum -a 256 -c -
unzip danggui-ios-source-v1.1.3.zip
cd danggui-ios-source-v1.1.3
flutter config --no-analytics --enable-swift-package-manager
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test --concurrency=1
bash tool/build_ios_unsigned.sh
```

`build_ios_unsigned.sh` 会从 `pubspec.yaml` 读取 `1.1.3+4`，生成 `dist/ios/danggui-ios-unsigned.app.zip` 并复查 Bundle ID、最低系统版本、竖屏限制、后台模式和远程通知 entitlement。平台静态审计另会核对 `NSAlarmKitUsageDescription`、AlarmKit 的 iOS 26 可用性保护，以及唯一允许的 `com.apple.developer.usernotifications.time-sensitive` entitlement。该 `.app.zip` 只用于证明源码可构建，仍不是 IPA。

AlarmKit 与 Time Sensitive 授权都由应用在用户明确开启未来提醒或在设置页操作时发起，受保护能力仍必须由用户在系统界面确认；应用不能也不会静默授予权限。项目不申请 Critical Alerts、远程推送或联网后台模式。

如需在真机运行，请在 Xcode 中打开 `ios/Runner.xcworkspace`，选择自己的 Development Team 后构建。不要把个人证书、描述文件或签名后的产物提交回仓库。
