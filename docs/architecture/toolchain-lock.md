# 当归工具链锁定清单

本文档是本地开发与 CI 的唯一工具链基线。升级任何一项都必须单独提交，并通过数据库迁移、通知、Golden、APK/AAB 和 iOS 无签名构建回归。

## 固定版本

| 组件 | 固定值 | 校验或来源 |
|---|---:|---|
| Flutter | 3.47.1 stable | revision `6655482ec06e547f90abf8ae7590466f4415978d` |
| Dart | 3.13.1 | 随 Flutter SDK 提供 |
| Flutter Windows ZIP | `flutter_windows_3.47.1-stable.zip` | SHA-256 `4cbf94fde1f5f8d6b9fc50b2483b57cf2077f61712282c2f4cf92560168f442b` |
| Java | Temurin/JBR 21 | CI 使用 Temurin 21；本地优先 Android Studio 自带 JBR 21 |
| Android Studio | Quail 3, 2026.1.3 Patch 1 (`2026.1.3.8`) | Windows EXE SHA-256 `d08a374ba59a07c7b12b4a1f13f5282fe4d5f548eb8a2e59ba81aa1f8a7b8bc9` |
| Android Gradle Plugin | 9.1.0 | `android/settings.gradle.kts` |
| Gradle Wrapper | 9.3.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin Android plugin | 2.4.0 | `android/settings.gradle.kts` |
| compile / target SDK | 36 / 36 | 显式锁定，禁止回退到 Flutter 动态默认值 |
| min SDK | 24 | Android 7.0 |
| Android Build Tools | 36.0.0 | 本地 SDK 与 CI 均安装此版本 |
| Android NDK | 28.2.13676358 | Flutter 3.47.1 的 `flutter.ndkVersion` |
| CMake | 3.22.1 | 本地 SDK 与 CI |
| desugar JDK libs | 2.1.4 | 本地通知插件要求 |
| iOS deployment target | 15.0 | Xcode project 与 App framework plist 同时锁定 |
| iOS 回退门禁 | `macos-15` / `/Applications/Xcode_16.4.app` / iOS 18.5 Simulator | 不依赖 runner 默认 Xcode；覆盖 iOS 15–25 普通通知路径 |
| iOS AlarmKit 门禁 | `macos-26` / `/Applications/Xcode_26.6.app` / iOS 26.5 Simulator | 不依赖 runner 默认 Xcode；覆盖 iOS 26+ AlarmKit 路径 |
| GitHub checkout action | 7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| GitHub setup-java action | 5.7.0 | `b6effb05e454b25005698d916606bdc6ffcbf961` |
| GitHub upload-artifact action | 7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| GitHub download-artifact action | 8.0.1 | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |
| Flutter setup action | 2.23.0 | `1a449444c387b1966244ae4d4f8c696479add0b2` |
| Android emulator runner action | 2.38.0 | `a421e43855164a8197daf9d8d40fe71c6996bb0d` |

Flutter 官方发布索引：<https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json>。

## Windows 安装约定

- SDK、AVD、缓存与正式构建工作区使用 ASCII、无空格路径，例如 `E:\DevTools\flutter\3.47.1`、`E:\Android\Sdk`、`E:\Android\Avd`、`E:\Work\danggui`。
- 不安装全局 Gradle，所有构建只调用仓库内 Gradle Wrapper。
- 首次在 Windows 上建立 Git 索引后执行 `git update-index --chmod=+x android/gradlew tool/*.sh`；CI 也会先标准化这些执行位。
- 不依赖其他软件附带的 Java；执行 `flutter config --jdk-dir <Android Studio>/jbr` 固定 JBR。
- 安装 `platforms;android-36`、`build-tools;36.0.0`、`platform-tools`、`ndk;28.2.13676358`、`cmake;3.22.1`、Android Emulator 与 Command-line Tools。
- 运行 `flutter doctor --android-licenses`，并在工具链记录中保存 `flutter doctor -v` 和 `sdkmanager --list_installed` 输出。
- Android 模拟器使用 WHPX；启用“Windows 虚拟机监控程序平台”后重启，并以 `emulator -accel-check` 验证。不得新装 HAXM/AEHD。

当源码暂时位于非 ASCII 路径且 Dart analysis server 报文截断时，可以在当前终端临时映射一个未使用的盘符：

```powershell
Push-Location
try {
    subst X: "<repo-path>"
    Set-Location X:\
    flutter analyze --fatal-infos
} finally {
    Pop-Location
    subst X: /d
}
```

映射前必须确认盘符未被占用，命令结束后立即解除；长期方案是将构建工作区放到 ASCII 路径。

## 中国大陆网络

Flutter 与 Pub 可按 Flutter 官方中国网络说明，在当前 shell 使用：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

镜像下载的 Flutter SDK仍须按本页记录的 Google 官方 SHA-256 校验。Android SDK 优先从 Google 官方仓库取得；不要关闭 TLS 校验，也不要导入来源不明的 SDK 压缩包。若 Google Maven 暂时不可达，可将可信镜像作为本地、显式启用的临时仓库，正式 CI 仍使用 `google()` 与 `mavenCentral()`。

## 复现检查

```powershell
flutter --version
dart --version
java -version
flutter doctor -v
sdkmanager --list_installed
android\gradlew.bat --version
```

期待 Flutter 为 3.47.1、Dart 为 3.13.1、Java 主版本为 21、Gradle 为 9.3.1，并且 Android SDK 36/Build Tools 36.0.0/NDK 28.2.13676358 全部存在。
两条 macOS CI 还分别设置 `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`
和 `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer`，并以 `xcodebuild -version`、
`xcrun simctl list runtimes` 及精确创建的 iOS 18.5/26.5 临时 Simulator 记录复现证据。

## 升级流程

1. 在独立分支只修改工具链版本和锁定文档。
2. 清空临时 Gradle/Flutter 构建目录后完整构建。
3. 运行 `flutter analyze --fatal-infos`、全部测试、Android 通用与分架构 APK、AAB、iOS `--no-codesign` 构建。
4. 用 API 24 与 API 36 设备验证数据库、提醒重启恢复、通知权限和升级保留数据。
5. 重新生成并审查依赖锁、许可清单、产物签名与 SHA-256 后方可合并。
