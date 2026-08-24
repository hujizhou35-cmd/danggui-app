import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/data_support.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/repositories/core_repositories.dart';
import '../domain/models.dart';
import '../services/notifications/notification_coordinator.dart';
import 'app_state.dart';

export '../data/database_provider.dart';

final appStoreProvider =
    AsyncNotifierProvider<AppStoreController, DangguiAppState>(
      AppStoreController.new,
    );

final class AppStoreController extends AsyncNotifier<DangguiAppState> {
  static const _uuid = Uuid();

  @override
  Future<DangguiAppState> build() async {
    final database = await ref.watch(databaseProvider.future);
    return _readState(database);
  }

  Future<void> refresh() async {
    final database = await ref.read(databaseProvider.future);
    state = AsyncData(await _readState(database));
  }

  Future<void> _completeTaskMutation(bool notificationJobQueued) async {
    if (notificationJobQueued) {
      try {
        // The SQLite transaction is already committed. Await the durable
        // outbox drain so an old platform alarm cannot survive a user-visible
        // edit, close, archive, or delete operation.
        await ref.read(notificationCoordinatorProvider).reconcile();
      } on Object catch (error, stackTrace) {
        // Platform/plugin failures must never roll back or make an editor
        // report that its local data was not saved. The durable job remains
        // pending for foreground/startup reconciliation.
        if (kDebugMode) {
          debugPrint('Notification outbox drain failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
    // Reconciliation may update the persisted permission/expiry state.
    await refresh();
  }

  void setSearchQuery(String value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(searchQuery: value));
  }

  Future<void> reorderTasks(List<String> orderedIds) async {
    final database = await ref.read(databaseProvider.future);
    final currentRows = await database
        .customSelect(
          'SELECT id FROM tasks WHERE status IN (?, ?) '
          'ORDER BY manual_rank, id',
          variables: <Variable<Object>>[
            Variable.withString(TaskStatus.active.name),
            Variable.withString(TaskStatus.completionPending.name),
          ],
        )
        .get();
    final currentIds = currentRows
        .map((row) => row.read<String>('id'))
        .toList(growable: false);
    if (currentIds.length != orderedIds.length ||
        currentIds.toSet().difference(orderedIds.toSet()).isNotEmpty) {
      throw StateError('Task order changed while it was being edited.');
    }
    final nowMicros = utcMicros(DateTime.now());
    await database.transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await database.customStatement(
          'UPDATE tasks SET manual_rank = ?, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE id = ?',
          <Object?>[(index + 1) * 1024, nowMicros, orderedIds[index]],
        );
      }
    });
    await refresh();
  }

  Future<String> createTask({
    required String title,
    DateTime? dueDate,
    String plan = '',
    String body = '',
    DateTime? reminderAt,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const FormatException('Task title must not be empty.');
    }
    final database = await ref.read(databaseProvider.future);
    var resolvedSound = soundEnabled;
    var resolvedVibration = vibrationEnabled;
    if (reminderAt != null &&
        (resolvedSound == null || resolvedVibration == null)) {
      final defaults = await database
          .customSelect(
            'SELECT default_sound_enabled, default_vibration_enabled '
            'FROM app_settings WHERE id = 1',
          )
          .getSingle();
      resolvedSound ??= defaults.read<bool>('default_sound_enabled');
      resolvedVibration ??= defaults.read<bool>('default_vibration_enabled');
    }
    final taskId = _uuid.v4();
    final documentId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final nowMicros = utcMicros(now);
    var notificationJobQueued = false;
    final semanticHash = await sha256Hex(<String, Object?>{
      'title': cleanTitle,
      'dueDate': _isoDate(dueDate),
      'plan': plan,
      'body': body,
    });
    await database.transaction(() async {
      final rankRow = await database
          .customSelect(
            'SELECT COALESCE(MAX(manual_rank), 0) + 1024 AS next_rank '
            'FROM tasks WHERE status IN (?, ?)',
            variables: <Variable<Object>>[
              Variable.withString(TaskStatus.active.name),
              Variable.withString(TaskStatus.completionPending.name),
            ],
          )
          .getSingle();
      final rank = rankRow.read<int>('next_rank');
      await database.customStatement(
        'INSERT INTO documents '
        '(id, kind, singleton_key, format_version, revision, semantic_hash, '
        'created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
        <Object?>[
          documentId,
          DocumentKind.taskBody.name,
          semanticHash,
          nowMicros,
          nowMicros,
        ],
      );
      await database.customStatement(
        'INSERT INTO tasks '
        '(id, document_id, title, due_local_date, plan_text, status, '
        'manual_rank, semantic_hash, created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          taskId,
          documentId,
          cleanTitle,
          _isoDate(dueDate),
          plan,
          TaskStatus.active.name,
          rank,
          semanticHash,
          nowMicros,
          nowMicros,
        ],
      );
      if (body.trim().isNotEmpty) {
        await _insertBlock(
          database,
          documentId: documentId,
          type: DocumentBlockType.paragraph,
          text: body,
          sortRank: 1024,
          nowMicros: nowMicros,
        );
      }
      await _upsertSearch(
        database,
        scope: SearchScope.task,
        entityId: taskId,
        documentId: documentId,
        title: cleanTitle,
        body: '$plan\n$body',
        dateKey: _isoDate(dueDate) ?? '',
        nowMicros: nowMicros,
      );
      if (reminderAt != null) {
        notificationJobQueued = await _writeReminder(
          database,
          taskId: taskId,
          taskStatus: TaskStatus.active,
          reminderAt: reminderAt,
          soundEnabled: resolvedSound ?? true,
          vibrationEnabled: resolvedVibration ?? true,
          nowMicros: nowMicros,
        );
      }
    });
    await _completeTaskMutation(notificationJobQueued);
    return taskId;
  }

  Future<void> updateTask(
    TaskViewModel task, {
    bool updateReminder = true,
  }) async {
    final cleanTitle = task.title.trim();
    if (cleanTitle.isEmpty) {
      throw const FormatException('Task title must not be empty.');
    }
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    var notificationJobQueued = false;
    final semanticHash = await sha256Hex(<String, Object?>{
      'title': cleanTitle,
      'dueDate': _isoDate(task.dueDate),
      'plan': task.plan,
      'body': task.body,
    });
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT document_id, status, title, plan_text FROM tasks '
            'WHERE id = ?',
            variables: <Variable<Object>>[Variable.withString(task.id)],
          )
          .getSingleOrNull();
      if (row == null) throw StateError('Task no longer exists.');
      final documentId = row.read<String>('document_id');
      final persistedTaskStatus = _enumByName(
        TaskStatus.values,
        row.read<String>('status'),
        TaskStatus.active,
      );
      final notificationContentChanged =
          row.read<String>('title') != cleanTitle ||
          row.read<String>('plan_text') != task.plan;
      await _snapshotDocument(database, documentId, nowMicros);
      await database.customStatement(
        'UPDATE tasks SET title = ?, due_local_date = ?, plan_text = ?, '
        'semantic_hash = ?, updated_at_utc = ?, row_version = row_version + 1 '
        'WHERE id = ?',
        <Object?>[
          cleanTitle,
          _isoDate(task.dueDate),
          task.plan,
          semanticHash,
          nowMicros,
          task.id,
        ],
      );
      await _replaceDocumentText(
        database,
        documentId: documentId,
        text: task.body,
        nowMicros: nowMicros,
      );
      if (updateReminder) {
        if (task.reminderAt == null) {
          notificationJobQueued = await _cancelReminder(
            database,
            task.id,
            nowMicros,
          );
        } else {
          notificationJobQueued = await _writeReminder(
            database,
            taskId: task.id,
            taskStatus: persistedTaskStatus,
            reminderAt: task.reminderAt!,
            soundEnabled: task.soundEnabled,
            vibrationEnabled: task.vibrationEnabled,
            nowMicros: nowMicros,
          );
        }
      } else if (notificationContentChanged) {
        final reminderChanged = await database.customUpdate(
          'UPDATE reminders SET schedule_revision = schedule_revision + 1, '
          'updated_at_utc = ?, row_version = row_version + 1 '
          'WHERE task_id = ? AND status = ? AND scheduled_at_utc > ?',
          variables: <Variable<Object>>[
            Variable.withInt(nowMicros),
            Variable.withString(task.id),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withInt(nowMicros),
          ],
          updates: <TableInfo<Table, Object?>>{database.reminders},
        );
        if (reminderChanged > 0) {
          notificationJobQueued = await _queueReminderJob(
            database,
            taskId: task.id,
            kind: PlatformJobKind.refreshReminderLocale,
            nowMicros: nowMicros,
          );
        }
      }
      await _upsertSearch(
        database,
        scope: SearchScope.task,
        entityId: task.id,
        documentId: documentId,
        title: cleanTitle,
        body: '${task.plan}\n${task.body}',
        dateKey: _isoDate(task.dueDate) ?? '',
        nowMicros: nowMicros,
      );
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<void> setTaskActive(String taskId, bool active) async {
    final database = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    final nowMicros = utcMicros(now);
    var notificationJobQueued = false;
    await database.transaction(() async {
      if (!active) {
        await database.customStatement(
          'UPDATE tasks SET status = ?, closed_at_utc = ?, '
          'closed_local_date = ?, closed_local_time = ?, closed_zone_id = ?, '
          'updated_at_utc = ?, row_version = row_version + 1 '
          'WHERE id = ? AND status = ?',
          <Object?>[
            TaskStatus.completionPending.name,
            nowMicros,
            _isoDate(now),
            _localTime(now),
            now.timeZoneName,
            nowMicros,
            taskId,
            TaskStatus.active.name,
          ],
        );
        final reminderChanged = await database.customUpdate(
          'UPDATE reminders SET status = ?, pause_reason = ?, '
          'schedule_revision = schedule_revision + 1, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE task_id = ? AND status <> ?',
          variables: <Variable<Object>>[
            Variable.withString(ReminderStatus.paused.name),
            Variable.withString(ReminderPauseReason.taskClosed.name),
            Variable.withInt(nowMicros),
            Variable.withString(taskId),
            Variable.withString(ReminderStatus.cancelled.name),
          ],
          updates: <TableInfo<Table, Object?>>{database.reminders},
        );
        if (reminderChanged > 0) {
          notificationJobQueued = await _queueReminderJob(
            database,
            taskId: taskId,
            kind: PlatformJobKind.cancelReminder,
            nowMicros: nowMicros,
          );
        }
      } else {
        await database.customStatement(
          'UPDATE tasks SET status = ?, closed_at_utc = NULL, '
          'closed_local_date = NULL, closed_local_time = NULL, '
          'closed_zone_id = NULL, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE id = ? AND status = ?',
          <Object?>[
            TaskStatus.active.name,
            nowMicros,
            taskId,
            TaskStatus.completionPending.name,
          ],
        );
        final reminderChanged = await database.customUpdate(
          'UPDATE reminders SET status = CASE WHEN scheduled_at_utc > ? '
          'THEN ? ELSE ? END, pause_reason = NULL, '
          'schedule_revision = schedule_revision + 1, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE task_id = ? AND status = ? '
          'AND pause_reason = ?',
          variables: <Variable<Object>>[
            Variable.withInt(nowMicros),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withString(ReminderStatus.expired.name),
            Variable.withInt(nowMicros),
            Variable.withString(taskId),
            Variable.withString(ReminderStatus.paused.name),
            Variable.withString(ReminderPauseReason.taskClosed.name),
          ],
          updates: <TableInfo<Table, Object?>>{database.reminders},
        );
        if (reminderChanged > 0) {
          notificationJobQueued = await _queueReminderJob(
            database,
            taskId: taskId,
            kind: PlatformJobKind.scheduleReminder,
            nowMicros: nowMicros,
            onlyIfFuture: true,
          );
        }
      }
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<void> addTaskToPast(String taskId) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    var notificationJobQueued = false;
    await database.transaction(() async {
      final task = await database
          .customSelect(
            'SELECT * FROM tasks WHERE id = ? AND status = ?',
            variables: <Variable<Object>>[
              Variable.withString(taskId),
              Variable.withString(TaskStatus.completionPending.name),
            ],
          )
          .getSingleOrNull();
      if (task == null) throw StateError('Task is not pending completion.');
      final pastDocument = await database
          .customSelect(
            'SELECT id, revision FROM documents WHERE singleton_key = ?',
            variables: <Variable<Object>>[Variable.withString('past.main')],
          )
          .getSingle();
      final pastDocumentId = pastDocument.read<String>('id');
      final taskDocumentId = task.read<String>('document_id');
      final sourceBlocks = await database
          .customSelect(
            'SELECT plain_text, block_type, is_checked FROM document_blocks '
            'WHERE document_id = ? ORDER BY sort_rank, id',
            variables: <Variable<Object>>[Variable.withString(taskDocumentId)],
          )
          .get();
      final sequenceRow = await database
          .customSelect(
            'SELECT COALESCE(MAX(append_sequence), 0) + 1 AS sequence '
            'FROM past_events',
          )
          .getSingle();
      final sequence = sequenceRow.read<int>('sequence');
      final completionDate =
          task.readNullable<String>('closed_local_date') ??
          _isoDate(DateTime.now())!;
      final completionZone =
          task.readNullable<String>('closed_zone_id') ??
          DateTime.now().timeZoneName;
      final completedAt = task.readNullable<int>('closed_at_utc') ?? nowMicros;
      final lastEvent = await database
          .customSelect(
            'SELECT completion_local_date FROM past_events '
            'ORDER BY append_sequence DESC LIMIT 1',
          )
          .getSingleOrNull();
      final rankRow = await database
          .customSelect(
            'SELECT COALESCE(MAX(sort_rank), 0) AS rank FROM document_blocks '
            'WHERE document_id = ?',
            variables: <Variable<Object>>[Variable.withString(pastDocumentId)],
          )
          .getSingle();
      var rank = rankRow.read<int>('rank');
      if (lastEvent?.read<String>('completion_local_date') != completionDate) {
        rank += 1024;
        await _insertBlock(
          database,
          documentId: pastDocumentId,
          type: DocumentBlockType.pastDate,
          text: completionDate,
          sortRank: rank,
          nowMicros: nowMicros,
        );
      }
      final eventId = _uuid.v4();
      final completionTime =
          task.readNullable<String>('closed_local_time') ??
          _localTime(
            DateTime.fromMicrosecondsSinceEpoch(
              completedAt,
              isUtc: true,
            ).toLocal(),
          );
      final timeBlockId = _uuid.v4();
      rank += 1024;
      await _insertBlock(
        database,
        id: timeBlockId,
        documentId: pastDocumentId,
        type: DocumentBlockType.pastEntry,
        text: completionTime,
        sortRank: rank,
        nowMicros: nowMicros,
      );
      final titleBlockId = _uuid.v4();
      rank += 1024;
      await _insertBlock(
        database,
        id: titleBlockId,
        documentId: pastDocumentId,
        type: DocumentBlockType.pastEntry,
        text: task.read<String>('title'),
        sortRank: rank,
        nowMicros: nowMicros,
      );
      final linked = <({String blockId, PastPartRole role, String text})>[
        (blockId: timeBlockId, role: PastPartRole.time, text: completionTime),
        (
          blockId: titleBlockId,
          role: PastPartRole.title,
          text: task.read<String>('title'),
        ),
      ];
      for (final source in sourceBlocks) {
        final text = source.read<String>('plain_text');
        if (text.trim().isEmpty) continue;
        final blockId = _uuid.v4();
        rank += 1024;
        final typeName = source.read<String>('block_type');
        final type = DocumentBlockType.values.firstWhere(
          (value) => value.name == typeName,
          orElse: () => DocumentBlockType.paragraph,
        );
        await _insertBlock(
          database,
          id: blockId,
          documentId: pastDocumentId,
          type: type == DocumentBlockType.checklist
              ? DocumentBlockType.checklist
              : DocumentBlockType.pastEntry,
          text: text,
          isChecked: source.readNullable<bool>('is_checked'),
          sortRank: rank,
          nowMicros: nowMicros,
        );
        linked.add((
          blockId: blockId,
          role: type == DocumentBlockType.checklist
              ? PastPartRole.checklist
              : PastPartRole.body,
          text: text,
        ));
      }
      final dueDate = task.readNullable<String>('due_local_date');
      if (dueDate != null) {
        final blockId = _uuid.v4();
        final text = '📅 $dueDate';
        rank += 1024;
        await _insertBlock(
          database,
          id: blockId,
          documentId: pastDocumentId,
          type: DocumentBlockType.paragraph,
          text: text,
          sortRank: rank,
          nowMicros: nowMicros,
        );
        linked.add((blockId: blockId, role: PastPartRole.dueDate, text: text));
      }
      final sourcePlan = task.read<String>('plan_text').trim();
      if (sourcePlan.isNotEmpty) {
        final blockId = _uuid.v4();
        rank += 1024;
        await _insertBlock(
          database,
          id: blockId,
          documentId: pastDocumentId,
          type: DocumentBlockType.paragraph,
          text: sourcePlan,
          sortRank: rank,
          nowMicros: nowMicros,
        );
        linked.add((
          blockId: blockId,
          role: PastPartRole.plan,
          text: sourcePlan,
        ));
      }
      final snapshot = <String, Object?>{
        'taskId': taskId,
        'title': task.read<String>('title'),
        'dueDate': task.readNullable<String>('due_local_date'),
        'plan': task.read<String>('plan_text'),
        'blocks': <Object?>[for (final source in sourceBlocks) source.data],
      };
      final snapshotJson = canonicalJson(snapshot);
      final snapshotHash = await sha256Hex(snapshot);
      await database.customStatement(
        'INSERT INTO past_events '
        '(id, document_id, source_task_id, append_sequence, completed_at_utc, '
        'completion_local_date, completion_zone_id, source_snapshot_version, '
        'source_snapshot_json, source_sha256, anchor_state, created_at_utc, '
        'updated_at_utc, row_version) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          eventId,
          pastDocumentId,
          taskId,
          sequence,
          completedAt,
          completionDate,
          completionZone,
          snapshotJson,
          snapshotHash,
          PastAnchorState.attached.name,
          nowMicros,
          nowMicros,
        ],
      );
      for (var index = 0; index < linked.length; index++) {
        final item = linked[index];
        final partId = _uuid.v4();
        final partHash = await sha256Hex(item.text);
        await database.customStatement(
          'INSERT INTO past_event_parts '
          '(id, event_id, role, source_order, original_payload_json, '
          'original_plain_text, original_sha256) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            partId,
            eventId,
            item.role.name,
            index,
            '{}',
            item.text,
            partHash,
          ],
        );
        await database.customStatement(
          'INSERT INTO past_anchor_links '
          '(id, part_id, current_block_id, last_known_block_id, relation, '
          'link_state, current_sha256, updated_at_utc) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            _uuid.v4(),
            partId,
            item.blockId,
            item.blockId,
            AnchorRelation.original.name,
            AnchorLinkState.linked.name,
            partHash,
            nowMicros,
          ],
        );
      }
      final pastHash = await sha256Hex(<String, Object?>{
        'event': snapshot,
        'completionDate': completionDate,
        'completionTime': completionTime,
      });
      await database.customStatement(
        'UPDATE documents SET revision = revision + 1, semantic_hash = ?, '
        'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
        <Object?>[pastHash, nowMicros, pastDocumentId],
      );
      final pastTextRows = await database
          .customSelect(
            'SELECT plain_text FROM document_blocks WHERE document_id = ? '
            'ORDER BY sort_rank, id',
            variables: <Variable<Object>>[Variable.withString(pastDocumentId)],
          )
          .get();
      await _upsertSearch(
        database,
        scope: SearchScope.past,
        entityId: 'past.main',
        documentId: pastDocumentId,
        title: '',
        body: pastTextRows
            .map((row) => row.read<String>('plain_text'))
            .join('\n'),
        dateKey: completionDate,
        nowMicros: nowMicros,
      );
      await database.customStatement(
        'UPDATE tasks SET status = ?, archived_at_utc = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id = ?',
        <Object?>[TaskStatus.archived.name, nowMicros, nowMicros, taskId],
      );
      notificationJobQueued = await _cancelReminder(
        database,
        taskId,
        nowMicros,
      );
      await database.customStatement(
        'DELETE FROM search_records WHERE scope = ? AND entity_id = ?',
        <Object?>[SearchScope.task.name, taskId],
      );
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<void> deleteTask(String taskId) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    final purgeMicros = nowMicros + const Duration(days: 30).inMicroseconds;
    var notificationJobQueued = false;
    await database.transaction(() async {
      final task = await database
          .customSelect(
            'SELECT status, title FROM tasks WHERE id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (task == null) return;
      final previousStatus = task.read<String>('status');
      final snapshot = <String, Object?>{
        'title': task.read<String>('title'),
        'status': previousStatus,
      };
      await database.customStatement(
        'UPDATE tasks SET status = ?, deleted_at_utc = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id = ?',
        <Object?>[TaskStatus.trashed.name, nowMicros, nowMicros, taskId],
      );
      await database.customStatement(
        'INSERT OR REPLACE INTO trash_entries '
        '(id, entity_type, entity_id, deleted_at_utc, purge_after_utc, '
        'restore_context_json, snapshot_sha256) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          _uuid.v4(),
          TrashEntityType.task.name,
          taskId,
          nowMicros,
          purgeMicros,
          canonicalJson(<String, Object?>{'status': previousStatus}),
          await sha256Hex(snapshot),
        ],
      );
      notificationJobQueued = await _pauseReminderForTrash(
        database,
        taskId,
        nowMicros,
      );
      await database.customStatement(
        'DELETE FROM search_records WHERE scope = ? AND entity_id = ?',
        <Object?>[SearchScope.task.name, taskId],
      );
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<void> restoreTask(String taskId) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    var notificationJobQueued = false;
    await database.transaction(() async {
      final trash = await database
          .customSelect(
            'SELECT id, restore_context_json FROM trash_entries '
            'WHERE entity_type = ? AND entity_id = ?',
            variables: <Variable<Object>>[
              Variable.withString(TrashEntityType.task.name),
              Variable.withString(taskId),
            ],
          )
          .getSingleOrNull();
      if (trash == null) return;
      final context = jsonDecode(
        trash.read<String>('restore_context_json'),
      ) as Map<String, Object?>;
      final statusName = context['status']?.toString();
      final restoredStatus = statusName == TaskStatus.completionPending.name
          ? TaskStatus.completionPending
          : TaskStatus.active;
      await database.customStatement(
        'UPDATE tasks SET status = ?, deleted_at_utc = NULL, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id = ?',
        <Object?>[restoredStatus.name, nowMicros, taskId],
      );
      await database.customStatement(
        'DELETE FROM trash_entries WHERE id = ?',
        <Object?>[trash.read<String>('id')],
      );
      final reminder = await database
          .customSelect(
            'SELECT id, status, pause_reason, scheduled_at_utc, '
            'schedule_revision FROM reminders WHERE task_id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (reminder != null &&
          reminder.read<String>('status') == ReminderStatus.paused.name &&
          reminder.readNullable<String>('pause_reason') ==
              ReminderPauseReason.user.name) {
        final shouldSchedule =
            restoredStatus == TaskStatus.active &&
            reminder.read<int>('scheduled_at_utc') > nowMicros;
        final reminderStatus = shouldSchedule
            ? ReminderStatus.scheduled
            : restoredStatus == TaskStatus.completionPending
            ? ReminderStatus.paused
            : ReminderStatus.expired;
        final pauseReason = restoredStatus == TaskStatus.completionPending
            ? ReminderPauseReason.taskClosed.name
            : null;
        await database.customStatement(
          'UPDATE reminders SET status = ?, pause_reason = ?, '
          'schedule_revision = schedule_revision + 1, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE id = ?',
          <Object?>[
            reminderStatus.name,
            pauseReason,
            nowMicros,
            reminder.read<String>('id'),
          ],
        );
        if (shouldSchedule) {
          notificationJobQueued = await _queueReminderJob(
            database,
            taskId: taskId,
            kind: PlatformJobKind.scheduleReminder,
            nowMicros: nowMicros,
          );
        }
      }
      final restoredTask = await database
          .customSelect(
            'SELECT document_id, title, plan_text, due_local_date FROM tasks '
            'WHERE id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingle();
      final documentId = restoredTask.read<String>('document_id');
      final bodyRows = await database
          .customSelect(
            'SELECT plain_text FROM document_blocks WHERE document_id = ? '
            'ORDER BY sort_rank, id',
            variables: <Variable<Object>>[Variable.withString(documentId)],
          )
          .get();
      await _upsertSearch(
        database,
        scope: SearchScope.task,
        entityId: taskId,
        documentId: documentId,
        title: restoredTask.read<String>('title'),
        body:
            '${restoredTask.read<String>('plan_text')}\n'
            '${bodyRows.map((row) => row.read<String>('plain_text')).join('\n')}',
        dateKey: restoredTask.readNullable<String>('due_local_date') ?? '',
        nowMicros: nowMicros,
      );
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<String> createNote({
    String title = '',
    String body = '',
    String? folderId,
  }) async {
    final database = await ref.read(databaseProvider.future);
    final noteId = _uuid.v4();
    final documentId = _uuid.v4();
    final nowMicros = utcMicros(DateTime.now());
    final semanticHash = await sha256Hex(<String, Object?>{
      'title': title,
      'body': body,
      'folderId': folderId,
    });
    await database.transaction(() async {
      await database.customStatement(
        'INSERT INTO documents '
        '(id, kind, singleton_key, format_version, revision, semantic_hash, '
        'created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
        <Object?>[
          documentId,
          DocumentKind.note.name,
          semanticHash,
          nowMicros,
          nowMicros,
        ],
      );
      await database.customStatement(
        'INSERT INTO notes '
        '(id, document_id, folder_id, title, semantic_hash, created_at_utc, '
        'updated_at_utc, row_version) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          noteId,
          documentId,
          folderId,
          title.trim(),
          semanticHash,
          nowMicros,
          nowMicros,
        ],
      );
      if (body.isNotEmpty) {
        await _insertBlock(
          database,
          documentId: documentId,
          type: DocumentBlockType.paragraph,
          text: body,
          sortRank: 1024,
          nowMicros: nowMicros,
        );
      }
      await _upsertSearch(
        database,
        scope: SearchScope.note,
        entityId: noteId,
        documentId: documentId,
        title: title,
        body: body,
        dateKey: '',
        nowMicros: nowMicros,
      );
    });
    await refresh();
    return noteId;
  }

  Future<void> updateNote(NoteViewModel note) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    final semanticHash = await sha256Hex(<String, Object?>{
      'title': note.title,
      'body': note.body,
      'folderId': note.folderId,
      'pinned': note.pinned,
    });
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT document_id FROM notes WHERE id = ? AND deleted_at_utc IS NULL',
            variables: <Variable<Object>>[Variable.withString(note.id)],
          )
          .getSingleOrNull();
      if (row == null) throw StateError('Note no longer exists.');
      final documentId = row.read<String>('document_id');
      await _snapshotDocument(database, documentId, nowMicros);
      await database.customStatement(
        'UPDATE notes SET title = ?, folder_id = ?, pinned_at_utc = ?, '
        'semantic_hash = ?, updated_at_utc = ?, row_version = row_version + 1 '
        'WHERE id = ?',
        <Object?>[
          note.title.trim(),
          note.folderId,
          note.pinned ? nowMicros : null,
          semanticHash,
          nowMicros,
          note.id,
        ],
      );
      await _replaceDocumentText(
        database,
        documentId: documentId,
        text: note.body,
        nowMicros: nowMicros,
      );
      await _upsertSearch(
        database,
        scope: SearchScope.note,
        entityId: note.id,
        documentId: documentId,
        title: note.title,
        body: note.body,
        dateKey: '',
        nowMicros: nowMicros,
      );
    });
    await refresh();
  }

  Future<void> deleteNote(String noteId) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT folder_id, pinned_at_utc FROM notes WHERE id = ?',
            variables: <Variable<Object>>[Variable.withString(noteId)],
          )
          .getSingleOrNull();
      if (row == null) return;
      await database.customStatement(
        'UPDATE notes SET deleted_at_utc = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id = ?',
        <Object?>[nowMicros, nowMicros, noteId],
      );
      await database.customStatement(
        'INSERT OR REPLACE INTO trash_entries '
        '(id, entity_type, entity_id, deleted_at_utc, purge_after_utc, '
        'restore_context_json, snapshot_sha256) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          _uuid.v4(),
          TrashEntityType.note.name,
          noteId,
          nowMicros,
          nowMicros + const Duration(days: 30).inMicroseconds,
          canonicalJson(<String, Object?>{
            'folderId': row.readNullable<String>('folder_id'),
            'pinned': row.readNullable<int>('pinned_at_utc') != null,
          }),
          await sha256Hex(noteId),
        ],
      );
      await database.customStatement(
        'DELETE FROM search_records WHERE scope = ? AND entity_id = ?',
        <Object?>[SearchScope.note.name, noteId],
      );
    });
    await refresh();
  }

  Future<String> createFolder(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FormatException('Folder name is empty.');
    final database = await ref.read(databaseProvider.future);
    final id = _uuid.v4();
    final nowMicros = utcMicros(DateTime.now());
    final rank = state.value?.folders.length ?? 0;
    await database.customStatement(
      'INSERT INTO folders '
      '(id, name, normalized_name, sort_rank, created_at_utc, updated_at_utc, '
      'row_version) VALUES (?, ?, ?, ?, ?, ?, 1)',
      <Object?>[
        id,
        cleanName,
        cleanName.toLowerCase(),
        (rank + 1) * 1024,
        nowMicros,
        nowMicros,
      ],
    );
    await refresh();
    return id;
  }

  Future<void> deleteFolder(String folderId) async {
    final database = await ref.read(databaseProvider.future);
    await database.transaction(() async {
      await database.customStatement(
        'UPDATE notes SET folder_id = NULL WHERE folder_id = ?',
        <Object?>[folderId],
      );
      await database.customStatement(
        'DELETE FROM folders WHERE id = ?',
        <Object?>[folderId],
      );
    });
    await refresh();
  }

  Future<void> updatePastBlock(String blockId, String text) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT document_id FROM document_blocks WHERE id = ?',
            variables: <Variable<Object>>[Variable.withString(blockId)],
          )
          .getSingleOrNull();
      if (row == null) return;
      final documentId = row.read<String>('document_id');
      await _snapshotDocument(database, documentId, nowMicros);
      final hash = await sha256Hex(text);
      await database.customStatement(
        'UPDATE document_blocks SET plain_text = ?, semantic_hash = ?, '
        'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
        <Object?>[text, hash, nowMicros, blockId],
      );
      await database.customStatement(
        'UPDATE past_events SET anchor_state = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id IN '
        '(SELECT pep.event_id FROM past_event_parts pep '
        'JOIN past_anchor_links pal ON pal.part_id = pep.id '
        'WHERE pal.current_block_id = ?)',
        <Object?>[PastAnchorState.modified.name, nowMicros, blockId],
      );
      await database.customStatement(
        'UPDATE past_anchor_links SET current_sha256 = ?, updated_at_utc = ? '
        'WHERE current_block_id = ?',
        <Object?>[hash, nowMicros, blockId],
      );
      final allBlocks = await database
          .customSelect(
            'SELECT plain_text FROM document_blocks WHERE document_id = ? '
            'ORDER BY sort_rank, id',
            variables: <Variable<Object>>[Variable.withString(documentId)],
          )
          .get();
      final body = allBlocks
          .map((item) => item.read<String>('plain_text'))
          .join('\n');
      await database.customStatement(
        'UPDATE documents SET revision = revision + 1, semantic_hash = ?, '
        'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
        <Object?>[await sha256Hex(body), nowMicros, documentId],
      );
      final latestDate = await database
          .customSelect(
            'SELECT completion_local_date FROM past_events '
            'ORDER BY append_sequence DESC LIMIT 1',
          )
          .getSingleOrNull();
      await _upsertSearch(
        database,
        scope: SearchScope.past,
        entityId: 'past.main',
        documentId: documentId,
        title: '',
        body: body,
        dateKey: latestDate?.read<String>('completion_local_date') ?? '',
        nowMicros: nowMicros,
      );
    });
    await refresh();
  }

  /// Replaces the editable Past document while preserving stable block ids
  /// around the changed range and recording explicit split/merge mappings for
  /// provenance anchors inside that range.
  Future<PastEditorDocumentViewModel> replacePastEditorDocument(
    PastEditorDraft draft,
  ) async {
    final database = await ref.read(databaseProvider.future);
    final document = await database
        .customSelect(
          'SELECT id, revision FROM documents WHERE singleton_key = ?',
          variables: <Variable<Object>>[Variable.withString('past.main')],
        )
        .getSingle();
    final documentId = document.read<String>('id');
    final currentRevision = document.read<int>('revision');
    final serializedBase = _serializePastEditorSegments(draft.baseSegments);
    if (serializedBase != draft.baseText) {
      throw const ValidationException('过往编辑基线无效。');
    }
    if (draft.text == draft.baseText) {
      if (state.value?.pastDocument.revision != currentRevision) {
        await refresh();
      }
      return state.requireValue.pastDocument;
    }
    if (currentRevision != draft.baseRevision) {
      throw const StateConflictException('过往已在其他操作中更新。');
    }

    final oldRows = await database
        .customSelect(
          'SELECT id, parent_block_id, sort_rank, block_type, plain_text, '
          'payload_json, attributes_json, is_checked FROM document_blocks '
          'WHERE document_id = ? ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .get();
    final oldById = <String, QueryRow>{
      for (final row in oldRows) row.read<String>('id'): row,
    };
    final projectedBlockIds = <String>[];
    for (final segment in draft.baseSegments) {
      projectedBlockIds.addAll(segment.sourceBlockIds);
    }
    if (projectedBlockIds.length != projectedBlockIds.toSet().length ||
        projectedBlockIds.toSet().difference(oldById.keys.toSet()).isNotEmpty ||
        oldById.keys.toSet().difference(projectedBlockIds.toSet()).isNotEmpty) {
      throw const StateConflictException('过往编辑基线与当前文档不一致。');
    }

    final editedLines = _parsePastProjectedLines(draft.text);
    final matches = _matchPastProjectionLines(draft.baseSegments, editedLines);
    final matchedBaseIndexes = matches.values.toSet();
    if (matches.length == editedLines.length &&
        matchedBaseIndexes.length == draft.baseSegments.length &&
        matches.entries.every((match) => match.key == match.value)) {
      // The user only changed synthetic whitespace between projected rows.
      // Keep the database untouched and return the canonical projection.
      return state.requireValue.pastDocument;
    }

    final oldModels = <String, DocumentBlockModel>{
      for (final row in oldRows)
        row.read<String>('id'): _pastDocumentBlockFromRow(row, documentId),
    };
    final newBlocksByLine = <int, DocumentBlockModel>{};
    final unmatchedLineIndexes = <int>[
      for (var index = 0; index < editedLines.length; index++)
        if (!matches.containsKey(index)) index,
    ];
    for (final lineIndex in unmatchedLineIndexes) {
      final parsed = _parsePastProjectedLine(editedLines[lineIndex]);
      newBlocksByLine[lineIndex] = DocumentBlockModel(
        id: _uuid.v4(),
        documentId: DocumentId(documentId),
        sortRank: 0,
        blockType: parsed.type,
        plainText: parsed.text,
        isChecked: parsed.isChecked,
      );
    }

    final unmatchedBaseIndexes = <int>[
      for (var index = 0; index < draft.baseSegments.length; index++)
        if (!matchedBaseIndexes.contains(index)) index,
    ];
    final replacementLineByBase = _matchPastReplacementSegments(
      baseSegments: draft.baseSegments,
      editedLines: editedLines,
      unmatchedBaseIndexes: unmatchedBaseIndexes,
      unmatchedLineIndexes: unmatchedLineIndexes,
    );
    final replacements = <String, List<String>>{};
    for (final baseIndex in unmatchedBaseIndexes) {
      final segment = draft.baseSegments[baseIndex];
      final replacementLine = replacementLineByBase[baseIndex];
      final targets = replacementLine == null
          ? const <String>[]
          : <String>[newBlocksByLine[replacementLine]!.id];
      for (final sourceBlockId in segment.sourceBlockIds) {
        replacements[sourceBlockId] = targets;
      }
    }

    final blocks = <DocumentBlockModel>[];
    var nextSortRank = 1024;
    for (var index = 0; index < editedLines.length; index++) {
      final baseIndex = matches[index];
      if (baseIndex == null) {
        blocks.add(
          _pastDocumentBlockWithRank(newBlocksByLine[index]!, nextSortRank),
        );
        nextSortRank += 1024;
        continue;
      }
      for (final blockId in draft.baseSegments[baseIndex].sourceBlockIds) {
        blocks.add(
          _pastDocumentBlockWithRank(oldModels[blockId]!, nextSortRank),
        );
        nextSortRank += 1024;
      }
    }
    await DriftDocumentRepository(database).replaceBlocks(
      DocumentId(documentId),
      blocks,
      expectedRevision: currentRevision,
      replacements: replacements,
    );
    await refresh();
    return state.requireValue.pastDocument;
  }

  Future<void> replacePastDocumentText(String text) async {
    final database = await ref.read(databaseProvider.future);
    final document = await database
        .customSelect(
          'SELECT id, revision FROM documents WHERE singleton_key = ?',
          variables: <Variable<Object>>[Variable.withString('past.main')],
        )
        .getSingle();
    final documentId = document.read<String>('id');
    final revision = document.read<int>('revision');
    final oldRows = await database
        .customSelect(
          'SELECT id, parent_block_id, block_type, plain_text, payload_json, '
          'attributes_json, is_checked FROM document_blocks '
          'WHERE document_id = ? '
          'ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .get();
    final parsed = _parsePastDocumentText(text);
    final oldFingerprints = <String>[
      for (final row in oldRows)
        _pastBlockFingerprint(
          DocumentBlockType.values.byName(row.read<String>('block_type')),
          row.read<String>('plain_text'),
          row.readNullable<bool>('is_checked'),
        ),
    ];
    final newFingerprints = <String>[
      for (final block in parsed)
        _pastBlockFingerprint(block.type, block.text, block.isChecked),
    ];

    var prefix = 0;
    while (prefix < oldFingerprints.length &&
        prefix < newFingerprints.length &&
        oldFingerprints[prefix] == newFingerprints[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldFingerprints.length - prefix &&
        suffix < newFingerprints.length - prefix &&
        oldFingerprints[oldFingerprints.length - 1 - suffix] ==
            newFingerprints[newFingerprints.length - 1 - suffix]) {
      suffix++;
    }

    final ids = List<String?>.filled(parsed.length, null);
    for (var index = 0; index < prefix; index++) {
      ids[index] = oldRows[index].read<String>('id');
    }
    for (var offset = 0; offset < suffix; offset++) {
      ids[parsed.length - 1 - offset] = oldRows[oldRows.length - 1 - offset]
          .read<String>('id');
    }
    for (var index = prefix; index < parsed.length - suffix; index++) {
      ids[index] = _uuid.v4();
    }

    final blocks = <DocumentBlockModel>[];
    for (var index = 0; index < parsed.length; index++) {
      final preservedOldIndex = index < prefix
          ? index
          : index >= parsed.length - suffix
          ? oldRows.length - (parsed.length - index)
          : null;
      final old = preservedOldIndex == null ? null : oldRows[preservedOldIndex];
      blocks.add(
        DocumentBlockModel(
          id: ids[index]!,
          documentId: DocumentId(documentId),
          parentBlockId: old?.readNullable<String>('parent_block_id'),
          sortRank: (index + 1) * 1024,
          // A Past entry has no visible marker that can be round-tripped by a
          // plain TextField. When its visible text is unchanged, preserve the
          // original structural type and metadata instead of silently
          // degrading it to a paragraph and detaching its provenance anchor.
          blockType: old == null
              ? parsed[index].type
              : DocumentBlockType.values.byName(old.read<String>('block_type')),
          plainText: parsed[index].text,
          payloadJson: old?.read<String>('payload_json') ?? '{}',
          attributesJson: old?.read<String>('attributes_json') ?? '{}',
          isChecked:
              old?.readNullable<bool>('is_checked') ?? parsed[index].isChecked,
        ),
      );
    }
    final oldChangedIds = oldRows
        .sublist(prefix, oldRows.length - suffix)
        .map((row) => row.read<String>('id'))
        .toList(growable: false);
    final newChangedIds = ids
        .sublist(prefix, parsed.length - suffix)
        .cast<String>();
    final replacements = _pastReplacementMap(oldChangedIds, newChangedIds);
    await DriftDocumentRepository(database).replaceBlocks(
      DocumentId(documentId),
      blocks,
      expectedRevision: revision,
      replacements: replacements,
    );
    await refresh();
  }

  Future<String> appendPastParagraph([String text = '']) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    final blockId = _uuid.v4();
    await database.transaction(() async {
      final document = await database
          .customSelect(
            'SELECT id FROM documents WHERE singleton_key = ?',
            variables: <Variable<Object>>[Variable.withString('past.main')],
          )
          .getSingle();
      final documentId = document.read<String>('id');
      await _snapshotDocument(database, documentId, nowMicros);
      final rankRow = await database
          .customSelect(
            'SELECT COALESCE(MAX(sort_rank), 0) + 1024 AS next_rank '
            'FROM document_blocks WHERE document_id = ?',
            variables: <Variable<Object>>[Variable.withString(documentId)],
          )
          .getSingle();
      await _insertBlock(
        database,
        id: blockId,
        documentId: documentId,
        type: DocumentBlockType.paragraph,
        text: text,
        sortRank: rankRow.read<int>('next_rank'),
        nowMicros: nowMicros,
      );
      await database.customStatement(
        'UPDATE documents SET revision = revision + 1, semantic_hash = ?, '
        'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
        <Object?>[await sha256Hex(text), nowMicros, documentId],
      );
    });
    await refresh();
    return blockId;
  }

  Future<void> saveSettings(AppSettingsModel settings) async {
    final database = await ref.read(databaseProvider.future);
    final nowMicros = utcMicros(DateTime.now());
    var notificationJobQueued = false;
    await database.transaction(() async {
      final previous = await database
          .customSelect('SELECT locale_mode FROM app_settings WHERE id = 1')
          .getSingle();
      await database.customStatement(
        'UPDATE app_settings SET locale_mode = ?, font_mode = ?, '
        'text_scale_percent = ?, density = ?, default_sound_enabled = ?, '
        'default_vibration_enabled = ?, default_snooze_minutes = ?, '
        'auto_backup_enabled = ?, auto_backup_hour_local = ?, '
        'auto_backup_minute_local = ?, backup_encryption_enabled = ?, '
        'help_seen_version = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 WHERE id = 1',
        <Object?>[
          settings.localeMode.name,
          settings.fontMode.name,
          settings.textScalePercent,
          settings.density.name,
          settings.defaultSoundEnabled ? 1 : 0,
          settings.defaultVibrationEnabled ? 1 : 0,
          settings.defaultSnoozeMinutes,
          settings.autoBackupEnabled ? 1 : 0,
          settings.autoBackupHourLocal,
          settings.autoBackupMinuteLocal,
          settings.backupEncryptionEnabled ? 1 : 0,
          settings.helpSeenVersion,
          nowMicros,
        ],
      );
      if (previous.read<String>('locale_mode') != settings.localeMode.name) {
        final reminders = await database
            .customSelect(
              'SELECT task_id FROM reminders WHERE status = ? '
              'AND scheduled_at_utc > ?',
              variables: <Variable<Object>>[
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withInt(nowMicros),
              ],
            )
            .get();
        for (final reminder in reminders) {
          final taskId = reminder.read<String>('task_id');
          await database.customStatement(
            'UPDATE reminders SET schedule_revision = schedule_revision + 1, '
            'updated_at_utc = ?, row_version = row_version + 1 '
            'WHERE task_id = ?',
            <Object?>[nowMicros, taskId],
          );
          notificationJobQueued =
              await _queueReminderJob(
                database,
                taskId: taskId,
                kind: PlatformJobKind.refreshReminderLocale,
                nowMicros: nowMicros,
              ) ||
              notificationJobQueued;
        }
      }
    });
    await _completeTaskMutation(notificationJobQueued);
  }

  Future<DangguiAppState> _readState(DangguiDatabase database) async {
    final taskRows = await database
        .customSelect(
          'SELECT t.*, r.scheduled_at_utc, r.sound_enabled, '
          'r.vibration_enabled, r.status AS reminder_status, '
          'r.pause_reason AS reminder_pause_reason '
          'FROM tasks t LEFT JOIN reminders r ON r.task_id = t.id '
          'AND r.status <> ? '
          'WHERE t.status IN (?, ?) '
          'ORDER BY t.manual_rank, t.id',
          variables: <Variable<Object>>[
            Variable.withString(ReminderStatus.cancelled.name),
            Variable.withString(TaskStatus.active.name),
            Variable.withString(TaskStatus.completionPending.name),
          ],
        )
        .get();
    final taskBodies = await _readDocumentBodies(
      database,
      taskRows.map((row) => row.read<String>('document_id')),
    );
    final tasks = <TaskViewModel>[
      for (final row in taskRows)
        TaskViewModel(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          status: _enumByName(
            TaskStatus.values,
            row.read<String>('status'),
            TaskStatus.active,
          ),
          manualRank: row.read<int>('manual_rank'),
          dueDate: _parseIsoDate(row.readNullable<String>('due_local_date')),
          reminderAt: _fromMicros(row.readNullable<int>('scheduled_at_utc')),
          plan: row.read<String>('plan_text'),
          body: taskBodies[row.read<String>('document_id')] ?? '',
          soundEnabled: row.readNullable<bool>('sound_enabled') ?? true,
          vibrationEnabled: row.readNullable<bool>('vibration_enabled') ?? true,
          reminderStatus: _nullableEnumByName(
            ReminderStatus.values,
            row.readNullable<String>('reminder_status'),
          ),
          reminderPauseReason: _nullableEnumByName(
            ReminderPauseReason.values,
            row.readNullable<String>('reminder_pause_reason'),
          ),
        ),
    ];

    final noteRows = await database
        .customSelect(
          'SELECT * FROM notes WHERE deleted_at_utc IS NULL '
          'ORDER BY pinned_at_utc IS NULL, pinned_at_utc DESC, updated_at_utc DESC',
        )
        .get();
    final noteBodies = await _readDocumentBodies(
      database,
      noteRows.map((row) => row.read<String>('document_id')),
    );
    final notes = <NoteViewModel>[
      for (final row in noteRows)
        NoteViewModel(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          body: noteBodies[row.read<String>('document_id')] ?? '',
          folderId: row.readNullable<String>('folder_id'),
          pinned: row.readNullable<int>('pinned_at_utc') != null,
          updatedAt: _fromMicros(row.read<int>('updated_at_utc'))!,
        ),
    ];

    final folderRows = await database
        .customSelect('SELECT id, name FROM folders ORDER BY sort_rank, id')
        .get();
    final folders = <FolderViewModel>[
      for (final row in folderRows)
        FolderViewModel(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
        ),
    ];

    final pastDocumentRow = await database
        .customSelect(
          'SELECT id, revision FROM documents WHERE singleton_key = ?',
          variables: <Variable<Object>>[Variable.withString('past.main')],
        )
        .getSingle();
    final pastRows = await database
        .customSelect(
          'SELECT b.id, b.sort_rank, b.block_type, b.plain_text, b.is_checked '
          'FROM document_blocks b JOIN documents d ON d.id = b.document_id '
          'WHERE d.singleton_key = ? ORDER BY b.sort_rank, b.id',
          variables: <Variable<Object>>[Variable.withString('past.main')],
        )
        .get();
    final pastEventRows = await database
        .customSelect(
          'SELECT e.id AS event_id, e.append_sequence, '
          'e.completion_local_date, e.anchor_state, p.role, p.source_order, '
          'l.id AS link_id, l.current_block_id, l.link_state '
          'FROM past_events e '
          'LEFT JOIN past_event_parts p ON p.event_id = e.id '
          'LEFT JOIN past_anchor_links l ON l.part_id = p.id '
          'WHERE e.document_id = ? '
          'ORDER BY e.append_sequence, p.source_order, l.id',
          variables: <Variable<Object>>[
            Variable.withString(pastDocumentRow.read<String>('id')),
          ],
          readsFrom: <ResultSetImplementation>{
            database.pastEvents,
            database.pastEventParts,
            database.pastAnchorLinks,
          },
        )
        .get();
    final pastBlocks = <PastBlockViewModel>[
      for (final row in pastRows)
        PastBlockViewModel(
          id: row.read<String>('id'),
          type: _enumByName(
            DocumentBlockType.values,
            row.read<String>('block_type'),
            DocumentBlockType.paragraph,
          ),
          text: row.read<String>('plain_text'),
          isChecked: row.readNullable<bool>('is_checked'),
        ),
    ];
    final pastDocument = _buildPastEditorDocument(
      revision: pastDocumentRow.read<int>('revision'),
      blockRows: pastRows,
      eventRows: pastEventRows,
    );

    final settingsRow = await database
        .customSelect('SELECT * FROM app_settings WHERE id = 1')
        .getSingle();
    final settings = AppSettingsModel(
      localeMode: _enumByName(
        LocaleMode.values,
        settingsRow.read<String>('locale_mode'),
        LocaleMode.system,
      ),
      fontMode: _enumByName(
        FontMode.values,
        settingsRow.read<String>('font_mode'),
        FontMode.sans,
      ),
      textScalePercent: settingsRow.read<int>('text_scale_percent'),
      density: _enumByName(
        DisplayDensity.values,
        settingsRow.read<String>('density'),
        DisplayDensity.loose,
      ),
      defaultSoundEnabled: settingsRow.read<bool>('default_sound_enabled'),
      defaultVibrationEnabled: settingsRow.read<bool>(
        'default_vibration_enabled',
      ),
      defaultSnoozeMinutes: settingsRow.read<int>('default_snooze_minutes'),
      autoBackupEnabled: settingsRow.read<bool>('auto_backup_enabled'),
      autoBackupHourLocal: settingsRow.read<int>('auto_backup_hour_local'),
      autoBackupMinuteLocal: settingsRow.read<int>('auto_backup_minute_local'),
      backupEncryptionEnabled: settingsRow.read<bool>(
        'backup_encryption_enabled',
      ),
      helpSeenVersion: settingsRow.read<int>('help_seen_version'),
      rowVersion: settingsRow.read<int>('row_version'),
    );
    return DangguiAppState(
      tasks: tasks,
      notes: notes,
      folders: folders,
      pastBlocks: pastBlocks,
      pastDocument: pastDocument,
      settings: settings,
    );
  }

  Future<Map<String, String>> _readDocumentBodies(
    DangguiDatabase database,
    Iterable<String> documentIds,
  ) async {
    final ids = documentIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <String, String>{};
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await database
        .customSelect(
          'SELECT document_id, block_type, plain_text, is_checked '
          'FROM document_blocks '
          'WHERE document_id IN ($placeholders) ORDER BY sort_rank, id',
          variables: <Variable<Object>>[
            for (final id in ids) Variable.withString(id),
          ],
        )
        .get();
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row.read<String>('document_id'), () => <String>[])
          .add(
            _editableBlockText(
              DocumentBlockType.values.byName(row.read<String>('block_type')),
              row.read<String>('plain_text'),
              row.readNullable<bool>('is_checked'),
            ),
          );
    }
    return <String, String>{
      for (final entry in grouped.entries) entry.key: entry.value.join('\n'),
    };
  }

  Future<bool> _writeReminder(
    DangguiDatabase database, {
    required String taskId,
    required TaskStatus taskStatus,
    required DateTime reminderAt,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required int nowMicros,
  }) async {
    final existing = await database
        .customSelect(
          'SELECT id, schedule_revision, status FROM reminders '
          'WHERE task_id = ?',
          variables: <Variable<Object>>[Variable.withString(taskId)],
        )
        .getSingleOrNull();
    final id = existing?.read<String>('id') ?? _uuid.v4();
    final revision = (existing?.read<int>('schedule_revision') ?? 0) + 1;
    final local = reminderAt.toLocal();
    final isTaskClosed = taskStatus == TaskStatus.completionPending;
    final isFuture = utcMicros(reminderAt) > nowMicros;
    final keepsPermissionDenied =
        !isTaskClosed &&
        existing?.read<String>('status') ==
            ReminderStatus.permissionDenied.name &&
        isFuture;
    final status = isTaskClosed
        ? ReminderStatus.paused
        : isFuture
        ? (keepsPermissionDenied
              ? ReminderStatus.permissionDenied
              : ReminderStatus.scheduled)
        : ReminderStatus.expired;
    final pauseReason = isTaskClosed
        ? ReminderPauseReason.taskClosed
        : keepsPermissionDenied
        ? ReminderPauseReason.permissionDenied
        : null;
    await database.customStatement(
      'INSERT INTO reminders '
      '(id, task_id, scheduled_local_date_time, scheduled_zone_id, '
      'scheduled_at_utc, snoozed_until_utc, sound_enabled, vibration_enabled, '
      'status, pause_reason, snooze_count, schedule_revision, '
      'last_fired_at_utc, created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, 0, ?, NULL, ?, ?, 1) '
      'ON CONFLICT(task_id) DO UPDATE SET '
      'scheduled_local_date_time = excluded.scheduled_local_date_time, '
      'scheduled_zone_id = excluded.scheduled_zone_id, '
      'scheduled_at_utc = excluded.scheduled_at_utc, '
      'snoozed_until_utc = NULL, '
      'sound_enabled = excluded.sound_enabled, '
      'vibration_enabled = excluded.vibration_enabled, '
      'status = excluded.status, pause_reason = excluded.pause_reason, '
      'schedule_revision = excluded.schedule_revision, '
      'updated_at_utc = excluded.updated_at_utc, row_version = row_version + 1',
      <Object?>[
        id,
        taskId,
        local.toIso8601String(),
        local.timeZoneName,
        utcMicros(reminderAt),
        soundEnabled ? 1 : 0,
        vibrationEnabled ? 1 : 0,
        status.name,
        pauseReason?.name,
        revision,
        nowMicros,
        nowMicros,
      ],
    );
    if (isTaskClosed || isFuture) {
      return _queueReminderJob(
        database,
        taskId: taskId,
        kind: isTaskClosed || keepsPermissionDenied
            ? PlatformJobKind.cancelReminder
            : PlatformJobKind.scheduleReminder,
        nowMicros: nowMicros,
      );
    }
    return false;
  }

  Future<bool> _cancelReminder(
    DangguiDatabase database,
    String taskId,
    int nowMicros,
  ) async {
    final changed = await database.customUpdate(
      'UPDATE reminders SET status = ?, pause_reason = ?, '
      'schedule_revision = schedule_revision + 1, updated_at_utc = ?, '
      'row_version = row_version + 1 WHERE task_id = ?',
      variables: <Variable<Object>>[
        Variable.withString(ReminderStatus.cancelled.name),
        Variable.withString(ReminderPauseReason.user.name),
        Variable.withInt(nowMicros),
        Variable.withString(taskId),
      ],
      updates: <TableInfo<Table, Object?>>{database.reminders},
    );
    if (changed > 0) {
      return _queueReminderJob(
        database,
        taskId: taskId,
        kind: PlatformJobKind.cancelReminder,
        nowMicros: nowMicros,
      );
    }
    return false;
  }

  Future<bool> _pauseReminderForTrash(
    DangguiDatabase database,
    String taskId,
    int nowMicros,
  ) async {
    final changed = await database.customUpdate(
      'UPDATE reminders SET status = ?, pause_reason = ?, '
      'schedule_revision = schedule_revision + 1, updated_at_utc = ?, '
      'row_version = row_version + 1 WHERE task_id = ? AND status <> ?',
      variables: <Variable<Object>>[
        Variable.withString(ReminderStatus.paused.name),
        Variable.withString(ReminderPauseReason.user.name),
        Variable.withInt(nowMicros),
        Variable.withString(taskId),
        Variable.withString(ReminderStatus.cancelled.name),
      ],
      updates: <TableInfo<Table, Object?>>{database.reminders},
    );
    if (changed == 0) return false;
    return _queueReminderJob(
      database,
      taskId: taskId,
      kind: PlatformJobKind.cancelReminder,
      nowMicros: nowMicros,
    );
  }

  Future<bool> _queueReminderJob(
    DangguiDatabase database, {
    required String taskId,
    required PlatformJobKind kind,
    required int nowMicros,
    bool onlyIfFuture = false,
  }) async {
    final reminder = await database
        .customSelect(
          'SELECT id, schedule_revision, scheduled_at_utc FROM reminders '
          'WHERE task_id = ?',
          variables: <Variable<Object>>[Variable.withString(taskId)],
        )
        .getSingleOrNull();
    if (reminder == null) return false;
    if (onlyIfFuture && reminder.read<int>('scheduled_at_utc') <= nowMicros) {
      return false;
    }
    final reminderId = reminder.read<String>('id');
    final revision = reminder.read<int>('schedule_revision');
    final dedupe = '${kind.name}:$reminderId:$revision';
    await database.customStatement(
      'INSERT OR IGNORE INTO platform_jobs '
      '(id, kind, aggregate_id, aggregate_revision, dedupe_key, payload_json, '
      'status, attempts, next_attempt_at_utc, created_at_utc, updated_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
      <Object?>[
        _uuid.v4(),
        kind.name,
        reminderId,
        revision,
        dedupe,
        canonicalJson(<String, Object?>{'taskId': taskId}),
        PlatformJobStatus.pending.name,
        nowMicros,
        nowMicros,
        nowMicros,
      ],
    );
    return true;
  }

  Future<void> _replaceDocumentText(
    DangguiDatabase database, {
    required String documentId,
    required String text,
    required int nowMicros,
  }) async {
    await database.customStatement(
      'DELETE FROM document_blocks WHERE document_id = ?',
      <Object?>[documentId],
    );
    final blocks = _parseEditableDocumentText(text);
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      await _insertBlock(
        database,
        documentId: documentId,
        type: block.type,
        text: block.text,
        sortRank: (index + 1) * 1024,
        nowMicros: nowMicros,
        isChecked: block.isChecked,
      );
    }
    await database.customStatement(
      'UPDATE documents SET revision = revision + 1, semantic_hash = ?, '
      'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
      <Object?>[
        await sha256Hex(<Object?>[
          for (final block in blocks)
            <String, Object?>{
              'type': block.type.name,
              'text': block.text,
              'checked': block.isChecked,
            },
        ]),
        nowMicros,
        documentId,
      ],
    );
  }

  Future<void> _snapshotDocument(
    DangguiDatabase database,
    String documentId,
    int nowMicros,
  ) async {
    final document = await database
        .customSelect(
          'SELECT revision FROM documents WHERE id = ?',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .getSingleOrNull();
    if (document == null) return;
    final blocks = await database
        .customSelect(
          'SELECT id, parent_block_id, sort_rank, block_type, plain_text, '
          'payload_json, attributes_json, is_checked FROM document_blocks '
          'WHERE document_id = ? ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .get();
    final nextRevision = document.read<int>('revision') + 1;
    final snapshot = canonicalJson(<String, Object?>{
      'formatVersion': 1,
      'documentId': documentId,
      'revision': nextRevision,
      'blocks': <Object?>[for (final row in blocks) row.data],
    });
    await database.customStatement(
      'INSERT OR IGNORE INTO document_revisions '
      '(id, document_id, revision, reason, codec, snapshot_blob, '
      'snapshot_sha256, created_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        _uuid.v4(),
        documentId,
        nextRevision,
        'editorClose',
        'json-v1',
        Uint8List.fromList(utf8.encode(snapshot)),
        await sha256Hex(jsonDecode(snapshot)),
        nowMicros,
      ],
    );
  }

  static Future<void> _insertBlock(
    DangguiDatabase database, {
    String? id,
    required String documentId,
    required DocumentBlockType type,
    required String text,
    required int sortRank,
    required int nowMicros,
    bool? isChecked,
  }) async {
    final hash = await sha256Hex(<String, Object?>{
      'type': type.name,
      'text': text,
      'checked': isChecked,
    });
    await database.customStatement(
      'INSERT INTO document_blocks '
      '(id, document_id, parent_block_id, sort_rank, block_type, plain_text, '
      'payload_json, attributes_json, is_checked, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
      <Object?>[
        id ?? _uuid.v4(),
        documentId,
        sortRank,
        type.name,
        text,
        '{}',
        '{}',
        isChecked,
        hash,
        nowMicros,
        nowMicros,
      ],
    );
  }

  static Future<void> _upsertSearch(
    DangguiDatabase database, {
    required SearchScope scope,
    required String entityId,
    required String documentId,
    required String title,
    required String body,
    required String dateKey,
    required int nowMicros,
  }) async {
    await database.customStatement(
      'INSERT INTO search_records '
      '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
      'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(scope, entity_id) DO UPDATE SET '
      'document_id = excluded.document_id, title_norm = excluded.title_norm, '
      'body_norm = excluded.body_norm, date_key = excluded.date_key, '
      'updated_at_utc = excluded.updated_at_utc',
      <Object?>[
        scope.name,
        entityId,
        documentId,
        normalizedSearchText(title),
        normalizedSearchText(body),
        dateKey,
        nowMicros,
      ],
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

T? _nullableEnumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

String? _isoDate(DateTime? value) {
  if (value == null) return null;
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _localTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime? _fromMicros(int? value) {
  if (value == null) return null;
  return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
}

PastEditorDocumentViewModel _buildPastEditorDocument({
  required int revision,
  required List<QueryRow> blockRows,
  required List<QueryRow> eventRows,
}) {
  final blockIndexes = <String, int>{};
  final blocksById = <String, PastBlockViewModel>{};
  for (var index = 0; index < blockRows.length; index++) {
    final row = blockRows[index];
    final id = row.read<String>('id');
    blockIndexes[id] = index;
    blocksById[id] = PastBlockViewModel(
      id: id,
      type: _enumByName(
        DocumentBlockType.values,
        row.read<String>('block_type'),
        DocumentBlockType.paragraph,
      ),
      text: row.read<String>('plain_text'),
      isChecked: row.readNullable<bool>('is_checked'),
    );
  }

  final events = <String, _PastProjectionEvent>{};
  for (final row in eventRows) {
    final eventId = row.read<String>('event_id');
    final event = events.putIfAbsent(
      eventId,
      () => _PastProjectionEvent(
        id: eventId,
        completionLocalDate: row.read<String>('completion_local_date'),
        appendSequence: row.read<int>('append_sequence'),
      ),
    );
    final roleName = row.readNullable<String>('role');
    final blockId = row.readNullable<String>('current_block_id');
    if (roleName == null ||
        blockId == null ||
        row.readNullable<String>('link_state') != AnchorLinkState.linked.name ||
        !blocksById.containsKey(blockId)) {
      continue;
    }
    final role = _nullableEnumByName(PastPartRole.values, roleName);
    if (role == null) continue;
    event.links.add(
      _PastProjectionLink(
        role: role,
        sourceOrder: row.read<int>('source_order'),
        blockId: blockId,
      ),
    );
  }

  final blockEventIds = <String, Set<String>>{};
  for (final event in events.values) {
    for (final link in event.links) {
      blockEventIds.putIfAbsent(link.blockId, () => <String>{}).add(event.id);
    }
  }
  final eligibleByFirstIndex = <int, _PastProjectionEvent>{};
  final claimedBlockIds = <String>{};
  final orderedEvents = events.values.toList(
    growable: false,
  )..sort((left, right) => left.appendSequence.compareTo(right.appendSequence));
  for (final event in orderedEvents) {
    final hasTitle = event.links.any((link) => link.role == PastPartRole.title);
    final hasTime = event.links.any((link) => link.role == PastPartRole.time);
    final sourceBlockIds =
        event.links.map((link) => link.blockId).toSet().toList(growable: false)
          ..sort(
            (left, right) =>
                blockIndexes[left]!.compareTo(blockIndexes[right]!),
          );
    if (!hasTitle || !hasTime || sourceBlockIds.isEmpty) continue;
    if (sourceBlockIds.any((id) => (blockEventIds[id]?.length ?? 0) != 1)) {
      continue;
    }
    final indexes = sourceBlockIds
        .map((id) => blockIndexes[id]!)
        .toList(growable: false);
    final first = indexes.first;
    final last = indexes.last;
    if (last - first + 1 != indexes.length ||
        sourceBlockIds.any(claimedBlockIds.contains)) {
      continue;
    }
    event.sourceBlockIds = sourceBlockIds;
    eligibleByFirstIndex[first] = event;
    claimedBlockIds.addAll(sourceBlockIds);
  }

  final segments = <PastEditorSegmentViewModel>[];
  var number = 0;
  String separatorFor(PastEditorSegmentKind kind) {
    if (segments.isEmpty) return '';
    return kind == PastEditorSegmentKind.dateHeading ? '\n\n' : '\n';
  }

  for (var index = 0; index < blockRows.length; index++) {
    final row = blockRows[index];
    final blockId = row.read<String>('id');
    final event = eligibleByFirstIndex[index];
    if (event != null) {
      final text = _pastEventProjectionText(event, blocksById);
      if (text.isNotEmpty) {
        segments.add(
          PastEditorSegmentViewModel(
            id: 'event:${event.id}',
            kind: PastEditorSegmentKind.event,
            text: text,
            separatorBefore: separatorFor(PastEditorSegmentKind.event),
            sourceBlockIds: event.sourceBlockIds,
            eventId: event.id,
            completionLocalDate: event.completionLocalDate,
          ),
        );
      }
      continue;
    }
    if (claimedBlockIds.contains(blockId)) continue;
    final block = blocksById[blockId]!;
    if (block.type == DocumentBlockType.numbered) number++;
    final kind = block.type == DocumentBlockType.pastDate
        ? PastEditorSegmentKind.dateHeading
        : PastEditorSegmentKind.freeform;
    segments.add(
      PastEditorSegmentViewModel(
        id: 'block:$blockId',
        kind: kind,
        text: _pastProjectionBlockText(block, number: number),
        separatorBefore: separatorFor(kind),
        sourceBlockIds: <String>[blockId],
        completionLocalDate: kind == PastEditorSegmentKind.dateHeading
            ? block.text
            : null,
      ),
    );
  }
  return PastEditorDocumentViewModel(revision: revision, segments: segments);
}

String _pastEventProjectionText(
  _PastProjectionEvent event,
  Map<String, PastBlockViewModel> blocksById,
) {
  final usedBlockIds = <String>{};
  List<String> take(Set<PastPartRole> roles, {bool calendar = false}) {
    final values = <String>[];
    final links = event.links.toList(growable: false)
      ..sort((left, right) => left.sourceOrder.compareTo(right.sourceOrder));
    for (final link in links) {
      if (!roles.contains(link.role) || !usedBlockIds.add(link.blockId)) {
        continue;
      }
      final block = blocksById[link.blockId];
      if (block == null) continue;
      var value = _pastProjectionBlockText(block).trim();
      if (value.isEmpty) continue;
      if (calendar) value = _pastCalendarProjectionText(value);
      values.add(value);
    }
    return values;
  }

  final core = <String>[
    ...take(const <PastPartRole>{PastPartRole.title}),
    ...take(const <PastPartRole>{PastPartRole.time}),
    ...take(const <PastPartRole>{PastPartRole.dueDate}, calendar: true),
  ];
  final details = <String>[
    ...take(const <PastPartRole>{PastPartRole.body, PastPartRole.checklist}),
    ...take(const <PastPartRole>{PastPartRole.plan}),
  ];
  for (final blockId in event.sourceBlockIds) {
    if (!usedBlockIds.add(blockId)) continue;
    final block = blocksById[blockId];
    if (block == null) continue;
    final value = _pastProjectionBlockText(block).trim();
    if (value.isNotEmpty) details.add(value);
  }
  final coreText = core.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final detailText = details.join(' · ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (coreText.isEmpty) return detailText;
  if (detailText.isEmpty) return coreText;
  return '$coreText · $detailText';
}

String _pastCalendarProjectionText(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('📅')) return normalized;
  final withoutLegacyPrefix = normalized.startsWith('原计划：')
      ? normalized.substring('原计划：'.length).trim()
      : normalized;
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(withoutLegacyPrefix)
      ? '📅 $withoutLegacyPrefix'
      : withoutLegacyPrefix;
}

String _pastProjectionBlockText(PastBlockViewModel block, {int number = 1}) =>
    switch (block.type) {
      DocumentBlockType.bullet => '• ${block.text}',
      DocumentBlockType.numbered => '$number. ${block.text}',
      DocumentBlockType.checklist =>
        '${block.isChecked == true ? '☒' : '☐'} ${block.text}',
      _ => block.text,
    };

final class _PastProjectionEvent {
  _PastProjectionEvent({
    required this.id,
    required this.completionLocalDate,
    required this.appendSequence,
  });

  final String id;
  final String completionLocalDate;
  final int appendSequence;
  final List<_PastProjectionLink> links = <_PastProjectionLink>[];
  List<String> sourceBlockIds = const <String>[];
}

final class _PastProjectionLink {
  const _PastProjectionLink({
    required this.role,
    required this.sourceOrder,
    required this.blockId,
  });

  final PastPartRole role;
  final int sourceOrder;
  final String blockId;
}

final class _ParsedEditableBlock {
  const _ParsedEditableBlock({
    required this.type,
    required this.text,
    this.isChecked,
  });

  final DocumentBlockType type;
  final String text;
  final bool? isChecked;
}

List<_ParsedEditableBlock> _parseEditableDocumentText(String source) {
  if (source.isEmpty) return const <_ParsedEditableBlock>[];
  return source
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) {
        if (line.startsWith('☒ ')) {
          return _ParsedEditableBlock(
            type: DocumentBlockType.checklist,
            text: line.substring(2),
            isChecked: true,
          );
        }
        if (line.startsWith('☐ ')) {
          return _ParsedEditableBlock(
            type: DocumentBlockType.checklist,
            text: line.substring(2),
            isChecked: false,
          );
        }
        if (line.startsWith('• ')) {
          return _ParsedEditableBlock(
            type: DocumentBlockType.bullet,
            text: line.substring(2),
          );
        }
        if (RegExp(r'^\d+\.\s').hasMatch(line)) {
          return _ParsedEditableBlock(
            type: DocumentBlockType.numbered,
            text: line.replaceFirst(RegExp(r'^\d+\.\s'), ''),
          );
        }
        return _ParsedEditableBlock(
          type: DocumentBlockType.paragraph,
          text: line,
        );
      })
      .toList(growable: false);
}

String _editableBlockText(
  DocumentBlockType type,
  String text,
  bool? isChecked,
) {
  return switch (type) {
    DocumentBlockType.bullet => '• $text',
    DocumentBlockType.numbered => '1. $text',
    DocumentBlockType.checklist => '${isChecked == true ? '☒' : '☐'} $text',
    _ => text,
  };
}

String _serializePastEditorSegments(
  List<PastEditorSegmentViewModel> segments,
) => segments
    .map((segment) => '${segment.separatorBefore}${segment.text}')
    .join();

List<String> _parsePastProjectedLines(String source) => source
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

Map<int, int> _matchPastProjectionLines(
  List<PastEditorSegmentViewModel> baseSegments,
  List<String> editedLines,
) {
  final baseOccurrences = <String, List<int>>{};
  for (var index = 0; index < baseSegments.length; index++) {
    baseOccurrences
        .putIfAbsent(baseSegments[index].text, () => <int>[])
        .add(index);
  }
  final editedOccurrences = <String, List<int>>{};
  for (var index = 0; index < editedLines.length; index++) {
    editedOccurrences.putIfAbsent(editedLines[index], () => <int>[]).add(index);
  }
  final matches = <int, int>{};
  for (final entry in editedOccurrences.entries) {
    final baseIndexes = baseOccurrences[entry.key];
    if (baseIndexes == null) continue;
    matches.addAll(_pairPastProjectionOccurrences(baseIndexes, entry.value));
  }
  return matches;
}

Map<int, int> _pairPastProjectionOccurrences(
  List<int> baseIndexes,
  List<int> editedIndexes,
) {
  final matches = <int, int>{};
  var baseCursor = 0;
  var editedCursor = 0;
  while (baseCursor < baseIndexes.length &&
      editedCursor < editedIndexes.length) {
    final remainingBase = baseIndexes.length - baseCursor;
    final remainingEdited = editedIndexes.length - editedCursor;
    if (remainingBase > remainingEdited &&
        baseCursor + 1 < baseIndexes.length) {
      final currentDistance =
          (baseIndexes[baseCursor] - editedIndexes[editedCursor]).abs();
      final nextDistance =
          (baseIndexes[baseCursor + 1] - editedIndexes[editedCursor]).abs();
      if (nextDistance < currentDistance) {
        baseCursor++;
        continue;
      }
    }
    if (remainingEdited > remainingBase &&
        editedCursor + 1 < editedIndexes.length) {
      final currentDistance =
          (baseIndexes[baseCursor] - editedIndexes[editedCursor]).abs();
      final nextDistance =
          (baseIndexes[baseCursor] - editedIndexes[editedCursor + 1]).abs();
      if (nextDistance < currentDistance) {
        editedCursor++;
        continue;
      }
    }
    matches[editedIndexes[editedCursor]] = baseIndexes[baseCursor];
    baseCursor++;
    editedCursor++;
  }
  return matches;
}

Map<int, int> _matchPastReplacementSegments({
  required List<PastEditorSegmentViewModel> baseSegments,
  required List<String> editedLines,
  required List<int> unmatchedBaseIndexes,
  required List<int> unmatchedLineIndexes,
}) {
  final candidates =
      <({int baseIndex, int lineIndex, int distance, int similarity})>[];
  for (final baseIndex in unmatchedBaseIndexes) {
    for (final lineIndex in unmatchedLineIndexes) {
      final similarity = _pastProjectionTextSimilarity(
        baseSegments[baseIndex].text,
        editedLines[lineIndex],
      );
      // A tiny shared suffix (for example ":00") is not enough evidence that
      // a new row edits the old event. Uncertain pairs stay detached/unanchored.
      if (similarity < 4) continue;
      candidates.add((
        baseIndex: baseIndex,
        lineIndex: lineIndex,
        distance: (baseIndex - lineIndex).abs(),
        similarity: similarity,
      ));
    }
  }
  candidates.sort((left, right) {
    final bySimilarity = right.similarity.compareTo(left.similarity);
    if (bySimilarity != 0) return bySimilarity;
    final byDistance = left.distance.compareTo(right.distance);
    if (byDistance != 0) return byDistance;
    final byBase = left.baseIndex.compareTo(right.baseIndex);
    if (byBase != 0) return byBase;
    return left.lineIndex.compareTo(right.lineIndex);
  });

  final matchedBaseIndexes = <int>{};
  final matchedLineIndexes = <int>{};
  final replacements = <int, int>{};
  for (final candidate in candidates) {
    if (matchedBaseIndexes.contains(candidate.baseIndex) ||
        matchedLineIndexes.contains(candidate.lineIndex)) {
      continue;
    }
    final isAmbiguous = candidates.any(
      (other) =>
          (other.baseIndex == candidate.baseIndex ||
              other.lineIndex == candidate.lineIndex) &&
          (other.baseIndex != candidate.baseIndex ||
              other.lineIndex != candidate.lineIndex) &&
          other.distance == candidate.distance &&
          other.similarity == candidate.similarity,
    );
    if (isAmbiguous) continue;
    matchedBaseIndexes.add(candidate.baseIndex);
    matchedLineIndexes.add(candidate.lineIndex);
    replacements[candidate.baseIndex] = candidate.lineIndex;
  }
  return replacements;
}

int _pastProjectionTextSimilarity(String left, String right) {
  final shortest = left.length < right.length ? left.length : right.length;
  var prefix = 0;
  while (prefix < shortest &&
      left.codeUnitAt(prefix) == right.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      left.codeUnitAt(left.length - suffix - 1) ==
          right.codeUnitAt(right.length - suffix - 1)) {
    suffix++;
  }
  final leftTokens = left
      .split(RegExp(r'[\s·]+'))
      .where((value) => value.isNotEmpty)
      .toSet();
  final rightTokens = right
      .split(RegExp(r'[\s·]+'))
      .where((value) => value.isNotEmpty)
      .toSet();
  return prefix + suffix + leftTokens.intersection(rightTokens).length * 4;
}

DocumentBlockModel _pastDocumentBlockFromRow(QueryRow row, String documentId) =>
    DocumentBlockModel(
      id: row.read<String>('id'),
      documentId: DocumentId(documentId),
      parentBlockId: row.readNullable<String>('parent_block_id'),
      sortRank: row.read<int>('sort_rank'),
      blockType: DocumentBlockType.values.byName(
        row.read<String>('block_type'),
      ),
      plainText: row.read<String>('plain_text'),
      payloadJson: row.read<String>('payload_json'),
      attributesJson: row.read<String>('attributes_json'),
      isChecked: row.readNullable<bool>('is_checked'),
    );

DocumentBlockModel _pastDocumentBlockWithRank(
  DocumentBlockModel block,
  int sortRank,
) => DocumentBlockModel(
  id: block.id,
  documentId: block.documentId,
  parentBlockId: block.parentBlockId,
  sortRank: sortRank,
  blockType: block.blockType,
  plainText: block.plainText,
  payloadJson: block.payloadJson,
  attributesJson: block.attributesJson,
  isChecked: block.isChecked,
);

final class _ParsedPastBlock {
  const _ParsedPastBlock({
    required this.type,
    required this.text,
    this.isChecked,
  });

  final DocumentBlockType type;
  final String text;
  final bool? isChecked;
}

List<_ParsedPastBlock> _parsePastDocumentText(String source) {
  final normalized = source.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const <_ParsedPastBlock>[];
  return normalized
      .split(RegExp(r'\n{2,}'))
      .map((raw) {
        final text = raw.trim();
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
            DateTime.tryParse(text) != null) {
          return _ParsedPastBlock(type: DocumentBlockType.pastDate, text: text);
        }
        if (text.startsWith('☒ ')) {
          return _ParsedPastBlock(
            type: DocumentBlockType.checklist,
            text: text.substring(2),
            isChecked: true,
          );
        }
        if (text.startsWith('☐ ')) {
          return _ParsedPastBlock(
            type: DocumentBlockType.checklist,
            text: text.substring(2),
            isChecked: false,
          );
        }
        if (text.startsWith('• ')) {
          return _ParsedPastBlock(
            type: DocumentBlockType.bullet,
            text: text.substring(2),
          );
        }
        if (RegExp(r'^\d+\.\s').hasMatch(text)) {
          return _ParsedPastBlock(
            type: DocumentBlockType.numbered,
            text: text.replaceFirst(RegExp(r'^\d+\.\s'), ''),
          );
        }
        return _ParsedPastBlock(type: DocumentBlockType.paragraph, text: text);
      })
      .toList(growable: false);
}

_ParsedPastBlock _parsePastProjectedLine(String source) {
  final parsed = _parsePastDocumentText(source);
  return parsed.isEmpty
      ? const _ParsedPastBlock(type: DocumentBlockType.paragraph, text: '')
      : parsed.single;
}

String _pastBlockFingerprint(
  DocumentBlockType type,
  String text,
  bool? isChecked,
) {
  // pastDate, pastEntry and paragraph are all rendered as unprefixed text.
  // Treat them as the same visible shape for prefix/suffix alignment; the
  // original type is copied back for aligned blocks above. List/checklist
  // markers remain part of the visible editing contract.
  final visibleType = switch (type) {
    DocumentBlockType.bullet => 'bullet',
    DocumentBlockType.numbered => 'numbered',
    DocumentBlockType.checklist => 'checklist:$isChecked',
    _ => 'plain',
  };
  return '$visibleType\u0000$text';
}

Map<String, List<String>> _pastReplacementMap(
  List<String> oldIds,
  List<String> newIds,
) {
  if (oldIds.isEmpty) return const <String, List<String>>{};
  if (newIds.isEmpty) {
    return <String, List<String>>{for (final id in oldIds) id: const []};
  }
  if (oldIds.length == 1) {
    return <String, List<String>>{oldIds.single: List.of(newIds)};
  }
  if (newIds.length == 1) {
    return <String, List<String>>{
      for (final id in oldIds) id: <String>[newIds.single],
    };
  }
  if (newIds.length >= oldIds.length) {
    return <String, List<String>>{
      for (var index = 0; index < oldIds.length; index++)
        oldIds[index]: newIds.sublist(
          (index * newIds.length / oldIds.length).floor(),
          ((index + 1) * newIds.length / oldIds.length).floor(),
        ),
    };
  }
  return <String, List<String>>{
    for (var index = 0; index < oldIds.length; index++)
      oldIds[index]: <String>[
        newIds[(index * newIds.length / oldIds.length).floor()],
      ],
  };
}
