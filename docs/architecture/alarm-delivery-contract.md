# 闹钟投递合同（v1.1.5）

本文固定 Android、iOS 与 Dart 在 v1.1.5 使用的可靠性语义。它描述应用可以验证的行为，不把系统或厂商无法保证的能力写成承诺。

## 身份与快照

- 一个调度版本由 `reminderId + revision` 唯一标识；`sessionId` 由这两个字段在 Android、iOS 和 Dart 端确定性派生，使进程重启后仍能幂等识别同一个响铃会话。
- `listAlarmSnapshots()` 返回 `reminderId`、`platformId`、`revision`（兼容别名 `scheduleRevision`）、`triggerAtEpochMs` 与 `state`。
- `state` 使用 `registered`、`ringing`、`stopped`、`snoozed`、`missed`、`capacity-deferred`；未知值不得被当成健康调度。
- v1.1.3 的 `listScheduledAlarms` 只保留一个版本的兼容入口。缺少 revision 或触发时间的旧快照会被安全升级，不能永久掩盖状态差异。

## 调度、替换与取消

- 新建或编辑采用“持久化待处理 → 安装新 revision → 验证并提交 → 退休旧 revision”。新调度失败时，仍有效的旧调度必须保留。
- Stop/Snooze 必须同时校验 reminder、revision 和 session；重复操作、陈旧通知动作与旧 AppIntent 均为无副作用成功。
- iOS 15–25 普通通知的动作 payload 也必须携带无正文的 reminder/revision/session 身份；历史 `task:<id>` 只允许安全打开尚存在的事项，不能 Stop/Snooze 或修改当前提醒。
- Android v1.1.4 曾在本机私有镜像内使用随机响铃 session。v1.1.5 只在首次打开旧版 device-protected store 时，对可以由配对的 delivered/terminal 事件、精确的 snooze 后继记录或明确过期记录证明的旧 session 做一次性转换。若更新边界仍留有旧通知动作，正在响铃的记录会暂存该 canonical UUID 作为一次性 alias；它只能匹配同 reminder/revision，Stop/Snooze 成功后随记录移除。迁移标记写入后，任意 session 不会再被归一化。
- 15 分钟截止始终相对用户原设定时刻计算。前台修复可将系统 API 的安装时刻推迟到“现在 + 1 秒”，但原生镜像仍保留原触发时刻，不得重置迟到窗口。
- 取消先写入 durable tombstone，再清理系统调度，最后退休本地记录。崩溃恢复只能继续取消，不能把已取消提醒重新创建。
- 启动恢复比较数据库与平台快照，仅修复缺失或不一致项。AlarmKit one-shot 从 daemon 消失可表示系统已 fire/stop，但不能证明用户看到、听到或感到提醒；只有观察到 alerting 或权威用户动作才记录 `delivered/systemAlert`。未观察到且仍在 15 分钟窗口内时最多执行一次保守补登记，观察到新登记后才允许后续再次修复。
- 权限等级改变时强制重建投递路线；一次失败后保留重试意图。保守补登记偏向可靠性，极端竞态可能产生一次重复提醒，该权衡必须进入诊断和发布边界。

## 时间与容量

- 三端都按绝对 UTC 时间点调度，同时保存 canonical IANA 时区作为用户本地日期语义；首次排期、Snooze、原生事件、重启和 DST 切换不得把它降级为缩写。
- 到点后 15 分钟（含边界）仍属于恢复窗口；超过 15 分钟必须记录 `missed` 并停止输出。打开应用不得让超过窗口的提醒补响。
- iOS 15–25 的普通通知只维护最近 60 条，为系统和测试预留 4 条；其余记录为 `capacity-deferred`，释放名额后自动补位。
- AlarmKit 的系统容量不是固定常量；`maximumLimitReached` 同样映射为 `capacity-deferred`，不得删除 durable 请求。

## 能力与权限

- 交付等级只有 `alarm-grade`、`time-sensitive-best-effort`、`ordinary`、`unavailable`。
- 普通运行时权限由应用主动请求。Android 精确闹钟、全屏提醒、厂商自启动和电池限制只能检测并打开系统页面，应用不得声称已静默授权。
- Android 可以单独控制震动；iOS 触感由系统控制，界面必须明确展示这一点。
- iOS 26+ AlarmKit 才能标为 `alarm-grade`；iOS 15–25 的 Time Sensitive 回退最多是 `time-sensitive-best-effort`。

## 本地诊断与隐私

- 生命周期事件为 `registered`、`delivered`、`foreground`/`systemAlert`、`audio`、`vibration`、`missed`、`stopped`、`snoozed`、`error`。
- 原生端最多保存最近 200 条可丢失诊断；`delivered/missed/stopped/snoozed` 业务事件按 reminder/revision/type 去重并保留到 Flutter 明确 ack，不会被诊断流量逐出。事件只含调度身份、revision/session、时间、延迟、状态和稳定错误码，不含事项标题或正文。
- Android 诊断位于禁用备份的应用私有数据；iOS 镜像、事务与事件位于 `Application Support/danggui`，设置排除 iCloud 备份并显式采用 `completeUntilFirstUserAuthentication` 文件保护。底层错误文本和用户路径不得写入诊断。

## 验收边界

- 自动化门禁验证合同、Android API 24/36、正式 APK 元数据、iOS unsigned build、RunnerTests，以及固定 iOS 18.5/26.5 上的两条跨模块 XCUITest。
- 模拟器不能证明真实扬声器、震动/触感、静音/专注、锁屏隔夜、重启和进程被系统终止后的投递。v1.1.5 虽已是稳定版，这些项目在实体小米/其他 OEM Android 与 iPhone 完成前仍标为 `device-unverified`，不得扩大解释。
