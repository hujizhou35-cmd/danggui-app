# v1.1.5 设计决策记录

## DD01 — 审计不可变 v1.1.4，而不是共享工作树

- **决定**：所有“当前实现”证据固定到 `2e6e67a2af1239bb56991f85a08c5ff64c00197f`；未提交 v1.1.5 代码只在修复完成后作为新证据登记。
- **理由**：共享工作树有并行修改，直接阅读工作文件会把尚未验证的方案误当成发布能力。
- **未采用**：把工作树最新内容当事实；这会破坏可追溯性。

## DD02 — 不按参考项目重写，按行为合同最小修复

- **决定**：Apple 文档决定平台规则；成熟项目用于验证边界和测试模式。没有证据证明缺陷时不改架构。
- **理由**：当归的离线 Drift + durable outbox + AlarmKit/普通通知组合与候选项目均不相同。
- **未采用**：整体移植 Signal/Joplin/AppFlowy；除架构错配外，AGPL/GPL 也不适合默认复制。

## DD03 — 控制状态严格解码，诊断日志可带损坏标记地宽松解码

- **决定**：alarm records、transactions、cancellations 使用版本化 envelope、generation 和 checksum；任一元素坏则整代失败并回退严格验证的 `.bak`。events 可保留有效项，但追加匿名 `journal-corrupt`。
- **理由**：控制记录缺一项会改变系统行为；日志少一项只降低诊断完整性。S01、R02/R03 的恢复模式支持失败关闭。
- **未采用**：所有数组继续 `compactMap`；会丢取消墓碑。所有日志也严格失败；会因为单条诊断丢失全部历史。

## DD04 — daemon 移除不等同于用户可感知投递；15 分钟内选择可靠性优先

- **决定**：A01 允许从 one-shot 不在 `AlarmManager.alarms` 推断 daemon 已 fire/stop 并移除，但只有明确观察 `.alerting`、Stop/Snooze 或系统动作时才记录用户可感知的 delivered/systemAlert。缺失且未超过 15 分钟进入 `repair-pending` 并保守补登记，超过则 `missed`。
- **理由**：daemon 生命周期事实不能证明用户看见或听见；A03 也不保证普通通知的实际及时投递。本产品在窗口内选择降低漏响概率。
- **权衡**：原 one-shot 若其实已经完整提醒但事件没被 App 观察，保守补登记存在极端重复提醒风险；用 revision/session、单次 repair marker 和 15 分钟上限约束。此为产品可靠性权衡，不表述成 Apple bug。
- **未采用**：沿用 v1.1.4 的 delivered+stopped 过度断言并删除 mirror；也未采用无限重试，以免持续重复提醒。

## DD05 — 15 分钟规则在三层只采样一次时钟

- **决定**：Dart、Swift 与合同测试统一定义 `now - triggerAt > 15 min` 为 expired；边界恰好 15:00 仍在窗口。一次操作只读取一次注入时钟并传递 occurredAt。
- **理由**：避免边界在多次 `Date.now` 之间翻转。现有 RunnerTests 已有一次时钟 sample 的良好模式。
- **未采用**：平台层与 Dart 分别读取当前时间；会产生互相矛盾的 missed/delivered 状态。

## DD06 — 普通通知动作升级为版本化 CAS payload

- **决定**：iOS 15–25 payload 增加 payload version、task ID、reminder ID、revision、session；Snooze/Stop 用同一 CAS 合同。旧 `task:<id>` payload 只导航，不再修改提醒。
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

## DD13 — merge 总是生成本机 ID 和新的提醒 revision/session

- **决定**：来源 task/note/reminder 与 platform ID 建立显式 ID map；重复同一备份 merge 由稳定 import identity 幂等；系统提醒只由本机 outbox 重建。
- **理由**：平台 ID 和 system request 是设备态，复用会产生碰撞/陈旧动作。
- **未采用**：原样复制 source platform ID 或 outbox；可能取消/覆盖本机提醒。

## DD14 — 文件保护与 Keychain 可访问性配对

- **决定**：需要首次解锁后后台恢复的 DB/原生控制状态使用显式 `completeUntilFirstUserAuthentication`；设备密钥使用 `AfterFirstUnlockThisDeviceOnly`、不可同步。所有派生态排除 iCloud，属性写入必须验证或记录稳定错误。
- **理由**：A08/A10/A11；D05 和 X11 表明默认继承/锁定行为不能靠猜。
- **验证边界**：Simulator 可检查资源属性，真实锁屏/重启仍 device-unverified。

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

## 功能批次门禁

1. 第一批 F01/F03/F04/F15/F17/F19：D01–D04 全部关闭且 iOS 18/26 合同无未解释差异。
2. 第二批 F09/F10/F11/F12/F16/F18/F20/F21：故障注入、旧版夹具和恢复不覆盖良好 DB 全部通过。
3. 第三批 F02/F05/F06/F07/F08/F13/F14/F22/F25：核心工作流模型测试通过。
4. 第四批 F23/F24/F26/F27/F28：体验、a11y、供应链和发布证据完成。

每一批都必须保留 Android 共享层回归；P0 未关闭时不得用 P2 改进替代发布门禁。
