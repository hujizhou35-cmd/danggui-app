# iOS 源码包构建说明

`danggui-ios-source-v1.1.2.zip` 是可审计、可复现解包的 Flutter/iOS 源码交付，不是 IPA，也不能直接安装到普通 iPhone。为了让接收者能运行与标签 CI 相同的完整测试和平台审计，压缩包保留全部已跟踪的 Flutter 项目源码（包括 Android 平台源码、`test/` 和 `integration_test/`），但不包含签名证书、描述文件、密钥、构建缓存、`dist` 或用户数据。既有 `danggui-ios-source-v1.1.0.zip` 继续保留在 v1.1.0 Release 中。

## 环境

- macOS 与 Xcode（CI 使用 `macos-26`，实际 Xcode 版本记录在同一发布的 `XCODE.txt`）。
- Flutter `3.47.1` stable 与其自带 Dart。
- iOS 15.0 或更高版本的模拟器/设备；真机安装需要使用者自己的 Apple 签名身份和描述文件。

## 校验与构建

```bash
grep '  ./danggui-ios-source-v1.1.2.zip$' SHA256SUMS | shasum -a 256 -c -
unzip danggui-ios-source-v1.1.2.zip
cd danggui-ios-source-v1.1.2
flutter config --no-analytics --enable-swift-package-manager
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test --concurrency=1
bash tool/build_ios_unsigned.sh
```

`build_ios_unsigned.sh` 会从 `pubspec.yaml` 读取产品版本与构建号，生成 `dist/ios/danggui-ios-unsigned.app.zip` 并复查 Bundle ID、最低系统版本、竖屏限制、后台模式和远程通知 entitlement。该 `.app.zip` 只用于证明源码可构建，仍不是 IPA。

如需在真机运行，请在 Xcode 中打开 `ios/Runner.xcworkspace`，选择自己的 Development Team 后构建。不要把个人证书、描述文件或签名后的产物提交回仓库。
