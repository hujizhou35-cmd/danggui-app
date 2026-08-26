# 闹钟投递合同（v1.1.4）

本文固定 Android、iOS 与 Dart 在 v1.1.4 使用的可靠性语义。它描述应用可以验证的行为，不把系统或厂商无法保证的能力写成承诺。

## 身份与快照

- 一个调度版本由 `reminderId + revision` 唯一标识；一次实际响铃会再生成 `sessionId`。
- `listAlarmSnapshots()` 返回 `reminderId`、`platformId`、`revision`（兼容别名 `scheduleRevision`）、`triggerAtEpochMs` 与 `state`。
- `state` 使用 `registered`、`ringing`、`stopped`、`snoozed`、`missed`、`capacity-deferred`；未知值不得被当成健康调度。
- v1.1.3 的 `listScheduledAlarms` 只保留一个版本的兼容入口。缺少 revision 或触发时间的旧快照会被安全升级，不能永久掩盖状态差异。

## 调度、替换与取消

- 新建或编辑采用“持久化待处理 → 安装新 revision → 验证并提交 → 退休旧 revision”。新调度失败时，仍有效的旧调度必须保留。
- Stop/Snooze 必须同时校验 reminder、revision 和 session；重复操作、陈旧通知动作与旧 AppIntent 均为无副作用成功。
- 取消先写入 durable tombstone，再清理系统调度，最后退休本地记录。崩溃恢复只能继续取消，不能把已取消提醒重新创建。
- 启动恢复比较数据库与平台快照，仅修复缺失或不一致项。权限等级改变时强制重建投递路线；一次失败后保留重试意图。

## 时间与容量

- 三端都按绝对 UTC 时间点调度。
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
- 原生端最多保存最近 200 条。事件只含调度身份、revision/session、时间、延迟、状态和稳定错误码，不含事项标题或正文。
- Android 诊断位于禁用备份的应用私有数据；iOS 镜像、事务与事件位于 `Application Support/danggui` 并设置排除 iCloud 备份。

## 验收边界

- 自动化门禁验证合同、Android API 24/36、正式 APK 元数据、iOS unsigned build 与 RunnerTests。
- 模拟器不能证明真实扬声器、震动/触感、静音/专注、锁屏隔夜、重启和进程被系统终止后的投递。这些项目在实体小米/其他 OEM Android 与 iPhone 完成前，v1.1.4 保持 Pre-release。
