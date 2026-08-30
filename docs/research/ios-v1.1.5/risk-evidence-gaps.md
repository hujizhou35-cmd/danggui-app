# 风险、已证实缺陷与证据缺口

## 判定规则

- **已证实缺陷**：v1.1.4 基线代码存在可构造的违反行为合同路径，不依赖真机猜测。
- **高风险缺口**：设计可能正确，但缺少关键失败处理或自动化证据；先写失败测试再决定是否改代码。
- **设备未验证**：Simulator/单元测试无法覆盖，不据此推断成功或失败。

## 已证实的 P0 缺陷

### D01 部分损坏的原生提醒存储会静默丢失事务/取消墓碑

- 位置：`ios/Runner/ReminderPlatformBridge.swift`，`DangguiAlarmStore.decodeLossyArray`、`loadArrayUnlocked`、`saveArrayUnlocked`。
- 证据：`decodeLossyArray` 将数组解成 `DangguiLossyValue` 后 `compactMap`，任一坏元素被无声丢弃；只要外层 JSON 可解，`loadArrayUnlocked` 就接受部分结果，不读取 `.bak`。之后 `saveArrayUnlocked` 又把这个“可宽松解码”的受损主文件当作有效旧数据写入 `.bak`。
- 影响：损坏的 replacement transaction、cancellation high-water mark 或 alarm record 会消失；可能重新登记已取消提醒、丢失新 revision、产生幽灵闹钟。诊断事件可以宽松保留，但控制状态不能。
- 现有测试反证：`RunnerTests.testCorruptedMirrorEntryDoesNotDiscardValidRecords` 与 `testCorruptedTransactionEntryDoesNotDiscardRecoverableTransaction` 把逐元素保留当成功；`testCorruptPrimaryFallsBackToLastKnownGoodMirror` 只覆盖整个 JSON 不可解，不覆盖“外层合法、控制元素损坏”。
- 最小修复合同：records/transactions/cancellations 使用严格 envelope（schema、generation、完整数组、checksum）；任一元素失败则整代无效并回退严格验证的 `.bak`。events 可继续 lossy，但必须标记 `journal-corrupt`，不能影响控制状态。
- 失败测试：在两条控制记录中只损坏取消墓碑的一个字段，确认整代回退且不会修复已取消 alarm；保存失败时 `.bak` 保持最后已知良好 generation。
- 来源：S01、R02、R03；X03/X05。

### D02 daemon 已移除被过度表述为用户已收到，并放弃保守恢复

- 位置：`ReminderPlatformBridge.swift`，`DangguiAlarmOperationActor.reconcileUnlocked` 约 2096–2109 行。
- 证据：当 mirror record 不在 AlarmKit `remoteByID`，且 `triggerAt <= now` 但尚未超过 15 分钟时，代码直接调用 `recordDeliveredIfNeeded`、追加 `.stopped` 并删除 mirror。A01 的 `AlarmManager.alarms` 说明 one-shot fire/stop 后会从 daemon 删除，因此“缺失”可以推断 daemon 已不再调度、且可能已经 fire；但该分支没有观察 `.alerting`、Stop/Snooze 或其他能证明用户实际看见/听见的事件。
- 影响：App 把 daemon 生命周期事实表述成 `delivered/systemAlert/stopped` 的用户可感知事实，同时失去 15 分钟内的保守恢复机会。这个差异不是 Apple 明示的 AlarmKit bug，而是当归的诊断语义和可靠性取舍。
- 最小修复合同：只有观察到 `.alerting` 或明确用户 Stop/Snooze 时记录 delivered/systemAlert。缺失且未过期时，为“可靠性优先”进入 `repair-pending` 并保守补登记；超过窗口只记 `missed`。诊断记录 `error` reason=`unobserved-daemon-removal`，不能虚构声音/震动。
- 权衡：如果原 one-shot 实际已经完整提醒但 App 未观察到，再补登记可能造成一次极端重复提醒。该风险需在设计记录、测试和 Release 限制中明确；选择它是因为本产品以漏响风险优先，不是 Apple 要求。
- 失败测试：提供空系统快照、触发后 1 分钟、无 alerting/action，断言无 delivered/stopped、mirror/outbox 进入保守重登记；提供已观察 alerting/Stop 的同类场景，断言不重登记；触发后 15:00 与 15:00.001 分别验证边界和重复风险去重。
- 来源：A01（one-shot daemon removal）、A03（系统投递边界）、R01/R02；X01/X02。

### D03 iOS 15–25 的旧通知动作可作用于新 revision

- 位置：`lib/src/services/notifications/notification_coordinator.dart`，普通通知排期 `payload: 'task:<taskId>'`、`handleNotificationAction`、`snoozeReminderForTask`。
- 证据：普通通知只携带 task ID；动作解析后查询该 task 当前 reminder 并直接 Snooze。payload 没有 reminder ID、schedule revision 或 session，无法区分用户点击的是已编辑前的旧通知还是当前通知。
- 影响：旧通知已显示后，用户编辑提醒生成新 revision；随后点击旧通知的 30 分钟 Snooze，代码会推迟新的提醒。与 AlarmKit Stop/Snooze 的 reminder/revision/session CAS 合同不对等。
- 最小修复合同：版本化 payload 至少包含 task/reminder/revision/session；动作事务用这些字段 CAS，旧 payload 只允许安全打开事项，不能改变提醒。旧 v1.1.4 清单入口保留一个版本兼容。
- 失败测试：排期 r7 → 模拟旧通知显示 → 编辑 r8 → 重放 r7 Snooze，断言 r8 未改变、事件记录 stale-action；重复 r8 动作幂等。
- 来源：A06、R01/R02；X18（系统入口陈旧路由的同类失败）。

### D04 `scheduled_zone_id` 并非 IANA 时区

- 位置：`notification_coordinator.dart` 的 Dart/原生 Snooze 路径；`scheduledLocal.timeZoneName` 写入 `scheduled_zone_id`。
- 证据：`DateTime.timeZoneName` 通常是 `CST`、`PDT` 等显示缩写，不是 `Asia/Shanghai`、`America/Los_Angeles` 等 IANA zone identifier。多个地区共享缩写，且缩写不足以确定 DST 规则。
- 影响：架构文档宣称的“本地日期 + IANA zone + UTC”无法成立；备份到另一时区、DST 规则变化或旅行后无法重建用户原意。
- 最小修复合同：通过可注入 time-zone provider 保存 IANA ID；保留 UTC 和原始本地组件。旧缩写数据明确标记 legacy/unknown，并以已保存 UTC 为权威，不能猜地区。
- 失败测试：America/Los_Angeles DST 缺失/重复时刻、Asia/Shanghai 同缩写碰撞、跨区 restore、手动改钟。
- 来源：A07、R01/R02；X02。

### D05 原生镜像/诊断缺少显式文件保护，且属性错误被吞掉

- 位置：`ReminderPlatformBridge.swift` `DangguiAlarmStore.fileURLUnlocked`；`AppDelegate.excludeDangguiDataFromSystemBackups`。
- 证据：目录只设置 `isExcludedFromBackup = true`，未设置 FileProtectionType；`try? setResourceValues` 静默忽略失败。数据库、备份 staging 的 iOS 属性也没有 RunnerTests 证明。
- 影响：文件在锁定状态下的机密性和首次解锁后后台恢复可用性取决于默认继承，不能作为可靠合同；属性失败不可诊断。
- 最小修复合同：集中式文件适配层创建目录/文件，显式设置与 Keychain 一致的 `completeUntilFirstUserAuthentication`（若实测业务需要），校验 `isExcludedFromBackup` 和保护属性；失败返回稳定错误或安全降级。
- 失败测试：临时 sandbox 上读取 URL resource values；模拟属性写失败；旧目录迁移保持唯一良好副本。
- 来源：A08/A10/A11、R02/R04；X11。

## 高风险 P0 证据缺口（尚不等于缺陷）

| ID | 功能 | 基线事实 | 必须补的证据/判定条件 |
|---|---|---|---|
| G01 | F01 生命周期 | `SceneDelegate` 为空；Dart 只在 `resumed` 对账 | 注入 scene/lifecycle provider；冷启动通知动作、scene 重连、significant time change XCUITest。若时间变化不触发对账则升级缺陷 |
| G02 | F04 能力 | `getCapabilities` 只看 authorization + timeSensitive，未读 alert/sound | 组合测试 `authorizationStatus/alertSetting/soundSetting/timeSensitiveSetting`；若 UI 声称可响而 sound disabled，升级缺陷 |
| G03 | F10 备份原子性 | v1.1.5 关闭 live 连接后使用新的 SQLite 连接和 `VACUUM INTO` 生成安全快照；候选、安全副本、journal 与 swap 后 live 均完整验证并显式 flush；真实 busy WAL 与 rename 前后故障测试已覆盖。Dart 无父目录 fsync API | 当前结论仅为 `process-crash-consistent`；磁盘满及真实断电仍需平台/VFS 故障注入，断电语义保持 `power-loss-unverified` |
| G04 | F11 Keychain | 使用 `first_unlock_this_device`、不可同步 | 首次解锁前、锁屏后台、missing/duplicate/OSStatus 错误；实体机前保持 device-unverified |
| G05 | F12 恢复输入 | 读取包体前 stat 限长并流式复核实际长度；ZIP 在解压前限制条目、精确名称、声明大小、symlink/type、压缩方法和 central/local 一致性；hash、完整 integrity/FK、精确生成 schema 签名和准备后语义/计数均覆盖，含恶意 AFTER DELETE trigger、缺列及 `quick_check=ok` 索引损坏夹具；create/replace/merge 共用实例级互斥 | 未来 schema 拒绝已有合同；磁盘满和 archive 库未知解析缺陷仍需持续 fuzz/故障注入。任何输入覆盖良好 DB 即升级缺陷 |
| G06 | F16 DB 损坏恢复 | 普通无 journal 启动也在仓储写入前执行一次完整 integrity/FK；journal 路径的 live/candidate/safety 和恢复后 canonical live 同样完整验证。journal 前候选失败逐项清理，无 journal 启动只按精确 app-owned 名称清孤儿；损坏候选不会覆盖良好 live | 损坏 WAL/SHM、只读/磁盘满仍需平台/VFS 注入。移动损坏 live 与 sidecar 到唯一取证前缀不是单事务；二次进程崩溃可能造成取证 sidecar 分散，这是不影响有效副本选择的已知低风险 |
| G07 | F17 outbox | Dart stale revision/dedupe 测试强；replace 候选在交换前写入新的 `alarmGeneration`，merge 保持当前代际，v1.1.4 回退 `legacy:<dataset_id>`，portable backup 剥离设备标记，journal 前后崩溃恢复测试证明旧/新 live 各自保持对应代际；三端 schedule/Stop/Snooze/Missed/快照/取消均核对当前代际，ACK 失败不阻断同轮新 revision 排期 | 平台调用成功但 app ack 前 crash、容量 deferred 重启、乱序/重复事件仍需持续门禁。Android 为支持 replace 回滚有意保留跨代 LKG records/events；在增加共享层 finalize 握手前，频繁 replace 会增加私有 SharedPreferences，占用增长不得误报为提醒成功或通过提前 GC 牺牲回滚可靠性 |
| G08 | F18 迁移 | schemaVersion 仍为 1，因此尚无升级链 | v1.1.5 任何 schema 改动前加入 v1.1.3/v1.1.4 真实 DB 夹具、未来版本拒绝和逐阶段 crash |
| G09 | F19 channel | Xcode 16.4/iOS 18.5 与 Xcode 26.6/iOS 26.5 各通过 68 RunnerTests + 2 RunnerUITests，actor/availability 两条固定 runtime 已有证据 | malformed 类型/epoch overflow/unknown enum 的更大 fuzz、FlutterResult exactly-once 压力仍需持续扩展；app-process contract double 不证明系统通知投递 |
| G10 | F21 日志 | journal 限 200 且设计不存正文 | 扫描 `NSLog`、Dart logger、异常字符串和证据包；确认路径、正文、口令/密钥不进入日志 |

## P1/P2 证据缺口

- 编辑器：API 24/36 已通过真实指针命中和系统 IME inset，并同时等待祖先与字段内部 ScrollPosition；真实中文/日文 composing、复杂光标/选择、长文自动保存与进程终止仍未覆盖。
- 搜索：replace/merge 已不信任备份投影，并从权威 task/note/past 数据原子重建，覆盖缺失、陈旧与
  重复 merge；四语规范化与删除恢复的更大模型矩阵仍待扩展。
- 过往/anchors：缺 Unicode grapheme 边界和随机 split/merge 状态机。
- 导出：缺磁盘满、分享取消、超长安全文件名、同名碰撞和旧版本字节夹具。
- 导航：两条 RunnerUITests 已覆盖专用 Debug app-process 的事项—提醒—删除恢复与备份—恢复—提醒重建；它们不是通知中心冷启动、production UI 系统入口或后台 scene 的证明。
- UI：快速滚动条与 Snackbar 有 Widget/Golden 证据，但没有 iPad/横屏/键盘/安全区成对矩阵。
- 无障碍：没有 VoiceOver runner、焦点顺序、自定义动作和最大系统 Dynamic Type；44pt 组件测试不能替代。
- 性能：已有大数据 Dart 测试，但没有 iOS 主线程、内存和临时空间阈值。
- 供应链：sqlite Simulator 动态 dylib 已固定 URL、SHA-256 和缓存边界；仍需完整 SBOM、逐依赖隐私用途和持续升级审查。
- 发布：[Mobile CI 33289990719](https://github.com/hujizhou35-cmd/danggui-app/actions/runs/33289990719) 已在 iOS 18.5/26.5 各通过 68 RunnerTests + 2 RunnerUITests，并通过 Android API 24/36；两套 iOS 证据明确 `notification_gateway=in-process-contract-double`、`system_delivery=device-unverified`，不可表述成 AlarmKit/UserNotifications 已真实投递。

## 必须持续标记为 device-unverified

在没有可重复实体 iPhone 记录前，以下项目不得从 Release 已知限制中删除：

- AlarmKit 与普通通知的真实扬声器输出、振动/触感；
- 静音开关、各专注模式、音量为零、蓝牙/耳机路由；
- 锁屏隔夜、低电量模式、存储压力、系统强杀；
- 首次解锁前/后文件与 Keychain 行为；
- 数据库/恢复 journal rename 后、父目录元数据尚未落盘时的突然断电；
- 系统重启后的排期、AlarmKit 容量与通知动作；
- iOS 15–17 运行时（只有 deployment-target/availability 合同不等于运行时验证）。

## 修复优先顺序

1. D01、D02、D03：直接关系幽灵闹钟、漏响和陈旧动作，先写失败测试并最小修复。
2. D04：修复新记录并为旧缩写数据定义无猜测迁移。
3. D05、G02、G09：平台能力、文件保护和 channel 真值。
4. G03–G08：备份/恢复/数据库/迁移故障注入。
5. P1/P2 只在 P0 无未解释差异后推进。
