# 平台、签名与交付架构

> v1.0.0 已作为[公开 Pre-release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.0.0)提供，仍不是稳定版。本页定义产物合同、已取得的自动化证据和仍待完成的实体机门禁。实时状态见 [v1.0.0 发布检查表](../release/v1.0.0-release-checklist.md)。

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

烟测不依赖系统语言的固定文案：它从运行时本地化对象与导航模型取标签，验证事项、过往、笔记、设置四个主区域以及设置内的离线帮助文档都可达。启动和路由等待全部有上限，禁止无界 `pumpAndSettle`；API 24/36 即使一项失败也会各自跑完，未处理 Flutter 异常、矩阵项失败以及不符合下述恢复条件的超时都会使工作流失败，下游 iOS 构建也不会运行。单个矩阵作业最长 90 分钟，模拟器启动最长 600 秒；每次设备测试若未在 12 分钟内完成，则收到终止信号，最多再等待 30 秒后强制结束。只有首轮恰好以超时结束、日志确认 APK 已构建并进入安装阶段但尚无测试执行时，脚本才会先有界重启 ADB，再逐项验证设备启动状态与 Package Manager；恢复后的包列表查询必须成功且为空，以确认应用包当前尚未安装，执行清理后还必须由第二次成功的空列表查询再次确认，才会重试一次。应用已安装、状态未知、构建失败、普通测试失败或第二次失败均不会重试或转成成功。失败时 CI 会额外保存所有已发生的尝试日志（至多两次）、`adb devices`、应用进程、Activity、Package 与 `logcat` 证据，避免无诊断的长时间等待。

模拟器由 [ReactiveCircus/android-emulator-runner v2.38.0](https://github.com/ReactiveCircus/android-emulator-runner/releases/tag/v2.38.0) 启动，工作流锁定其不可变提交 `a421e43855164a8197daf9d8d40fe71c6996bb0d`；Linux KVM 权限设置按该项目的官方建议配置。冷启动通过后，同一矩阵还会写入事项/提醒、笔记/文件夹、过往事件/锚点与非默认设置；seed/verify 设备测试均显式使用 Flutter `--no-uninstall`，避免测试宿主在阶段间删除应用数据；随后执行同签名 `adb install --no-streaming -r -t` 覆盖，启动生产入口并执行正常协调流程，再逐字段核对数据、SQLite `quick_check`/外键、卡片提醒文案、AlarmManager 与真实系统通知栏。Alarm 证据只断言它在 verify 生产启动后存在，不把恢复来源归因于应用协调器或插件的 `MY_PACKAGE_REPLACED` 广播。API 36 由应用自身发起通知权限请求并通过系统 UI 授权，API 24 明确验证无需运行时通知权限。该自动化证明 API 24/36 模拟器上的同版本覆盖与后续生产启动后的系统服务链路，不宣称测试宿主强停状态下无需重启即可送达、不宣称旧 schema 迁移，也不替代代表性实体机的 OEM、锁屏、声音和振动人工验收。

API 33+ 在每个 AVD attempt 的第一次 Flutter 构建、安装或启动之前执行独立的系统组件健康门禁，从而在应用尚未参与时建立纯基础设施归因。门禁先要求 Package Manager 成功且当归包列表为空，再解析系统实际选定的 PermissionController 包；随后对 SystemUI 快速设置面板与 PermissionController 的 `MANAGE_PERMISSIONS` 页面做两次、间隔 5 秒的有界响应采样，并记录 AVD 名、Android build/system image fingerprint、增量版本和 ABI。SystemUI 的每轮观察都会重新发出有界展开请求，避免把刚启动时被忽略的一次请求重复采样为十次失败。该探针本身不安装当归、不授予或撤销 `POST_NOTIFICATIONS`，也不点击任何 ANR 对话框。只有两次采样都能确认对应系统包的真实 UI 后，才运行冷启动烟测；随后的发布验收只严格复核当前 API 与 attempt 的健康证据，不会重跑或修复门禁。API 24 写入明确的 not-applicable 证据，不具备以下 SystemUI 重建资格。

若 API 33+ 在健康门禁中出现明确的有界命令超时，或 UI 层级同时包含系统 `android` 包、`android:id/aerr_close`、`android:id/aerr_wait` 以及 “System UI/Permission Controller 无响应”标题，当前 action 会以专用状态失败关闭。另一个严格限定的基础设施状态是：首轮、产品安装前已证明包不存在，十轮 SystemUI 展开、dump 与读取命令均成功，但始终无法观察到 `com.android.systemui`；它被记录为 `bounded-ui-observation-exhausted`，只允许一次全新 AVD 重跑，不能复用于 PermissionController 或产品阶段。权限流程内的 ANR 还必须同时证明：正在首轮 API 33+ 的通知权限阶段、seed 进程仍存活、seed 前包列表成功且为空、权限策略仍为 pending、CI 尚未点击允许按钮且日志没有产品测试失败标记。普通弹窗缺失、Flutter/数据库/37 项保留断言、AlarmManager 或通知失败都不能生成重建凭据；产品失败与系统 ANR 同时出现时以产品失败为准。

工作流只静态声明两个相同不可变 SHA 的 emulator-runner action：首轮使用 `emulator-5554` 与唯一 attempt-1 AVD；仅当上述结构化凭据、专用退出码和一次性 token 全部一致时，才在 `emulator-5556` 上强制创建唯一 attempt-2 AVD，从冷启动和 fresh-package 边界重跑完整链路。第二轮不忽略失败、不能再次授权重试；最终 `always()` 门禁还会核对根目录 `workflow-phase.json` 的 passed 状态、退出码和 attempt，再恢复 required check 的真实结论。首轮系统证据归档在 artifact 的 `attempt-1/`，根目录始终代表最终一次验收，并含 `retry-decision.json`。这与前述“APK 安装流超时且包仍未安装”时在同一 AVD 内进行的一次 ADB 恢复不同，两种预算互不扩张。

权限 seed pipeline 在独立进程组中运行，GNU `timeout --foreground`、`flutter test` 与 `tee` 保持在同一组；wrapper 以同目录临时文件加原子 rename 记录完整 `PIPESTATUS` 和自然完成状态。发现 ANR 后先留出短暂有界窗口，若自然完成 sidecar、未 rename 的 partial sidecar 或完整日志显示产品失败，则产品失败优先并撤销重试；强制清理后还会复核一次。只有对整个组执行有界 TERM/KILL、确认所有后代消失、leader 退出码与实际发送的终止信号对应、日志在静默窗口内不再增长，且 retry gate 独立复核进程组、终止与静默三份证据后，才保留 fresh-AVD 凭据；无法完整清理宿主进程时会使作业失败，不能依赖 emulator teardown 间接清理。

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

### v1.0.0 预发布证据

版本标签 `v1.0.0` 指向提交 `b6dc50594abdb769080a738dd64550d26bc64d36`。标签工作流 [32609272408](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/32609272408) 的 Android 正式构建、API 24 模拟器、API 36 模拟器和 unsigned iOS 构建四个作业全部成功；Android 作业明确使用 `release` 签名，APK 与 AAB 签名和预期证书指纹一致。公开 Pre-release 共 16 个附件，全部从下载端取回并重新计算 SHA-256 后通过。

API 24/36 验收各完成 37/37 项断言，覆盖事项、提醒、笔记、文件夹、过往、设置六域数据保留、SQLite `quick_check` 与外键完整性、事项卡提醒文案、AlarmManager 注册和真实系统通知。API 36 还观察了真实系统通知权限弹窗、通过系统 UI 授权，并验证最终授权状态。iOS 作业完成 unsigned `.app` 构建与平台配置审计；该压缩包仍不可安装、不是 IPA。

上述证据只支持公开 **Pre-release**。它不证明真实旧 schema 到当前 schema 的迁移，也不替代代表性 Android 实体机上的 OEM 后台策略、锁屏展示、声音、振动及 10/30/60 分钟稍后提醒验收。实体机清单未签署，GitHub Social Preview 也尚未上传，因此不得将 v1.0.0 改称稳定版。

公开 Pre-release 已附加以下 Android 核心文件；真实页面为 [v1.0.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.0.0)：

- `danggui-android-universal-release.apk`
- `danggui-android-armeabi-v7a-release.apk`
- `danggui-android-arm64-v8a-release.apk`
- `danggui-android-x86_64-release.apk`
- `danggui-android-release.aab`
- `SHA256SUMS`
- 公开签名证书或其可复核的 SHA-256 指纹

iOS 的 `danggui-ios-unsigned.app.zip` 可以随构建证据保留，但必须明确标注“不可安装、不是 IPA”；不得与 Android 安装包放在同一下载措辞下误导用户。
