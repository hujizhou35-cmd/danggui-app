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
