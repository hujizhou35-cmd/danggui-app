# 功能—来源—基线—差距—测试追踪矩阵

矩阵审计 `2e6e67a2af1239bb56991f85a08c5ff64c00197f`。路径和测试均指 v1.1.4 基线；共享工作树中的未提交 v1.1.5 文件不算现有证据。来源 ID 见 `source-ledger.md`。

| ID / 优先级 | 主要来源 | v1.1.4 当前实现与现有证据 | 已知差距/失败测试目标 | 当前结论 |
|---|---|---|---|---|
| F01 P0 启动/恢复 | A05/A06；R02/R11；X04/X18 | `lib/src/app.dart`、`application/app_store.dart`、`NotificationCoordinator.initialize/reconcile`；Dart 在 resumed 对账，编辑页在 pause/inactive flush；`integration_test/app_cold_start_test.dart` | `SceneDelegate.swift` 为空；没有 significant-time-change 对账、通知动作冷启动和 scene 重连 XCUITest；数据库恢复前置顺序未做 crash 测试 | `contract-proven`（部分）；Simulator pending；device-unverified |
| F02 P1 事项 | R07/R08/R10；X17/X19 | `core_repositories.dart`、`app_store.dart`、tasks pages；`core_repositories_test.dart`、`task_creation_and_reminder_test.dart` | 缺 500–1000 组固定 seed 状态机、排序冲突/旧 revision、事项—过往—提醒—搜索全链测试 | `contract-proven`（常规路径） |
| F03 P0 提醒 | A01/A02/A03/A06；R01/R02；X01/X02 | `notification_coordinator.dart`、`native_alarm_platform.dart`、`ReminderPlatformBridge.swift`；durable outbox、revision/session、两阶段替换、15 分钟规则、60 容量；Dart 通知测试和 17 个 RunnerTests | 原生镜像逐项宽松解码会静默丢事务/墓碑；one-shot 快照缺失被直接表述成用户可感知 delivered/stopped 且不保守补登记；普通通知动作缺 revision/session；缺双 Simulator 与 20 轮循环 | 存在 P0 缺陷；不可宣称完整 contract-proven |
| F04 P0 权限/能力 | A02/A03/A04；R01/R02；X01 | `getCapabilities`、权限请求、settings launcher；设置页/launcher tests | 原生能力未核对 `alertSetting`/`soundSetting`；授权撤销/恢复的实时 UI 与系统快照测试不足；不能验证真实声音 | `contract-proven`（请求流）；能力真实性有缺口 |
| F05 P1 过往 | R07/R09/R10；X19 | `past_page.dart`、repository/app_store 文档 edit/anchor/part 路径；`app_store_document_edit_test.dart`、bulk edit tests | 缺 anchors/parts 模型化 split/merge、组合字符定位、故障中断与导出/恢复往返 | `contract-proven`（常规路径） |
| F06 P1 笔记/文件夹 | R07/R08/R10；X17 | `notes_page.dart`、`note_editor_page.dart`、repositories；文档和 editor tests | 文件夹删除与未完成 autosave 并发、批量移动失败、笔记转事项全链、恢复索引缺系统测试 | `contract-proven`（基本 CRUD） |
| F07 P1 编辑器 | A05；R07/R08/R10；X13/X19 | 编辑页、`EditorSaveFeedback`、app store revision；`editor_autosave/interactions/layout_test.dart` | 缺真实 IME composing/cursor、进程终止、自动保存与备份/导出交错、长文内存测试 | `contract-proven`（逻辑）；UI/进程边界 pending |
| F08 P1 搜索 | R07/R08/R09 | DB search records、app store/repository refresh；core repository tests | 缺中英日俄规范化合同、删除/恢复/导入后的全量重建、索引损坏与随机模型测试 | 证据不足 |
| F09 P0 最近删除 | A09；R02/R07；X15/X19 | `trash_service.dart` 事务处理、恢复提醒 revision/outbox、搜索重建；`recently_deleted_service/page_test.dart` | 缺清理/恢复/永久删除每阶段 crash、并发幂等和恢复后原生提醒对账 | `contract-proven`（常规路径）；故障注入 pending |
| F10 P0 备份 | A08/A09/A11、S02/S03；R02/R03；X03/X08 | `backup_service.dart` WAL checkpoint、一致性临时 DB、manifest/哈希、安全副本；backup tests、automatic backup tests | 没有每个 I/O 阶段、fsync/atomic replace、磁盘满/分享取消、iOS 文件保护与临时明文扫描；尚无真实旧版大库 | `contract-proven`（格式/常规往返）；耐故障不足 |
| F11 P0 加密/Keychain | A10/S05；R04/R06；X10/X11/X12 | `backup_codec.dart` Argon2id + AES-GCM、随机 salt/nonce；`flutter_secure_storage` 配置 `first_unlock_this_device`、不可同步；codec tests | 缺首次解锁前、设备锁定、Keychain 缺项/迁移、口令内存寿命和明文 staging 扫描；真机锁定行为未验证 | 加密格式 `contract-proven`；Keychain device-unverified |
| F12 P0 恢复 | A08/A09、S03/S04；R02/R05；X03/X09/X16 | `backup_service.dart` inspect、ZIP whitelist/哈希/schema/quick check、replace 安全副本、merge 新 ID、剥离设备态并重建 outbox；backup tests | 缺符号链接/路径穿越完整语料、swap 每边界中断、完整 `integrity_check`、未来/旧 schema 真实夹具、磁盘满后回滚与旧系统提醒退休测试 | `contract-proven`（正常与部分恶意输入）；P0 故障缺口 |
| F13 P1 导出 | A09；R05/R07/R09；X09 | `portable_export_service.dart/models.dart` 路径净化、稳定排序、ZIP/Markdown/JSON verifier；export tests | 缺分享取消、磁盘满、超长/组合字符、同名冲突和跨版本逐字节夹具 | `contract-proven`（常规路径） |
| F14 P1 设置 | R07/R09/R10 | `settings_page.dart`、settings table/repository、设置测试 | 缺并发 rowVersion 冲突 UX、默认提醒对既有事项的不变性、四语系统设置动作测试 | `contract-proven`（基本持久化） |
| F15 P0 时间 | A07；R01/R02；X02 | UTC、本地时间和 `scheduled_zone_id` 字段；15 分钟窗口测试、snooze 固定时钟测试 | 实际写 `DateTime.timeZoneName` 缩写而非 IANA；缺 DST 缺失/重复时刻、手动改时钟、跨时区 restore；没有 significant-time-change hook | 已证实语义缺陷；不可 contract-proven |
| F16 P0 数据库 | A09、S01/S02/S04；R02/R03；X03/X05/X07 | Drift 22 表、外键/唯一约束、WAL、事务；`database_provider.dart` 启动 `quick_check`；repository/backup tests | 基线 quick_check 失败只重试，无最后已知良好恢复；缺 disk-full/VFS fault、WAL/SHM 损坏、完整 integrity check 和提交四边界 | `contract-proven`（事务结构）；恢复性不足 |
| F17 P0 outbox/派生态 | A01/A03/A06；R01/R02；X01/X05 | `platform_jobs`、dedupe、stale revision、64 批处理、系统快照对账；notification coordinator tests | 原生 mirror 的 partial decode/backup 语义会丢 tombstone；平台成功—ack 之间故障覆盖不足；容量 deferred 跨重启未跑 Simulator | `contract-proven`（Dart outbox）；原生持久化存在 P0 缺陷 |
| F18 P0 迁移 | A09、S01/S04；R02/R03；X04/X06/X16 | `DangguiDatabase.schemaVersion == 1`；备份只接受 schema 1；无已发布 schema 升级链 | 缺旧版数据库夹具、未来版本显式拒绝的启动测试、迁移中断/重复执行矩阵；版本首次变化前必须补 | 尚无迁移证据；P0 发布门禁 |
| F19 P0 Flutter/Swift | A01/A02/A03/A06；R01/R02；X01/X18 | `MethodChannelNativeAlarmPlatform` 与 `ReminderPlatformBridge`；actor、字段别名、revision/session、稳定错误；RunnerTests | 普通路径与 AlarmKit 动作合同不对等；缺 bad-type/overflow fuzz、FlutterResult once、并发 actor/availability 双 runtime 实跑 | `contract-proven`（部分）；P0 不对等 |
| F20 P0 iOS 文件 | A08/A09/A10/A11；R02/R04；X09/X11 | `AppDelegate.excludeDangguiDataFromSystemBackups`、Alarm store `.isExcludedFromBackup`、Application Support/临时 staging | 原生镜像/诊断/DB 未明确 `FileProtectionType`；属性失败通常静默；旧路径迁移的属性/原子性测试不足 | 备份排除 contract-proven；保护属性缺口 |
| F21 P0 隐私/诊断 | A01/A13/A14；R02/R11；X15 | 原生 journal 最多 200 条，事件不存事项正文；`privacy_platform_config_test.dart` | “系统 one-shot 已从 daemon 移除”分支直接断言用户可感知 delivered/stopped；缺 platform error、路径、口令/密钥静态/动态扫描和证据包审计 | 隐私边界部分 contract-proven；诊断真实性有 P0 缺陷 |
| F22 P1 导航/系统入口 | A06；R02/R11；X18 | GoRouter/app shell、notification action handler；cold-start 基本 test | 缺已删除目标安全降级、动作重放、通知冷启动/scene resume XCUITest | 证据不足 |
| F23 P2 UI 基础 | R07/R08/R10 | `fast_scrollbar.dart`、`snack_bar_feedback.dart`、IME guard、frame；fast scrollbar/snackbar/golden tests | 缺横竖屏、iPad 分屏、安全区/键盘成对矩阵和真实拖动可达性 | `contract-proven`（Widget） |
| F24 P2 无障碍/四语 | A12；R08/R11 | 主题/组件约束、四语文案、320px/高 textScale 部分测试、Goldens | 缺 VoiceOver runner、焦点顺序、自定义动作、系统最大 Dynamic Type、iPad/横屏、四语日期/复数截图 | 证据不足；device-unverified |
| F25 P1 性能 | R07/R08/R09；X13 | `large_dataset_reliability_test.dart`、`nonempty_merge_performance_test.dart` | 缺 iOS 启动/主线程/内存/临时空间指标；无阈值和 Instruments 证据；长文 IME 未覆盖 | 合同测试部分；平台性能 pending |
| F26 P2 供应链 | A13；C01/C02；R12 | `pubspec.lock`、Podfile.lock、隐私审计、发布脚本 SHA | 动态 sqlite Simulator dylib 获取链需固定 URL/SHA/离线缓存；缺完整 SBOM、逐依赖许可证/隐私用途与升级策略 | 部分 contract-proven |
| F27 P2 帮助/关于 | A04/A12 | help/settings pages、四语 help 文档与 tests | 缺真实版本元数据锁定、当前真机未验证边界一致性、能力变化后的帮助文案回归 | `contract-proven`（静态文案） |
| F28 P2 发布 | A12；C01/C02/C03；R03/R11 | Android 发布验收、源包/证据/SHA 流程已有 v1.1.4 基础 | v1.1.5 尚未跑固定 macOS-15/Xcode16.4+iOS18.5 与 macOS-26/Xcode26.6+iOS26.5；无两条 XCUITest/xcresult；无真机 | 全部 pending；device-unverified |

## 基线测试清单与缺口解释

现有证据主要集中在：

- `test/services/notifications/notification_coordinator_test.dart`、`native_alarm_platform_test.dart`、`ios/RunnerTests/RunnerTests.swift`；
- `test/services/backup/backup_service_test.dart`、`backup_codec_test.dart`、`automatic_backup_coordinator_test.dart`；
- repository、trash、editor、export、stress、Widget/Golden tests；
- Android 冷启动和发布验收 integration tests。

基线没有 iOS XCUITest target，也没有 F01/F03/F12 两条计划中的端到端场景。因此 RunnerTests 编译通过只能证明 Swift 合同，不等于系统通知、场景路由或真实硬件行为。

## v1.1.5 更新规则

修复进入工作树后，在相应行增加：失败测试名、修复提交、CI run URL 和结论提升。没有 CI run URL 不得写 `simulator-proven`；没有可重复实体 iPhone 记录不得移除 `device-unverified`。

## v1.1.5 实施追踪（PR 与 CI 证据）

本表是上方不可变 v1.1.4 基线判断的增量，不改写基线事实。核心实现为 `d261c0c`，固定运行时/供应链为 `3d355fc`，发布文案为 `a06205a`，编辑器真实指针稳定化为 `a8fb35b`、`8353465`，API 24 安装传输门禁为 `ef1300b`；研究台账起点为 `ffdb5de`。实现 PR 的 [Mobile CI 33289990719](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/33289990719) 通过 433 项离线审计、348 项 Flutter 测试、Android API 24/36、unsigned iOS build，以及两套各 68 项 RunnerTests + 2 项 RunnerUITests；[截图 run 33289990716](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/33289990716) 的中英文作业也通过。iOS 两套 UI 场景均明确使用 app-process contract double，不能提升为系统通知实际投递证明。

| ID | v1.1.5 实施/失败路径证据 | 提交 | 当前结论 / CI |
|---|---|---|---|
| F01 | `xcui_scenario_harness_test`、两条 `RunnerUITests` 场景、启动依赖失败后重建、通知冷启动安全降级 | `d261c0c` | app-process 生命周期合同在 iOS 18.5/26.5 `simulator-proven`；真实通知冷启动仍 device-unverified |
| F02 | optimistic-lock 双写冲突、640 步固定 seed 事项/笔记影子模型、删除恢复跨链 | `d261c0c` | contract-proven；Android API 24/36 回归通过 |
| F03 | 损坏镜像 LKG、generation/revision/session、A→B→A、4096 满队列终态、Stop/Snooze/Missed/15 分钟/60 容量 | `d261c0c` | Dart/Kotlin/Swift 与双 Simulator app-process 合同通过；系统提醒实际投递 device-unverified |
| F04 | alert/sound/time-sensitive 能力组合、权限撤销/恢复、两条权限写库等待共享 gate | `d261c0c` | contract-proven；系统 UI/真机仍 device-unverified |
| F05 | anchored block split/merge/reorder、批量 3600 块编辑和固定模型交错 | `d261c0c` | contract-proven；真实 IME pending |
| F06 | 笔记 rowVersion CAS、自动保存串行、搜索重建、固定模型删除/恢复 | `d261c0c` | contract-proven |
| F07 | task/note/Past 自动保存重入、失败重试、返回/后台 flush、外部 revision 冲突；同时观察祖先和字段内部 ScrollPosition | `d261c0c`, `a8fb35b`, `8353465` | API 24/36 单次真实指针与系统 IME inset 通过；中文/日文 composing、真实进程终止仍 device-unverified |
| F08 | replace/merge 丢弃来源索引并由权威数据重建，模型测试持续核对查询结果 | `d261c0c` | contract-proven；更大四语规范化矩阵 pending |
| F09 | 损坏 trash context 拒绝、30 天边界、恢复/永久删除及未来提醒重建 | `d261c0c` | contract-proven |
| F10 | `VACUUM INTO` 一致性快照、候选/安全副本/journal 校验、busy WAL 与各交换 fault point | `d261c0c` | process-crash-consistent；power-loss-unverified |
| F11 | Argon2id/AES-GCM 往返、错误口令、密文/认证标签篡改、随机 salt/nonce、临时明文清理 | `d261c0c` | crypto contract-proven；锁屏 Keychain device-unverified |
| F12 | ZIP bomb/symlink/重复名/central-local/CRC/hash/schema/integrity 拒绝，replace/merge 幂等和 generation 回滚 | `d261c0c` | contract-proven；真实磁盘满/power loss pending |
| F13 | 稳定 Markdown/JSON/ZIP、大小上限、同名保留、分享成功/取消/异常清理 | `d261c0c` | contract-proven |
| F14 | settings rowVersion CAS、四语、默认提醒和备份状态真值 | `d261c0c` | contract-proven |
| F15 | canonical IANA provider、DST 缺失/重复时刻、Snooze/重启/UTC fallback | `d261c0c` | contract-proven；手动系统改钟 Simulator pending |
| F16 | WAL/FULL/foreign keys、完整 integrity、未来 schema 拒绝、live/candidate/safety LKG 恢复 | `d261c0c` | contract-proven；VFS 磁盘满/power loss pending |
| F17 | business outbox 与 200 条诊断分离；ACK 一次失败仍同轮排期并由 timer 幂等重放 | `d261c0c` | Dart/Kotlin/Swift 合同及双固定 Simulator 通过；平台实际投递仍 device-unverified |
| F18 | schema 仍为 1；未来版本启动/恢复显式拒绝，v1.1.4 设备 generation 使用稳定 legacy 路径 | `d261c0c` | 当前无 schema migration；升级前夹具门禁保留 |
| F19 | MethodChannel generation/别名/坏事件可 ACK、actor 串行、严格错误和 RunnerTests 扩展 | `d261c0c` | Xcode 16.4/iOS 18.5 与 Xcode 26.6/iOS 26.5 各 68 RunnerTests + 2 RunnerUITests 通过 |
| F20 | `DangguiDataProtection` 显式 backup exclusion + first-unlock protection，失败返回稳定 unavailable | `d261c0c` | contract-proven；首次解锁/锁屏 device-unverified |
| F21 | PR CI 433 项、当前本地 438 项源码隐私/平台审计及主动破坏 fail-closed 测试；4096 业务事件不含正文，诊断 200 条 | `d261c0c`, `3d355fc`, `ef1300b` | contract-proven；正式标签证据包仍待发布 |
| F22 | v3 通知身份、旧 payload 仅导航、目标删除回退列表、重复/陈旧动作幂等 | `d261c0c` | 两条专用 Debug app-process XCUITest 通过；通知中心/生产系统入口仍 device-unverified |
| F23 | fast scrollbar、bounded Snackbar、键盘 inset、Golden 回归纳入 348 项全量测试；真实编辑字段命中路径覆盖 API 24/36 | `d261c0c`, `a8fb35b`, `8353465` | Widget/Golden 与 Android 模拟器交互通过 |
| F24 | 系统 text scale 不再截断至 2 倍，最小触控、四语窄屏/语义回归 | `d261c0c` | contract-proven；VoiceOver/iPad 深矩阵 pending |
| F25 | 2000 tasks/1000 notes/3600 Past、导出/备份/恢复指标及 1000→500 merge | `d261c0c` | Dart stress contract-proven；Instruments pending |
| F26 | sqlite iOS dylib 固定 URL/SHA/缓存、依赖/许可证/离线边界、固定 action commits | `3d355fc` | 两套固定 macOS/Xcode runner 在本次 PR CI 均通过；完整 SBOM/持续升级审查保留 |
| F27 | `1.1.5+6`、四语设置/帮助/已知限制和权限真值测试 | `d261c0c`, `a06205a` | contract-proven |
| F28 | 固定 `macos-15`/16.4/18.5 与 `macos-26`/26.6/26.5；Android API 24 使用 5 次受审计非流式安装，API 36 保持原生透传；APK/源码/证据/SHA 下载复核 | `3d355fc`, `a06205a`, `ef1300b` | PR CI 全绿；保护标签、正式签名与公开附件待发布，device-unverified 保留 |

保护标签发布后再把正式签名、附件哈希和公开 Release 事实写入发布检查表；不得用本节的 PR `debug-fallback` 测试签名代替正式签名证据。
