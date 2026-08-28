# v1.1.5 iOS 全功能参考驱动审计

## 审计边界

- 审计基线：`v1.1.4` 对应提交 `2e6e67a2af1239bb56991f85a08c5ff64c00197f`。
- 研究日期：2026-08-28。所有源码判断均以 `git show 2e6e67a2:<path>` 为准，避免把共享工作树中尚未完成的 v1.1.5 修改误记为基线能力。
- 范围：iOS 原生层、共享 Dart 业务层以及 Android 对共享层的回归约束；不全面重审 Android 原生闹钟实现。
- 证据来源：Apple/SQLite 官方文档、项目原仓库的固定提交、项目原 issue 或修复提交。博客、聚合文章、Star 数和 README 宣称不作为可靠性证明。
- 本目录是审计与实施依据，不宣称真机结论，也不改变 v1.1.4 的标签、附件或校验值。

## 文件导航

| 文件 | 用途 |
|---|---|
| [feature-contracts.md](feature-contracts.md) | F01–F28 功能树、行为合同与必测失败路径 |
| [source-ledger.md](source-ledger.md) | 固定来源、精确文件/符号、评分、许可证和采用边界 |
| [traceability-matrix.md](traceability-matrix.md) | 功能—来源—基线实现—差距—测试—结论追踪 |
| [risk-evidence-gaps.md](risk-evidence-gaps.md) | 已证实缺陷、风险、证据缺口和真机边界 |
| [design-decisions.md](design-decisions.md) | 已采用/未采用方案及理由 |

## 证据和结论词汇

证据强度：

- `E0`：只有概念或 README 宣称。
- `E1`：固定提交中的具体实现或官方 API 规则。
- `E2`：来源项目有针对性测试或 CI。
- `E3`：当归仓库有可重复的合同/单元/集成测试。
- `E4`：在固定 Xcode 和 Simulator 上重复通过，并与当前 Apple 规则一致。
- `E5`：实体 iPhone 上多次覆盖锁屏、静音/专注、强杀、重启、声音和触感。

发布说明只允许使用三种结论：

- `contract-proven`：合同已由代码审阅和自动化测试证明；不等同于平台真实投递。
- `simulator-proven`：固定 Xcode/Simulator 矩阵实际通过，并保留 `.xcresult` 或摘要。
- `device-unverified`：实体设备行为尚未证明。所有声音、震动、静音/专注、隔夜锁屏、系统强杀和重启后投递当前均属于此类。

“计划测试”“存在测试文件”不能升级结论。CI 未实际通过前，矩阵中的 Simulator 项均保持 `pending`。

## 总体审计结论

v1.1.4 已具备较完整的提醒 outbox、revision/session、15 分钟迟到、两阶段替换、备份加密和最近删除合同，但尚不能称为 iOS 全功能可靠：

1. 原生闹钟镜像采用逐元素宽松解码，部分损坏会静默丢掉事务/取消墓碑，并可能把受损主文件覆盖到最后已知良好备份。
2. AlarmKit one-shot 从系统快照缺失可表示 daemon 已 fire/stop 并移除，但不能证明用户实际看见/听见；当前实现在 15 分钟窗口内仍直接记录 `delivered`/`stopped` 并退休镜像，诊断过度断言且没有保守恢复机会。
3. iOS 15–25 普通通知动作只携带 task ID；旧通知动作可能作用于编辑后的新 revision。
4. `scheduled_zone_id` 实际写入 `DateTime.timeZoneName` 缩写，并非架构文档所称 IANA 区域，无法可靠重建夏令时和跨时区语义。
5. 原生镜像与诊断虽排除 iCloud 备份，但未明确设置文件保护；通知能力判定也未覆盖 alert/sound setting 的真实状态。
6. 数据库、恢复、编辑和导出具备大量单元测试，但迁移中断、磁盘不足、逐阶段故障注入、冷启动通知动作、VoiceOver、iPad 和大 Dynamic Type 仍缺少足够证据。

这些问题和其最小修复方向在风险表与设计决策中逐项追踪。

## 复核方式

```powershell
git rev-parse v1.1.4
git show 2e6e67a2af1239bb56991f85a08c5ff64c00197f:ios/Runner/ReminderPlatformBridge.swift
git show 2e6e67a2af1239bb56991f85a08c5ff64c00197f:ios/RunnerTests/RunnerTests.swift
git show 2e6e67a2af1239bb56991f85a08c5ff64c00197f:lib/src/services/notifications/notification_coordinator.dart
```

任何 v1.1.5 修复必须遵循“证据 → 失败测试 → 最小修复 → 回归 → 决策记录”，并在本目录矩阵中更新状态。
