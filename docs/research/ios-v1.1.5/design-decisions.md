# v1.1.5 设计决策记录

## DD01 — 审计不可变 v1.1.4，而不是共享工作树

- **决定**：所有“当前实现”证据固定到 `2e6e67a2af1239bb56991f85a08c5ff64c00197f`；未提交 v1.1.5 代码只在修复完成后作为新证据登记。
- **理由**：共享工作树有并行修改，直接阅读工作文件会把尚未验证的方案误当成发布能力。
- **未采用**：把工作树最新内容当事实；这会破坏可追溯性。

## DD02 — 不按参考项目重写，按行为合同最小修复

- **决定**：Apple 文档决定平台规则；成熟项目用于验证边界和测试模式。没有证据证明缺陷时不改架构。
- **理由**：当归的离线 Drift + durable outbox + AlarmKit/普通通知组合与候选项目均不相同。
- **未采用**：整体移植 Signal/Joplin/AppFlowy；除架构错配外，AGPL/GPL 也不适合默认复制。

## DD03 — 控制状态严格解码，业务事件无损背压，诊断可有界裁剪

- **决定**：alarm records、transactions、cancellations 使用版本化 envelope、generation 和 checksum；任一元素坏则整代失败并回退严格验证的 `.bak`。未确认的 Stop/Snooze 等业务事件独立保存，最多 4096 条并在满载时拒绝新的有状态动作；纯诊断最多 200 条，可保留有效项并追加匿名 `journal-corrupt`。
- **理由**：控制记录或业务事件缺一项会改变系统行为；诊断少一项只降低可观测性。S01、R02/R03 的恢复模式支持失败关闭。
- **未采用**：所有数组继续 `compactMap`，或用 200 条诊断环形缓冲区承载待确认业务事件；两者都会静默丢失取消墓碑或用户动作。所有诊断也严格失败同样未采用，因为单条坏诊断不应丢失全部历史。

## DD04 — daemon 移除不等同于用户可感知投递；15 分钟内选择可靠性优先

- **决定**：A01 允许从 one-shot 不在 `AlarmManager.alarms` 推断 daemon 已 fire/stop 并移除，但只有明确观察 `.alerting`、Stop/Snooze 或系统动作时才记录用户可感知的 delivered/systemAlert。缺失且未超过 15 分钟进入 `repair-pending` 并保守补登记，超过则 `missed`。
- **理由**：daemon 生命周期事实不能证明用户看见或听见；A03 也不保证普通通知的实际及时投递。本产品在窗口内选择降低漏响概率。
- **权衡**：原 one-shot 若其实已经完整提醒但事件没被 App 观察，保守补登记存在极端重复提醒风险；用 revision/session、单次 repair marker 和 15 分钟上限约束。此为产品可靠性权衡，不表述成 Apple bug。
- **未采用**：沿用 v1.1.4 的 delivered+stopped 过度断言并删除 mirror；也未采用无限重试，以免持续重复提醒。

## DD05 — 15 分钟规则在三层只采样一次时钟

- **决定**：Dart、Swift 与合同测试统一定义 `now - triggerAt > 15 min` 为 expired；边界恰好 15:00 仍在窗口。一次操作只读取一次注入时钟并传递 occurredAt。
- **理由**：避免边界在多次 `Date.now` 之间翻转。现有 RunnerTests 已有一次时钟 sample 的良好模式。
- **未采用**：平台层与 Dart 分别读取当前时间；会产生互相矛盾的 missed/delivered 状态。

## DD06 — 普通通知动作升级为带设备代际的版本化 CAS payload

- **决定**：iOS 15–25 payload v3 增加 task ID、reminder ID、revision、session 和 `deviceGeneration`；Snooze/Stop 用同一 CAS 合同。v2 仅能作用于仍处于 legacy generation 的数据；旧 `task:<id>` payload 只导航，不再修改提醒。
- **理由**：解决 D03，并保持 AlarmKit 与普通通知语义对等。
- **兼容**：旧公开方法名和字段保留一个版本；解析器接受旧 payload，但以安全只读行为降级。
- **未采用**：收到旧 payload 后查当前 reminder 并执行动作；会把陈旧用户动作施加到新提醒。

## DD07 — AlarmKit 替换继续“先新后旧”，容量不足是状态而非删除

- **决定**：先持久化 transaction，schedule/验证新 ID，再退休旧 ID；容量不足保持 `capacity-deferred` 和逻辑提醒/outbox。
- **理由**：A01 的唯一 ID/updates 与 X01 的容量失败说明替换必须可恢复。
- **未采用**：先 cancel 旧 alarm；新 schedule 失败时会形成漏提醒窗口。

## DD08 — 系统快照是派生态，数据库逻辑提醒是权威

- **决定**：系统 ID、mirror 和诊断可重建；它们不能降低数据库中较新的 revision。所有修复经 outbox，`kind:id:revision` 去重。
- **理由**：系统可移除请求，备份/merge 来自另一设备，平台 ID 不可迁移。
- **未采用**：以 pending 系统列表覆盖数据库；会在授权/容量变化时丢用户意图。

## DD09 — 能力等级读取 alert/sound/Time Sensitive 的真实设置

- **决定**：总授权、alert、sound、Time Sensitive、AlarmKit authorization 分开采集；UI 显示“振动由系统控制”，不把 settings deep-link 结果当授权。
- **理由**：A02–A04 把这些状态分开；可 schedule 不代表会有声音。
- **未采用**：只看 `authorizationStatus` 或返回 bool `supported`；信息不足且会虚高。

## DD10 — 保存 IANA zone 与本地组件；旧缩写不猜测

- **决定**：新增可注入 zone provider，未来写 IANA ID、原始 local components 和 UTC。旧 `CST/PDT` 等只标 `legacy-abbreviation`，继续以已存 UTC 投递，用户编辑时升级。
- **理由**：A07 的 `Date`/Calendar/DateComponents 语义和 D04；缩写无法唯一映射 IANA zone。
- **未采用**：维护缩写→IANA 猜测表；全球歧义会静默改变时间。

## DD11 — 备份、恢复和数据库均采用适配层故障注入

- **决定**：为时钟、UUID、文件系统、Keychain、SQLite fault points、通知中心和 AlarmKit 提供内部可测试适配层；不改变公开格式和 MethodChannel 合同。
- **理由**：真实的磁盘满/提交中断不能靠普通 mock happy path 证明；S01–S04、R03 的 crash tests 提供模式。
- **未采用**：在测试中只删除最终文件或抛一个通用异常；覆盖不到写后/提交前等危险窗口。

## DD12 — replace 前验证安全副本，失败优先保留用户数据

- **决定**：外部备份在隔离 staging 完整验证；replace 前对 live DB 建立并验证安全副本；交换失败回滚并保留双方供恢复。未来 schema 明确拒绝。
- **理由**：X03/X04/X14/X16 展示数据库/迁移失败的不可逆代价；A09、S03/S04提供原子替换与验证边界。
- **未采用**：解包后直接覆盖 live DB；任何 CRC、空间或 crash 会毁掉唯一良好副本。

## DD13 — replace 轮换设备代际，merge 总是生成本机 ID

- **决定**：replace 在数据库交换前写入并激活新的随机 `alarmGeneration`，交换前失败则恢复旧代；merge 保持当前设备代际。来源 task/note/reminder 与 platform ID 建立显式 ID map；重复同一备份 merge 由稳定 import identity 幂等；系统提醒只由本机 outbox 重建。
- **理由**：平台 ID 和 system request 是设备态，复用会产生碰撞/陈旧动作。
- **未采用**：原样复制 source platform ID 或 outbox；可能取消/覆盖本机提醒。

## DD14 — 文件保护与 Keychain 可访问性配对

- **决定**：需要首次解锁后后台恢复的 DB/原生控制状态使用显式 `completeUntilFirstUserAuthentication`；设备密钥使用 `AfterFirstUnlockThisDeviceOnly`、不可同步。所有派生态排除 iCloud，属性写入必须验证或记录稳定错误。
- **理由**：A08/A10/A11；D05 和 X11 表明默认继承/锁定行为不能靠猜。
- **验证边界**：Simulator 可真实检查备份排除，但其临时文件系统不保证回读 `NSFileProtectionKey`；文件保护写入通过可注入适配层验证，真实锁屏/重启语义仍为 device-unverified。

## DD15 — 不新增生产依赖作为默认修复

- **决定**：优先使用现有 Drift/sqlite3.dart/cryptography/flutter_secure_storage 和平台 API。只有现有实现无法安全加固、许可证清晰、离线隐私通过且移除成本可控才引入依赖。
- **理由**：本次问题多为状态语义和测试缺口，换库不能自动解决。
- **未采用**：因 GRDB/ZIPFoundation/KeychainAccess 测试好就直接新增；它们当前只作为模式参考。

## DD16 — 诊断真值优先于“看起来完整”

- **决定**：事件只有在有证据时记录；未知投递保持 pending/unknown/error，不伪造 audio/vibration/delivered。最多 200 条，不存用户正文、口令、密钥和完整外部路径。
- **理由**：错误诊断会误导可靠性修复，也可能泄露数据。A14 与 X15支持最小日志原则。
- **未采用**：为保持事件链连续而推测缺失步骤成功。

## DD17 — schema 未变化也先建立迁移夹具

- **决定**：从 v1.1.3/v1.1.4 制品提取真实数据库夹具并锁定；v1.1.5 若改变 schema，先提交升级/中断/未来版本测试再改 schema。
- **理由**：当前 schemaVersion=1 意味着迁移代码没有接受过真实发布数据验证；X06/X16 是反例。
- **未采用**：等 schemaVersion 增加后再补夹具；那时无法确认生成夹具的旧代码仍可复现。

## DD18 — 免费 CI 分成合同、两代 Simulator 和 Android 回归

- **决定**：固定 Flutter 3.47.1/Dart 3.13.1；`macos-15`+Xcode16.4+iOS18.5 测普通通知回退，`macos-26`+Xcode26.6+iOS26.5 测 AlarmKit；失败上传 `.xcresult`。共享层变化同时跑 Android 全回归。
- **理由**：availability 编译不能替代运行时；A12明确 Simulator 与真机边界。
- **未采用**：`macos-latest` 或只跑 unsigned build；版本漂移且不覆盖交互/动作。

## DD19 — Simulator 结论和真机结论严格分开

- **决定**：单元/合同通过写 `contract-proven`；固定 Simulator run 通过才写 `simulator-proven`；声音、震动、静音/专注、隔夜、强杀、重启仍写 `device-unverified`。
- **理由**：A12 和 X18 都说明 Simulator 与真机可能不同。
- **未采用**：把 Simulator 出现通知当“iPhone 可靠性已验证”。

## DD20 — 修复不回写 v1.1.4 标签

- **决定**：所有缺陷修复进入 `codex/v1.1.5-ios-reference-audit`，经失败测试、CI、PR 合入后创建不可变 `v1.1.5`。
- **理由**：保留可复现基线与已发布校验值；远端 Xcode 若发现新问题进入后续补丁，不移动旧标签。

## DD21 — 原生层只接受当前 active device generation

- **决定**：Dart 在任何事件恢复或系统快照对账前先激活数据库中的 canonical UUID generation；Swift/Kotlin 以带主备校验的单值状态作为原生权威。排期、快照、动作、事件、取消和退休均核对 generation；切代先持久化新 active generation，再精确退休旧平台 ID。来自旧代的延迟取消为幂等空操作，绝不降级成“按 reminder ID 取消当前代”。
- **理由**：revision/session 只在单一数据集内唯一；replace 后旧通知、冷启动事件或延迟取消可能与新数据库复用业务 ID。代际门禁把平台派生态绑定到创建它的数据库实例。
- **恢复代价**：Android 在共享层尚无“数据库交换已最终提交”的原生 finalize 握手前保留跨代 LKG records/events，确保 A→B 激活后若 replace 回滚仍可恢复 A；系统 PendingIntent 清理在后续 reconcile 重试。频繁 replace 可能增加应用私有 SharedPreferences 体积，但不得以提前 GC 换取丢失回滚副本或复响风险。
- **未采用**：在 Dart 首次 reconcile 时仅清理可见旧快照；App 启动前的 Receiver/Service/UNNotification action 仍可能复活或修改旧代。

## DD22 — 数据库与平台派生态变更使用同一进程内 FIFO 门禁

- **决定**：backup replace/merge、提醒 reconcile、通知 Snooze/Stop、通知点击和权限结果产生的数据库变更共享 `PlatformMutationGate`。replace 激活新 generation 与数据库交换处于同一门禁区间；门禁释放后才允许新一轮派生态恢复。
- **理由**：单独的 SQLite 事务不能序列化 MethodChannel/文件交换；恢复与前台 reconcile 并发会把旧数据库快照重新登记到新代。
- **未采用**：只在 BackupService 或 NotificationCoordinator 内各自加 mutex；两个互斥锁无法建立跨模块顺序。

## DD23 — 原生事件提交与 ACK 分离，ACK 失败不得阻断修复

- **决定**：原生事件先在 SQLite 事务中按 generation/revision/session compare-and-swap 提交，再刷新共享状态并尝试 ACK。ACK 异常只保留进程内待重试标志，由现有有界 retry timer 重新 drain/ACK；本轮容量计算、系统快照修复和 outbox 排期继续执行。
- **理由**：Stop/Snooze/Missed 在事务提交后已成为权威业务状态；MethodChannel ACK 失败不能撤销该提交，也不能让新 revision 的提醒等待下一次生命周期才登记。重复事件由 revision/session 幂等拒绝。
- **未采用**：ACK 异常直接让 reconcile 失败；这会同时跳过 UI 刷新和同轮派生态修复。立即循环 ACK 也未采用，避免平台持续故障时形成忙循环。

## DD24 — XCUITest 使用独立 Flutter 入口，不在生产入口保留测试路由

- **决定**：生产 `lib/main.dart` 不导入测试 harness；两条代表性 XCUITest 只通过 `lib/xcui_main.dart` 构建。该入口同时要求 Debug 与 allow-list 内的 XCTest launch scenario。CI 由固定 Flutter 生成并校验 `FLUTTER_TARGET`，再以显式 `-configuration Debug` 交给 `xcodebuild`，退出时恢复生成配置；各拒绝原因分别显示，避免超时后仍无法归因。
- **理由**：首轮 iOS 26.5 CI 证明 raw `xcodebuild` 覆盖入口不可靠；第二轮又证明即使日志显示专用入口、Debug 与正确 `DART_DEFINES`，应用内三重合并门禁仍只能给出不可诊断的统一失败。生产入口与 harness 已物理隔离，因此专用入口、Debug 和场景 allow-list 是更直接且可验证的最小可信边界。
- **未采用**：在生产 `main.dart` 中保留 Debug 分支，或继续保留无法独立诊断的编译期布尔门禁；前者仍让破坏性测试代码进入普通构建依赖图，后者增加假失败却不提升发布隔离。

## DD25 — Simulator 文件保护测试验证写入意图，不虚构文件系统回读能力

- **决定**：`DangguiDataProtection.apply` 保留真实 `FileManager.setAttributes` 默认实现，并增加内部可注入写入 seam；RunnerTests 确认根目录、已有子目录和文件均收到 `completeUntilFirstUserAuthentication`，同时真实验证根目录备份排除。写入失败继续映射为稳定 fail-closed 错误。
- **理由**：首轮 iOS 26.5 Simulator 对成功写入的临时文件返回空 `NSFileProtectionKey`，不能据此判定生产策略未执行。A12 已限定 Simulator 不能证明锁屏文件保护语义。
- **未采用**：删除文件保护断言，或把 Simulator 的 `nil` 当生产成功；前者失去调用合同，后者会虚高平台结论。

## DD26 — Android 验收使用当前 Snooze 身份，但不冒充原生按钮点击

- **决定**：连续 10/30/60 分钟验收每轮从当前 reminder/revision 与 device generation 派生 canonical v2/v3 session，调用生产 coordinator 后验证数据库、outbox、registration 与 AlarmManager。证据只记录 payload 版本、是否绑定 generation 和身份匹配布尔值，不记录完整 payload；明确写 `systemUiActionClickClaimed=false` 与 `nativeActionReceiverClickClaimed=false`。
- **理由**：首轮 API 24 验收仍传 v1.1.4 的 `task:<id>`，而 v1.1.5 正确拒绝其修改提醒，造成假失败。fresh-install 设备验收实际覆盖 v2；v3 generation 仍由 restore 合同测试证明。
- **未采用**：重新允许 legacy payload Snooze，或把直接 coordinator 调用描述为原生 Receiver 点击；两者都会破坏陈旧动作防护或夸大证据。

## DD27 — 仅经归因的系统 Launcher ANR 可消耗一次全新 AVD 重试

- **决定**：API 33+ 健康门禁解析默认 HOME component 与只读系统分区 package path；只有 Android ANR 对话框、当前 ANR 焦点包和该 HOME 包完全一致，且当归尚未安装时，才将其归为 `launcher` 基础设施故障并签发 attempt-1 的唯一 fresh-AVD token。Retry gate 独立复核全部证据。
- **理由**：首轮 API 36 的 Permission Manager 已打开，但被系统 Quickstep ANR 遮挡；旧分类器把它误记为不可重试的 Permission Controller 不可见。该故障发生在当归安装前。
- **未采用**：任意 `aerr_close`、任意应用 ANR 或当归自身 ANR都允许重试；这些情况必须直接失败，避免 CI 隐藏产品崩溃。

## DD28 — Simulator 型号由目标 runtime 实际验证，不依赖全局列表顺序

- **决定**：固定 runtime 后，CI 按设备族收集并记录候选 device type，由 `simctl create` 逐项验证兼容性；创建成功的型号才进入两次全新设备 boot 尝试，所有已取得 UDID 的设备均由退出 trap 关闭并删除。
- **理由**：第二轮 iOS 18.5 CI 证明全局 `devicetypes` 第一项可能不兼容目标 runtime，两次只换设备名称的重试会稳定重复 `CoreSimulator.SimError 403`。实际创建是比列表顺序或型号命名更可靠的兼容性判据。
- **未采用**：硬编码某一代 iPhone，或继续对同一未验证型号盲目重试；前者会随固定 Xcode 镜像变化而漂移，后者不能改变失败条件。

## DD29 — CI 子进程回收状态只能消费一次

- **决定**：Android 基础设施自测复用生产代码的 `DANGGUI_SEED_PROCESS_REAPED` 合同；若等待器已回收子进程，后续直接使用已捕获的失败状态，不再次 `wait` 同一 PID。
- **理由**：第二轮 Linux CI 命中了“等待器先回收”分支，旧自测再次 `wait` 得到 127 并静默失败；生产验收脚本已经按该标志避免二次回收。该问题只影响门禁自测，不改变应用行为。
- **未采用**：放宽预期退出码或将 127 当作原测试失败；这会掩盖真正的产品退出状态。

## DD30 — 所有 Android 构建门禁预装同一固定原生工具链

- **决定**：README 真机截图与主 Mobile CI 一样，在进入 Gradle/模拟器前显式安装 `cmake;3.22.1`；离线审计锁定这一合同。
- **理由**：第三轮英文截图任务在 Gradle 隐式安装 CMake 时下载到损坏的非 ZIP，中文并行任务则成功。依赖隐式安装既晚于静态检查，也没有仓库可控的版本门禁；前置安装能让工具链版本和失败位置保持一致。
- **未采用**：把该失败当作偶发网络问题直接重跑，或让 Gradle继续按需安装；两者都会保留不可复现的工具链差异。

## 功能批次门禁

1. 第一批 F01/F03/F04/F15/F17/F19：D01–D04 全部关闭且 iOS 18/26 合同无未解释差异。
2. 第二批 F09/F10/F11/F12/F16/F18/F20/F21：故障注入、旧版夹具和恢复不覆盖良好 DB 全部通过。
3. 第三批 F02/F05/F06/F07/F08/F13/F14/F22/F25：核心工作流模型测试通过。
4. 第四批 F23/F24/F26/F27/F28：体验、a11y、供应链和发布证据完成。

每一批都必须保留 Android 共享层回归；P0 未关闭时不得用 P2 改进替代发布门禁。
