# 平台、签名与交付架构

> v1.0.0 当前处于首发准备状态。本页定义产物合同和硬性门禁，不代表 GitHub Release 已经存在。实时状态见 [v1.0.0 发布检查表](../release/v1.0.0-release-checklist.md)。

## 平台不变量

- Android application ID、namespace 与 Kotlin 包均为 `com.danggui.memo`。
- iOS Bundle ID 为 `com.danggui.memo`，测试 Bundle ID 为 `com.danggui.memo.RunnerTests`。
- Android 最低 API 24，compile/target API 36；iOS 最低版本 15，仅支持手机竖屏。
- 所有 Android 变体都不声明 `android.permission.INTERNET`；CI 会解析最终 APK 并阻止包含 INTERNET 的产物。
- 应用禁用 Android 系统云备份与设备迁移，避免本地数据库被系统服务上传；跨设备迁移只走应用内、用户主动选择的 `.dgbak` 流程。
- 不申请 `SCHEDULE_EXACT_ALARM` 或 `USE_EXACT_ALARM`。业务层必须使用非精确本地提醒模式，并向用户说明 OEM 省电策略可能造成延迟。

## 本地通知平台配置

Android 主清单只包含：

- `POST_NOTIFICATIONS`：Android 13+ 由用户操作触发运行时授权。
- `VIBRATE`：遵循用户与通知频道设置。
- `RECEIVE_BOOT_COMPLETED`：设备重启或应用更新后由插件恢复仍有效的计划提醒。
- `ScheduledNotificationReceiver`、`ScheduledNotificationBootReceiver` 和 `ActionBroadcastReceiver`，全部 `exported=false`。

Android 启用 core library desugaring，并保留 `ic_stat_danggui` 通知小图标。Dart 初始化必须使用 `AndroidInitializationSettings('ic_stat_danggui')`；通知频道一旦创建，声音和振动属性由 Android 固化，修改默认值时必须使用新的频道版本 ID。

iOS 的 `AppDelegate` 将 `UNUserNotificationCenter` delegate 指向 Flutter AppDelegate，并为通知动作的后台 isolate 注册插件。通知授权仍只能在用户明确开启提醒时由 Dart 请求，不得在首次启动时突兀弹窗。

## Android 签名决策

Gradle 按以下优先级读取签名：

1. 环境变量 `DANGGUI_KEYSTORE_PATH`、`DANGGUI_KEYSTORE_PASSWORD`、`DANGGUI_KEY_ALIAS`、`DANGGUI_KEY_PASSWORD`。
2. 未设置环境变量时读取被 Git 忽略的 `android/keystore.properties`。
3. 两者均完全缺失时，release 构建明确回退到 debug key，仅供测试。

任一来源只配置部分字段会立即失败；指定的 keystore 不存在也会失败。构建日志和产物目录只记录 `release` 或 `debug-fallback`，不输出密码。

创建正式密钥：

```powershell
$env:DANGGUI_KEYSTORE_PASSWORD = "<strong-secret>"
$env:DANGGUI_KEY_PASSWORD = "<strong-secret>"
.\tool\generate_android_keystore.ps1 -OutputPath "<external-secure-path>\danggui-release.jks"
```

脚本拒绝把正式密钥放入仓库，并导出可公开保存的证书。密钥、两个密码和恢复副本必须分别离线保管；丢失正式密钥将无法为同一 application ID 发布兼容升级。

本地正式构建可设置四个环境变量，也可从 `android/keystore.properties.example` 创建本机私密配置，然后运行：

```powershell
.\tool\build_android_release.ps1
```

产物验证包括 APK 签名、AAB JAR 签名、最终权限和 SHA-256。正式发布时还应设置 `DANGGUI_EXPECTED_CERT_SHA256`，防止误用其他证书。

## GitHub Actions 签名环境

正式签名材料只保存在受保护的 `android-release` Environment；仓库级
Secrets 与 `ci` Environment 均保持为空。`android-release` 使用以下名称：

| Secret | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 正式 JKS 文件的单行 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 默认 `danggui` |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_EXPECTED_CERT_SHA256` | 正式标签必须配置的证书 SHA-256 |

`android-linux` 作业根据 ref 选择环境：所有 PR（包括同仓库分支）、`main`
推送和手动验证都只能进入无 Secrets 的 `ci`，必须生成名称带
`debug-fallback` 的测试产物；只有 `v*` 标签可进入 `android-release`。脚本
还会断言 PR 实际收到的签名字段数量必须为零，形成第二道失败关闭门禁。非
标签事件不会取得正式材料；标签中四项签名字段全部存在时生成正式签名
APK/AAB，部分或全部缺失都会被版本标签门禁拒绝。维护者不得把这些值重新
配置为仓库级 Secrets，否则任意同仓库 PR 都会重新获得读取长期签名材料的
能力。

`android-release` 的部署策略只允许 `v*` tag；版本标签还必须同时取得四项正式签名字段和
`ANDROID_EXPECTED_CERT_SHA256`，否则 CI 立即失败，不允许在版本标签上产出
debug 回退包。仓库另以服务端 tag ruleset 限制 `v*` 的创建、更新和删除，
唯一永久绕过者为仓库 owner；普通写入角色不能绕过受保护主分支直接触发签名
环境。`main` 自身要求经 PR 合并、严格状态检查、会话解决，且管理员同样受
保护规则约束。

CI 产出：

- 通用 APK。
- `armeabi-v7a`、`arm64-v8a`、`x86_64` 分架构 APK。
- AAB。
- `SHA256SUMS`、`SIGNING_MODE.txt` 和 `TOOLCHAIN.txt`。
- macOS 上的 unsigned `Runner.app` 压缩包，仅作为 iOS 源码可构建证据，不是 IPA，不能安装到普通 iPhone。

CI Artifact 只用于构建审计和维护者验收，不自动等同于公开正式包。只有从版本标签构建、满足下述全部门禁，并由维护者附加到本仓库 GitHub Release 的 `release` 产物，才可称为官方安装包。普通用户应优先选择 `danggui-android-universal-release.apk`；ABI 分包面向明确知道设备架构的用户，AAB 不应直接侧载。

## Android 模拟器冷启动门禁

`android-emulator-smoke` 在独立的 `ubuntu-24.04` 作业中使用 Flutter `3.47.1`，并以 API 24/36、x86_64 组成两项矩阵。每项从全新 CI 环境启动 Android Emulator，调用生产 `main()`，因而会经过真实数据库、插件注册、启动协调与路由过程，而不是只 `pumpWidget` 一个隔离页面。Flutter 的设备测试宿主需要通过设备本机 VM Service 建立调试连接，因此该作业只在一次性的 CI checkout 中临时为 Debug 清单加入 `INTERNET`，不提交该清单、不参与 Release 构建；仓库内 main/debug/profile 清单和最终受审计 APK 仍全部不含网络权限。

烟测不依赖系统语言的固定文案：它从运行时本地化对象与导航模型取标签，验证事项、过往、笔记、设置四个主区域以及设置内的离线帮助文档都可达。启动和路由等待全部有上限，禁止无界 `pumpAndSettle`；API 24/36 即使一项失败也会各自跑完，任一超时、未处理 Flutter 异常或矩阵项失败都会使工作流失败，下游 iOS 构建也不会运行。单个矩阵作业最长 45 分钟，模拟器启动最长 600 秒，烟测命令本身最长 25 分钟；任一超时都以非零状态失败。失败时 CI 会额外保存 `adb devices`、应用进程、Activity、Package 与 `logcat` 证据，避免无诊断的长时间等待。

模拟器由 [ReactiveCircus/android-emulator-runner v2.38.0](https://github.com/ReactiveCircus/android-emulator-runner/releases/tag/v2.38.0) 启动，工作流锁定其不可变提交 `a421e43855164a8197daf9d8d40fe71c6996bb0d`；Linux KVM 权限设置按该项目的官方建议配置。该烟测是真实应用启动门禁，但不替代发布检查表中的覆盖升级、系统通知 UI 与数据保留人工验收。

## iOS 后续签名边界

当前不购买 Apple Developer Program，不保存 `.p8`、`.p12` 或 provisioning profile，也不上传 TestFlight。将来启用发布时，在不修改业务代码的前提下增加独立、人工审批的签名工作流；签名前重新确认 Bundle ID、证书主体、隐私清单、加密出口声明和中国大陆合规要求。

## 发布门禁

任何可对外称为“正式 Android 包”的产物必须同时满足：

1. `SIGNING_MODE.txt` 为 `release`。
2. `apksigner verify --verbose --print-certs` 通过，证书 SHA-256 与公开指纹一致。
3. AAB 的 JAR 签名通过。
4. 最终 APK 不含 INTERNET 或精确闹钟权限。
5. `flutter analyze --fatal-infos`、全部测试与 API 24/API 36 真实模拟器冷启动烟测通过。
6. API 24/API 36 安装升级、提醒和数据保留验收通过。
7. SHA-256 与 Release 页面一致。

Debug 回退包必须保留 `debug-fallback` 文件名，禁止上传应用商店或标记为正式 Release。

发布时至少附加以下文件；实际 Release URL 只能在页面成功创建后写入文档：

- `danggui-android-universal-release.apk`
- `danggui-android-armeabi-v7a-release.apk`
- `danggui-android-arm64-v8a-release.apk`
- `danggui-android-x86_64-release.apk`
- `danggui-android-release.aab`
- `SHA256SUMS`
- 公开签名证书或其可复核的 SHA-256 指纹

iOS 的 `danggui-ios-unsigned.app.zip` 可以随构建证据保留，但必须明确标注“不可安装、不是 IPA”；不得与 Android 安装包放在同一下载措辞下误导用户。
