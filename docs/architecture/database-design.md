# 当归本地数据库设计

- 状态：Schema v1（实现基线）
- 数据库：SQLite + Drift
- 适用范围：Android、iOS；本地优先，无账号、无云端依赖

## 1. 设计目标

当归把用户数据的完整副本保存在设备本地。数据库设计优先保证：

- 事项、笔记和“过往”编辑在崩溃后仍保持原子一致；
- 提醒的业务意图与 Android/iOS 通知注册解耦，系统调用失败可重试；
- “过往”可继续编辑，同时保留它从哪次事项完成记录演化而来的可解释证据；
- 删除默认可恢复 30 天，物理删除有明确边界；
- 备份可离线校验、可选口令加密，恢复前不覆盖现有数据库；
- 持久化枚举使用稳定字符串而不是枚举下标，后续版本可以安全追加枚举值。

所有绝对时间以 UTC 微秒整数保存。与用户语义有关的日期/时间同时保存 ISO
本地值和 IANA 时区标识，避免夏令时或跨时区后改变原意。实体 ID 使用 UUID；
带 `row_version` 的聚合根使用乐观锁更新。

## 2. 22 张表与领域边界

### 2.1 元数据与设置（2）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `app_meta` | `id = 1`；`dataset_id` 唯一 | 数据集身份、创建时间、最近完整性检查和搜索模式。`dataset_id` 是备份/恢复身份校验依据，不是用户或设备 ID。 |
| `app_settings` | `id = 1` | 语言、字体、字号、密度、提醒默认值、自动备份和帮助版本。`text_scale_percent` 为 90–120；稍后提醒为 10/30/60 分钟；每日备份本地时间的小时为 0–23、分钟为 0–59，默认 02:00。 |

`locale_mode` 支持 `system`、`zhHans`、`en`、`ja`、`ru`。设置保存通过
`row_version` 做 compare-and-swap；语言变化会为未来提醒写入刷新语言的 outbox
任务。

### 2.2 文档内核（3）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `documents` | UUID；可选唯一 `singleton_key` | 统一承载事项正文、笔记正文和“过往”。只有 `kind = past` 可使用 `past.main`，且非 past 文档不得有 singleton key。保存修订号、规范化语义哈希和格式版本。 |
| `document_blocks` | UUID；FK → `documents`；可自关联父块 | 有序块模型。`sort_rank` 负责稳定排序；块保存纯文本、JSON 载荷、JSON 属性和语义哈希。只有 `checklist` 块必须有 `is_checked`，其他块必须为 NULL。文档删除时级联删除块。 |
| `document_revisions` | UUID；FK → `documents` | 破坏性编辑前的不可变快照，使用 `json-v1` 编码并保存 SHA-256。`(document_id, revision)` 唯一，支持审计、冲突说明和将来的局部恢复。 |

正文没有分别复制到事项和笔记表；展示标题、计划等查询热字段放在聚合表，富文本正文只在
文档内核保存一份。`DocumentRepository.replaceBlocks` 要求调用方传入
`expectedRevision`，整批块、修订快照、文档哈希、锚点和搜索投影在同一事务更新。

### 2.3 事项、提醒与平台副作用（4）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `tasks` | UUID；`document_id` 唯一，FK RESTRICT → `documents` | 事项标题、计划日期、计划文本、手动顺序及状态。标题去空白后不可为空；`trashed` 与 `deleted_at_utc` 必须同步；`completionPending` 必须同时具备关闭 UTC、本地日期、本地时间和时区。 |
| `reminders` | UUID；`task_id` 唯一，FK CASCADE → `tasks` | 一事项最多一个逻辑提醒。保存本地日期时间、时区、解析后的 UTC、声音/振动、暂停原因、稍后提醒和 `schedule_revision`。业务记录不保存平台通知 ID。 |
| `notification_registrations` | PK/FK → `reminders`；平台通知 ID 唯一 | 当前设备上的 Android/iOS 通知注册结果，是可重建的设备态。记录注册时使用的提醒修订号和语言。 |
| `platform_jobs` | UUID；`dedupe_key` 唯一 | 事务 outbox。任务种类为排程、取消、刷新提醒语言或执行备份；状态为 pending/running/succeeded/failed，并保存次数、下次重试时间和稳定错误码。 |

提醒卡片读取 `reminders.scheduled_at_utc`（或本地日期时间）与事项一起投影，因此设置了
19:50 的事项可直接显示“19:50 提醒”，无需访问平台通知 API。

### 2.4 文件夹与笔记（2）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `folders` | UUID；`normalized_name` 唯一 | 用户文件夹及手动顺序。规范名防止只因大小写/首尾空格产生重复。 |
| `notes` | UUID；`document_id` 唯一，FK RESTRICT → `documents`；可选 FK → `folders` | 笔记聚合、标题、置顶和软删除时间。文件夹删除时笔记的 `folder_id` 置 NULL，不删除笔记。 |

### 2.5 最近删除（1）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `trash_entries` | UUID；`(entity_type, entity_id)` 唯一 | 事项/笔记软删除索引，包含删除时间、物理清理时间、恢复上下文 JSON 和快照 SHA-256。默认 `purge_after_utc = deleted_at + 30 天`。 |

软删除保留聚合和文档数据。事项进入最近删除时，逻辑提醒被暂停且 outbox 请求取消当前
平台通知；恢复时未来提醒重新排程，已过期提醒标记为 expired。到期清理显式按外键顺序
删除聚合、文档和 trash 记录。

### 2.6 “过往”来源与锚点（3）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `past_events` | UUID；FK RESTRICT → `documents`；`append_sequence` 唯一 | 一次“关闭事项 → 加入过往”的不可变事件头。保存完成 UTC、本地日期/时区、完整来源快照和 SHA-256，以及当前锚点汇总状态。 |
| `past_event_parts` | UUID；FK CASCADE → `past_events` | 将来源拆成 time/title/body/checklist/dueDate/plan 等逻辑部分，保存原始文本、原始载荷和哈希；`(event_id, source_order)` 唯一。 |
| `past_anchor_links` | UUID；FK CASCADE → part；可空 FK SET NULL → 当前 block | 来源 part 到当前“过往”块的可演化映射。保留 `last_known_block_id`，并记录 original/split/merged/replacement 与 linked/deleted/orphaned。 |

### 2.7 搜索投影（1）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `search_records` | 自增 rowid；`(scope, entity_id)` 唯一 | 事项、过往和笔记的派生搜索投影，保存规范化标题、正文和日期键。当前 v1 使用 SQLite contains/LIKE 语义；`app_meta.fts_mode` 为将来启用 FTS5 留出能力标记。 |

搜索投影与所属聚合在同一事务增删改，软删除时移除、恢复时重建。它不是唯一事实来源；
迁移或完整性修复可以从 documents/tasks/notes/past 全量重建。

### 2.8 备份、恢复与导入审计（6）

| 表 | 主键/关系 | 职责与关键不变量 |
| --- | --- | --- |
| `backup_targets` | UUID | 用户授权的本地目录/系统文档目标。locator 可能是文本或二进制安全书签；权限属于设备态。 |
| `backup_encryption_profiles` | UUID | Argon2id 参数、盐、被包装主密钥及可选平台密钥别名。禁止存储明文口令或明文主密钥。 |
| `backup_runs` | UUID；可选 FK SET NULL → target/profile | 每次备份的状态机和结果：文件名、应用/Schema/manifest 版本、记录数 JSON、大小、归档 SHA-256、时间与错误码。当前状态为 started → writing → verifying → succeeded，任一步可转 failed。 |
| `restore_runs` | UUID；可选 FK SET NULL → 预恢复备份 | 恢复来源、来源哈希、replace/merge 模式、来源 Schema、摘要、状态与错误码。 |
| `restore_conflicts` | UUID；FK CASCADE → `restore_runs` | merge 模式下的逐实体冲突、哈希和解决策略。replace 模式通常不产生记录。 |
| `import_provenance` | 复合 PK：来源数据集、类型、来源 ID、来源哈希 | 防止重复导入；映射来源实体与本地实体，可回溯到 restore run。 |

## 3. “过往”锚点的拆分、合并与脱离语义

完成事项时，系统先冻结一份 `source_snapshot_json`，再按语义建立 parts。每个 part 初始创建
一个 `original + linked` 链接指向新追加的 `document_block`。日期标题只是分组展示块，不属于
某一个事项事件。

编辑“过往”时，调用方可把“旧块 ID → 新块 ID 列表”作为替换映射随块事务提交：

- 一对一：关系为 `replacement`；来源仍可追踪，但事件汇总为 modified。
- 一对多：同一 part 产生多条链接，关系为 `split`。
- 多对一：多个 part 的链接指向同一新块，关系为 `merged`。
- 无替换目标：链接的 `current_block_id` 置 NULL，`link_state = deleted`，但
  `last_known_block_id`、part 原文和来源快照继续保留。

映射必须只引用本次被删除的旧块，目标必须存在于新块集合，且单个旧块的目标不得重复。
当前哈希与 part 原始哈希、链接数量和关系共同决定事件汇总状态：全部一对一原始且哈希相同
为 attached；仍有链接但发生编辑/拆合为 modified；所有 part 都无有效链接为 detached；
orphaned 保留给导入或异常修复时无法解析来源的情况。

这套三层结构避免用易碎的字符区间锚点：用户可以重新排版、拆段、合段，来源证据仍不会
随当前文本被覆盖。

## 4. 关键索引

| 索引 | 用途 |
| --- | --- |
| `idx_tasks_status_rank(status, deleted_at_utc, manual_rank, id)` | 首页未完成事项及手动排序 |
| `idx_tasks_due_date(due_local_date, status)` | 日期筛选 |
| `idx_blocks_document_rank(document_id, parent_block_id, sort_rank, id)` | 文档树的稳定有序读取 |
| `idx_revision_document_number(document_id, revision)`（唯一） | 修订幂等与版本定位 |
| `idx_reminders_status_time(status, scheduled_at_utc)` | 到期扫描与恢复重排程 |
| `idx_platform_jobs_pending(status, next_attempt_at_utc)` | outbox 消费 |
| `idx_notes_folder_updated(folder_id, deleted_at_utc, updated_at_utc)` | 文件夹/最近笔记 |
| `idx_trash_entity(entity_type, entity_id)`（唯一） | 防止重复软删除 |
| `idx_trash_purge(purge_after_utc)` | 30 天到期清理 |
| `idx_past_events_date(completion_local_date, append_sequence)` | 按本地完成日呈现过往 |
| `idx_past_part_order(event_id, source_order)`（唯一） | 事件来源顺序 |
| `idx_anchor_block(current_block_id)` | 编辑块时反查受影响事件 |
| `idx_search_entity(scope, entity_id)`（唯一） | 搜索投影 upsert |
| `idx_import_provenance_local(entity_type, local_entity_id)` | 本地实体反查导入来源 |
| `idx_backup_runs_created(status, started_at_utc)` | 备份状态与历史列表 |

## 5. 必须保持原子的事务

1. **创建/更新事项或笔记**：聚合、document、blocks、语义哈希和搜索投影一起提交。
2. **关闭事项**：校验状态，写入关闭 UTC/本地时间/时区，暂停逻辑提醒，并写取消通知 outbox。
3. **加入过往**：校验 completionPending；冻结来源快照；分配 append sequence；追加日期/内容块；
   写 event/parts/links；更新过往文档哈希和搜索；归档事项；取消提醒。任一步失败全部回滚。
4. **替换文档块**：检查 expected revision；先存编辑前 revision；写新块和替换映射；更新锚点
   汇总、文档 revision/hash 与搜索投影。
5. **设置/删除提醒**：逻辑 reminder 与对应 schedule/cancel outbox 同事务提交。平台 API 永远在
   事务提交后调用。
6. **软删除/恢复/物理清理**：聚合状态、trash entry、搜索投影、提醒状态和 outbox 同事务更新。
7. **保存设置**：使用 row version；若语言改变，为每个未来提醒递增 schedule revision 并写刷新任务。

## 6. Outbox 与幂等

`dedupe_key = <kind>:<aggregate_id>:<aggregate_revision>`，因此同一提醒修订的同类平台动作最多
入队一次。消费者只读取 pending/failed 且已到 `next_attempt_at_utc` 的任务，先标 running，成功
标 succeeded；失败保存不含敏感信息的错误码并使用有上限的指数退避。

平台注册行携带 `schedule_revision`。消费者必须忽略比 reminder 当前修订更旧的工作，避免快速
编辑或关闭/重开时旧任务覆盖新意图。数据库提交成功但进程在调用系统 API 前终止也不会丢失
意图；下次启动继续消费即可。

恢复时不会复用来源设备的通知 ID。服务删除 registrations/outbox，令已过期的 scheduled
提醒变为 expired，并为当前仍 active 的未来提醒重建 scheduleReminder 任务。

## 7. 备份格式、加密与恢复

### 7.1 `.dgbak` 格式

未加密包是只含两项的 ZIP：

- `manifest.json`：规范键序 JSON，含 app ID、应用版本、创建 UTC、dataset ID、数据库 Schema、
  记录数、数据库路径和数据库 SHA-256；
- `data/danggui.sqlite`：通过 SQLite `VACUUM INTO` 生成的一致、可移植 SQLite 快照。导出副本会
  清除通知注册、平台 outbox、备份目标 locator 和密钥包装 profile，避免把设备能力带进归档；
  事项、笔记、过往、设置、逻辑提醒、搜索投影与审计仍保留；其中搜索投影只是缓存，恢复时
  必须从事项、笔记和过往权威表重建，不能信任来源包中的投影。

读取包体前先以文件元数据限制为 512 MiB 并拒绝非普通文件；随后分块读取，每次追加前重复总量
上限，并要求实际长度等于先前 stat，拒绝读取期间替换/增长。codec 在解压前手工预检 EOCD、
central/local headers、精确的两项名称、条目数、声明展开大小、压缩方法、加密位、磁盘号、
重叠区间和 Unix/DOS 文件类型；随后仍拒绝非法 SQLite 头、manifest/数据库 SHA 不一致并验证
ZIP CRC。当前限制为包/数据库最多 512 MiB、manifest 256 KiB、加密头 16 KiB。

### 7.2 口令加密

加密包使用 `DANGGUI-ENC-1\n` 魔数、4 字节大端 JSON 头长度、公开参数头和密文。参数固定为：

- Argon2id：随机 16 字节 salt、64 MiB 内存、3 次迭代、并行度 1、输出 256 bit；
- AES-256-GCM：随机 12 字节 nonce、128 bit authentication tag；
- 整个 ZIP 作为认证加密明文，错密码、密文/nonce/tag 篡改或截断均在解包前失败。

口令和派生密钥不写入数据库、manifest、日志或错误码。手工导出当前直接从用户口令派生本次
文件密钥；`backup_encryption_profiles` 用于未来自动备份的主密钥包装与轮换，二者不得混为
明文口令存储。

### 7.3 创建流程

1. 同一 `BackupService` 实例把 create、replace 和 merge 放入同一异步互斥队列；写
   `backup_runs(started)`，随后进入 writing；
2. 通过 `VACUUM INTO` 生成 staging snapshot，在副本内清除设备态并执行完整
   `integrity_check`、`foreign_key_check` 和自包含 WAL 校验，然后生成 manifest 和包；
3. 写同目录 `.partial` 文件，进入 verifying，回读并比较长度及 SHA-256；
4. 原子 rename 为 `.dgbak`，审计状态置 succeeded；
5. 任一步失败独立、best-effort 地清除 snapshot、WAL/SHM/journal、partial 和最终输出；单个清理
   失败不能跳过其他敏感文件或掩盖原始错误，审计置 failed 并保存稳定错误码。

### 7.4 只读 inspect 与 replace 恢复流程

`inspect(file, passphrase)` 会完整执行解密、解压前 ZIP 资源预检、ZIP CRC、manifest、数据库
SHA-256、SQLite `integrity_check`、外键、dataset singleton 和 manifest 记录数核对；同时把
`sqlite_schema` 中全部应用表、列/约束 SQL、显式索引、trigger 和 view 与本构建生成的精确 schema
签名比较。仅 `user_version` 相同不足以通过。它只打开系统临时目录中的
隔离副本，绝不读取或修改 live database；因此选择文件后可先安全展示数据集、创建时间、是否加密
及各类记录数，再由用户决定 replace 或 merge。损坏包、错误口令和未来 schema 都在接触 live
database 前拒绝。

replace 流程：

1. 先解密、验证 ZIP、manifest 和数据库 SHA；只接受当前支持的 app ID 与 Schema；
2. 写唯一 staging 文件，用独立 Drift 连接执行完整 `integrity_check`、`foreign_key_check`、
   精确 schema 签名、`user_version`、dataset ID 和两个 singleton 检查；
3. 在 staging 中清除来源设备的通知注册、平台任务、备份目标和密钥包装；从权威业务表重建
   search_records，并重建提醒 outbox；
   随后再次验证 schema、完整性、singleton 与 manifest 记录数，才将被备份在进行中状态的审计
   标为 interruptedByRestore 并写成功 restore audit；
4. 把 staging 变成自包含候选并关闭；等待 live 连接排队写结束后关闭它，再从 live 路径用新的
   SQLite 连接执行 `VACUUM INTO`，生成并完整验证 `.pre-restore-*` 安全副本；
5. 候选、安全副本均通过完整 integrity/FK/schema 验证后写入已 flush 的恢复 journal；同目录 rename
   候选到 canonical live 路径，flush 后再次完整验证，成功才删除 journal；
6. 启动时若 journal 存在，完整验证 live/candidate/safety 后保留有效 live，或从候选/安全副本恢复；
   若无 journal，则只清理由精确 app-owned 前缀和安全 operation ID 构成的孤儿 candidate/sidecar；
   失效数据库和应用状态 provider，确保不继续使用已关闭连接。

候选的旧文件删除、复制、flush 和完整验证均处于同一失败清理边界内；journal 写入前失败会逐项
best-effort 清 candidate/WAL/SHM/journal，任何清理错误都不能替换首个业务或 I/O 异常。来自包内容
的格式/schema/语义拒绝使用稳定 `FormatException`；权限、磁盘满、flush、close 和 SQLite 运行时
错误保留其原始类别，不能伪装成“备份格式错误”。

### 7.5 merge 恢复流程与冲突政策

merge 在源包完成上述全部只读验证后，以 `VACUUM INTO` 创建并完整验证 `.pre-merge-*` 安全副本，
然后写 `restore_runs(started)`。实际导入在一个
SQLite 事务内完成；任一实体、外键、outbox 或审计明细失败，所有导入内容、provenance 和 conflict
一起回滚，原有用户实体始终不被 UPDATE/DELETE。

导入顺序与策略如下：

1. 文件夹先按 `normalized_name` 复用；仅 ID 相同但规范名不同才生成 UUID；
2. 事项、笔记及各自 document/current blocks 使用来源 UUID；若本地 ID 已占用且语义哈希不同，
   生成新 UUID 并写 `restore_conflicts(imported_with_new_uuid)`；ID 与哈希都相同则视为同一实体；
3. 提醒随事项 ID 重映射。已过期提醒统一标为 expired；active 事项的未来 scheduled 提醒创建
   新的 `scheduleReminder` pending outbox，绝不复用来源设备 notification registration；
4. 来源 Past 当前 blocks 逐块使用 provenance 判重，只追加未导入版本，并在本地 Past 中加
   “导入于 … · 来源 …”分隔；past event/part/anchor ledger 分别重映 UUID、append sequence、
   task/block/part 引用；无法解析的 current block 链接标为 orphaned；
5. 最近删除条目随 task/note/folder ID 重写；本地已经存在同一实体的 trash entry 时保留本地条目；
6. 当前 `app_settings`、backup target/encryption profile、notification registrations 与既有 outbox
   完全保留。merge 提交前删除来源或现有投影，并从合并后的权威 task/note/past 数据原子重建全部
   search_records；重复 merge 不产生陈旧或重复搜索结果。

`import_provenance(origin_dataset_id, entity_type, origin_entity_id, origin_hash)` 是幂等键。同一来源
实体同一版本再次 merge 会跳过；来源同一实体出现新语义哈希时作为新版本导入，不覆盖先前版本。
成功 audit 的 `summary_json` 记录各类型 imported/skipped 数、冲突数、安全副本名、Past 追加块数
及明确政策字段。

当前 merge 的有意边界：导入每份文档的当前 durable blocks，不复制 `document_revisions` 的设备内
撤销历史；新文档从 revision 0 开始。这样可避免 revision snapshot 内嵌旧 ID 在另一数据集发生
悬空或错误复写。来源事实仍由 Past snapshot/parts/anchors 与 provenance 保留。后续若要携带撤销
历史，必须先定义并测试 snapshot codec 的全量 ID 重写，不能直接复制 blob。

## 8. 迁移策略

当前首次公开基线为 `schemaVersion = 1`。发布后的每次结构变更必须：

1. 递增整数 schemaVersion，禁止在同一版本静默修改表结构；
2. 在 CI 保存并比较 Drift Schema 快照，评审生成 SQL；
3. 为每个相邻版本提供确定性的 `onUpgrade` 步骤，先加可空/带默认列，再分批回填，最后建立
   约束/索引；禁止依赖应用层“碰巧读取后修复”；
4. 迁移在事务内执行；大数据回填若必须分段，则用 app_meta 中的显式阶段标记支持断点续做；
5. 完成后运行 `foreign_key_check` 和最小 `quick_check`，并重建可派生的 search_records、平台 outbox；
6. 迁移测试至少覆盖：空库、典型数据、边界枚举、软删除数据、过往拆/合锚点、未来提醒、
   最大受支持旧版本逐级升级；
7. 不做自动降级。遇到高于当前应用支持的数据库或备份版本时只读拒绝并提示升级应用。

自动备份时间字段在首次发布前已纳入 v1：`auto_backup_hour_local` 默认 2，
`auto_backup_minute_local` 默认 0，并有范围 CHECK。若已有外部分发的 v1 数据库，则必须把该
变更改为 v2 migration，不能继续沿用版本号 1。

## 9. 数据保留、完整性与隐私

- 最近删除默认保留 30 天；仅到期清理或用户明确“永久删除”才物理删除。
- `document_revisions`、past source snapshot 和锚点来源默认长期保留，因为它们用于解释编辑来源；
  若未来做空间治理，应先生成可验证基线快照，再删除被覆盖修订。
- search_records、notification_registrations 和 platform_jobs 是可重建数据，不作为唯一事实来源。
- 备份/恢复审计默认保留；可以按数量清理旧成功记录，但失败记录应保留到用户确认问题解决。
- `.pre-restore-*` 是最后一道本地回滚保护。v1 不自动删除；后续清理策略必须至少保留最近一次
  成功恢复前副本，并在删除前确认当前数据库通过完整性检查。
- 数据库启用 foreign_keys、WAL、synchronous=FULL、5 秒 busy timeout 和 secure_delete=FAST。
  关键候选、快照、journal 与导出文件显式 flush、哈希并使用同目录 rename。由于 Dart 没有父目录
  fsync，本合同只达到 `process-crash-consistent`，不得宣称 sudden-power-loss safe；真实断电保持
  `power-loss-unverified`。损坏 live 的主文件及 sidecar 会移入同一唯一取证前缀；逐个移动期间再次
  崩溃可能只造成取证集合不完整，不会把未验证文件当作良好数据库，此低风险边界仍需设备验证。
- 每次 `databaseProvider` 生命周期只在仓储获得连接前执行一次完整 `integrity_check` 和 FK 检查，
  不在每次前后台切换重复扫描。即使普通无 journal 启动也不会把 `quick_check=ok`、但 UNIQUE 索引
  已损坏的 canonical live 数据库交给业务写入。
- 设备闹钟代际不新增 schema 或公开备份字段。v1.1.5 的成功 replace 审计在 `summary_json` 中写入
  与该行合法 UUID `id` 完全相同的 `alarmGeneration`；读取端只接受这种 succeeded replace 标记，
  v1.1.4 和任何无效/错配标记均回退到稳定的 `legacy:<dataset_id>`。replace 在候选库交换前生成新
  代际，merge 保持当前代际；portable snapshot 会剥离标记，因此 `.dgbak` 不会把源设备代际带到
  另一设备。journal 恢复选择旧 live 或新 candidate 时，也会自然选择对应数据库内的旧/新代际。
- 启动先以 no-follow 规则清理系统临时目录内四个精确 app-owned 明文根，再检查 Application
  Support 的 iOS 数据保护状态；保护策略 unavailable 不能让旧 staging 永久残留。
- 所有备份均包含用户正文和提醒内容，应按敏感个人数据处理。日志只允许记录 run ID、阶段、
  大小和稳定错误码，不记录标题、正文、口令、密钥、完整文件路径或 manifest 内容。

## 10. 最低测试矩阵

- Schema：22 表创建、默认设置/past singleton、全部 CHECK、唯一约束、级联/SET NULL/RESTRICT；
- 事务：在“加入过往”和块替换的每个写阶段注入失败，验证无半成品；
- 锚点：original、replacement、split、merged、全部删除、哈希变化和非法替换映射；
- 提醒：创建/修改/关闭/重开/软删除/恢复、dedupe、旧 revision、失败重试和权限拒绝；
- 搜索：中英文/日文/俄文大小写与空白规范化、软删除移除、恢复与过往编辑刷新；
- 设置：乐观锁、四种语言、字号边界、稍后提醒集合、备份时分 00:00/23:59 与越界拒绝；
- 保留：删除后第 29/30/31 天、时区变化、清理中断和文档外键顺序；
- 备份：未加密往返、加密往返、空/短/错口令、nonce/tag/密文/ZIP/数据库篡改、额外条目、
  解压炸弹声明、符号链接/type、central/local 不一致、读取前 stat 超限、写盘失败、并发互斥、
  全量 best-effort 清理和审计状态；
- 恢复：inspect 零 live 修改，错误 app/schema/dataset、完整 integrity/FK/记录数失败、能骗过
  quick_check 的索引损坏、staging 清理、WAL busy、journal/rename 前后故障、设备态清除、未来提醒
  outbox 与权威 search_records 重建和 provider 重新打开；merge
  空库全实体、设置保留、同 ID 异 hash 不覆盖、normalized folder 复用、Past 分隔与 anchor 重映、
  provenance 重复幂等、安全副本、成功/失败审计及事务故障注入；
- 迁移：每个已发布版本到当前版本，并在迁移后执行仓储行为测试而不只比较表结构。
