# 长期数据压力与可靠性测试

## 目标与门禁

这组测试验证长期本地使用后，搜索、“过往”整篇编辑、可读导出、备份检查以及合并/替换恢复仍能正确完成，并阻止逐行异步 I/O 导致的算法性退化。

硬门禁：

- 主压力链每个计时步骤小于 30 秒；
- 主压力链测试体总耗时小于 90 秒（不包括 Flutter 编译与测试文件加载）；
- 3,600 块“过往”中仅修改 1 块的定向回归小于 10 秒，且只能增加该块的 `row_version`；
- 500 条已有本地事项 + 1,000 条无冲突来源事项的非空目标合并小于 30 秒；
- 可读 ZIP 和 `.dgbak` 必须通过内容哈希/包哈希校验，恢复后必须通过 `PRAGMA quick_check` 与 `foreign_key_check`。

RSS 只记录为容量观测值，不设与机器强绑定的失败阈值。

## 数据规模

`test/stress/large_dataset_reliability_test.dart` 在临时目录中创建真实 SQLite 文件，填充：

- 2,000 个事项，每个事项有独立文档和正文块；
- 1,000 个笔记，分布在 32 个文件夹，每个笔记有独立文档和正文块；
- 3,600 个“过往”块，日期跨越 2017-01-01 至 2026-11-09；
- 事项、笔记和“过往”搜索投影。

完整链路依次执行：批量填充、三个作用域的精确搜索、“过往”读取、3,600 块整篇保存、全量可读导出及独立验签、备份创建与隔离检查、合并恢复、替换恢复。

`test/stress/nonempty_merge_performance_test.dart` 另外构造：

- 目标库：500 个本地事项 + 500 个本地“过往”块；
- 来源库：1,000 个事项 + 1,000 个“过往”块；
- 来源与目标的稳定 ID、文件夹规范名称互不冲突。

该回归不只检查耗时，还检查本地记录未被覆盖、目标语言设置未被来源替换、“过往”以分隔符追加、provenance 数量正确，且无冲突记录。

## 合并批量路径的触发条件

目标库可以已有用户数据。只有同时满足以下条件时，才使用集合预检查 + 单事务批量写入路径：

- 目标库中不存在该来源 `datasetId` 的既有 provenance；
- 文件夹、事项、笔记、所属文档、文档块、提醒、Past event/part/anchor 和回收站条目的稳定 ID 均无交集；
- 文件夹规范名称无交集；
- 事项/笔记搜索键无交集；
- 将产生的提醒平台任务 dedupe key 与目标库无冲突。

任何一项不满足时，都回退到通用解析器，保留现有的同哈希跳过、异哈希 UUID 重映射、文件夹同名复用、冲突审计与幂等 provenance 语义。

## 2026-08-22 Windows 基线

环境：Flutter 3.47.1 / Dart 3.13.1，Windows x64，debug `flutter test`，单进程隔离执行。

| 步骤 | 耗时 |
| --- | ---: |
| 填充数据 | 728 ms |
| 三作用域搜索 | 31 ms |
| 读取 3,600 个 Past blocks | 117 ms |
| Past 整篇修改 1 块并保存 | 481 ms |
| 可读导出 + 校验 | 2,043 ms |
| 创建备份 | 518 ms |
| 隔离检查备份 | 348 ms |
| 合并恢复 | 3,183 ms |
| 替换恢复 | 618 ms |
| 测试体总计 | 10,201 ms |

主压力链输出的可读 ZIP 为 354,280 bytes，`.dgbak` 为 637,158 bytes，最终 RSS 观测值为 259,518,464 bytes。非空目标合并基线为 691 ms，结束时 RSS 观测值为 202,977,280 bytes。

CI 日志中两行机器可读前缀分别为 `DANGGUI_STRESS_METRICS` 和 `DANGGUI_NONEMPTY_MERGE_METRICS`。主基线字段：

- `dataset`：事项、笔记和 Past blocks 规模；
- `elapsedMilliseconds` / `totalMilliseconds`：步骤与总耗时；
- `rssBytesAfterStep` / `finalRssBytes`：粗略 RSS 观测；
- `fileBytes`：可读导出和备份文件体积。

## 运行方式

```powershell
flutter test test/stress/large_dataset_reliability_test.dart --reporter expanded
flutter test test/stress/nonempty_merge_performance_test.dart --reporter expanded
flutter test test/data/document_repository_bulk_edit_test.dart --reporter expanded
flutter test test/services/backup/backup_service_test.dart
```

## 当前局限

- 数据高度可压缩，文件体积不代表照片等未来附件；当前 schema 也不包含附件表。
- 性能数字来自 Windows debug 测试，用于发现数量级退化，不是真机响应时间承诺。
- 冲突密集的合并会进入通用解析器；其正确性、幂等性和 UUID 重映射由 `backup_service_test.dart` 覆盖，但尚未设置与无冲突路径相同的大规模耗时门禁。
- 本组测试不涉及真机通知调度、系统分享面板、Android 杀进程或 iOS 后台策略；这些属于平台集成测试。
- 当前备份基线使用未加密包；Argon2id + AES-GCM 的正确性由 codec 单元测试覆盖，其耗时不应与未加密导出混为一个性能门禁。
