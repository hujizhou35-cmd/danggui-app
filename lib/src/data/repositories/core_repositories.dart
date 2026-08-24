import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../data_support.dart';
import '../database.dart';

abstract base class _RepositoryBase {
  _RepositoryBase(
    this.db, {
    this.clock = const SystemClock(),
    this.ids = const UuidIdGenerator(),
  });

  final DangguiDatabase db;
  final Clock clock;
  final IdGenerator ids;

  int get nowMicros => utcMicros(clock.nowUtc());

  Future<String> documentPlainText(String documentId) async {
    final query = db.select(db.documentBlocks)
      ..where((block) => block.documentId.equals(documentId))
      ..orderBy([
        (block) => OrderingTerm(expression: block.sortRank),
        (block) => OrderingTerm(expression: block.id),
      ]);
    return (await query.get())
        .map((block) => block.plainText)
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  Future<void> putSearchRecord({
    required SearchScope scope,
    required String entityId,
    required String? documentId,
    required String title,
    required String body,
    String dateKey = '',
  }) async {
    await db
        .into(db.searchRecords)
        .insert(
          SearchRecordsCompanion.insert(
            scope: scope,
            entityId: entityId,
            documentId: Value(documentId),
            titleNorm: Value(normalizedSearchText(title)),
            bodyNorm: Value(normalizedSearchText(body)),
            dateKey: Value(dateKey),
            updatedAtUtc: nowMicros,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> enqueueJob({
    required PlatformJobKind kind,
    required String aggregateId,
    required int aggregateRevision,
    required Map<String, Object?> payload,
  }) async {
    final dedupeKey = '${kind.name}:$aggregateId:$aggregateRevision';
    await db
        .into(db.platformJobs)
        .insert(
          PlatformJobsCompanion.insert(
            id: ids.next(),
            kind: kind,
            aggregateId: aggregateId,
            aggregateRevision: aggregateRevision,
            dedupeKey: dedupeKey,
            payloadJson: canonicalJson(payload),
            status: PlatformJobStatus.pending,
            nextAttemptAtUtc: nowMicros,
            createdAtUtc: nowMicros,
            updatedAtUtc: nowMicros,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  TaskModel mapTask(TaskRow row) => TaskModel(
    id: TaskId(row.id),
    documentId: DocumentId(row.documentId),
    title: row.title,
    dueLocalDate: row.dueLocalDate,
    planText: row.planText,
    status: row.status,
    manualRank: row.manualRank,
    closedAtUtc: row.closedAtUtc == null
        ? null
        : dateTimeFromUtcMicros(row.closedAtUtc!),
    closedLocalDate: row.closedLocalDate,
    closedLocalTime: row.closedLocalTime,
    closedZoneId: row.closedZoneId,
    archivedAtUtc: row.archivedAtUtc == null
        ? null
        : dateTimeFromUtcMicros(row.archivedAtUtc!),
    deletedAtUtc: row.deletedAtUtc == null
        ? null
        : dateTimeFromUtcMicros(row.deletedAtUtc!),
    createdAtUtc: dateTimeFromUtcMicros(row.createdAtUtc),
    updatedAtUtc: dateTimeFromUtcMicros(row.updatedAtUtc),
    rowVersion: row.rowVersion,
  );

  NoteModel mapNote(NoteRow row) => NoteModel(
    id: NoteId(row.id),
    documentId: DocumentId(row.documentId),
    folderId: row.folderId == null ? null : FolderId(row.folderId!),
    title: row.title,
    pinnedAtUtc: row.pinnedAtUtc == null
        ? null
        : dateTimeFromUtcMicros(row.pinnedAtUtc!),
    deletedAtUtc: row.deletedAtUtc == null
        ? null
        : dateTimeFromUtcMicros(row.deletedAtUtc!),
    createdAtUtc: dateTimeFromUtcMicros(row.createdAtUtc),
    updatedAtUtc: dateTimeFromUtcMicros(row.updatedAtUtc),
    rowVersion: row.rowVersion,
  );

  ReminderModel mapReminder(ReminderRow row) => ReminderModel(
    id: ReminderId(row.id),
    taskId: TaskId(row.taskId),
    scheduledLocalDateTime: row.scheduledLocalDateTime,
    scheduledZoneId: row.scheduledZoneId,
    scheduledAtUtc: dateTimeFromUtcMicros(row.scheduledAtUtc),
    snoozedUntilUtc: row.snoozedUntilUtc == null
        ? null
        : dateTimeFromUtcMicros(row.snoozedUntilUtc!),
    soundEnabled: row.soundEnabled,
    vibrationEnabled: row.vibrationEnabled,
    status: row.status,
    pauseReason: row.pauseReason,
    scheduleRevision: row.scheduleRevision,
  );
}

final class DriftTaskRepository extends _RepositoryBase
    implements TaskRepository {
  DriftTaskRepository(super.db, {super.clock, super.ids});

  @override
  Stream<List<TaskModel>> watchOpenTasks() {
    final query = db.select(db.tasks)
      ..where(
        (task) =>
            task.deletedAtUtc.isNull() &
            (task.status.equalsValue(TaskStatus.active) |
                task.status.equalsValue(TaskStatus.completionPending)),
      )
      ..orderBy([
        (task) => OrderingTerm(expression: task.manualRank),
        (task) => OrderingTerm(expression: task.id),
      ]);
    return query.watch().map((rows) => rows.map(mapTask).toList());
  }

  @override
  Future<TaskModel?> getTask(TaskId id) async {
    final row = await (db.select(
      db.tasks,
    )..where((task) => task.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : mapTask(row);
  }

  @override
  Future<TaskModel> createTask(TaskDraft draft) async {
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ValidationException('事项标题不能为空。');
    }
    try {
      validateIsoDate(draft.dueLocalDate);
    } on FormatException catch (error) {
      throw ValidationException(error.message.toString());
    }

    return db.transaction(() async {
      final taskId = ids.next();
      final documentId = ids.next();
      final now = nowMicros;
      final maxRank = db.tasks.manualRank.max();
      final maxRankRow =
          await (db.selectOnly(db.tasks)
                ..addColumns([maxRank])
                ..where(db.tasks.deletedAtUtc.isNull()))
              .getSingle();
      final manualRank = (maxRankRow.read(maxRank) ?? 0) + 1024;
      final hash = await sha256Hex({
        'title': title,
        'dueLocalDate': draft.dueLocalDate,
        'planText': draft.planText,
        'body': const <Object?>[],
        'status': TaskStatus.active.name,
      });

      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              id: documentId,
              kind: DocumentKind.taskBody,
              semanticHash: _zeroHash,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: taskId,
              documentId: documentId,
              title: title,
              dueLocalDate: Value(draft.dueLocalDate),
              planText: Value(draft.planText),
              status: TaskStatus.active,
              manualRank: manualRank,
              semanticHash: hash,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      await putSearchRecord(
        scope: SearchScope.task,
        entityId: taskId,
        documentId: documentId,
        title: title,
        body: draft.planText,
        dateKey: draft.dueLocalDate ?? '',
      );
      final row = await (db.select(
        db.tasks,
      )..where((task) => task.id.equals(taskId))).getSingle();
      return mapTask(row);
    });
  }

  @override
  Future<TaskModel> updateTask(
    TaskId id,
    TaskUpdate update, {
    required int expectedVersion,
  }) async {
    final title = update.title.trim();
    if (title.isEmpty) {
      throw const ValidationException('事项标题不能为空。');
    }
    try {
      validateIsoDate(update.dueLocalDate);
    } on FormatException catch (error) {
      throw ValidationException(error.message.toString());
    }

    return db.transaction(() async {
      final current = await (db.select(
        db.tasks,
      )..where((task) => task.id.equals(id.value))).getSingleOrNull();
      if (current == null) throw const NotFoundException('事项不存在。');
      if (current.rowVersion != expectedVersion) {
        throw const StateConflictException('事项已在其他操作中更新。');
      }
      if (current.status == TaskStatus.trashed) {
        throw const StateConflictException('最近删除中的事项不能编辑。');
      }
      final body = await documentPlainText(current.documentId);
      final hash = await sha256Hex({
        'title': title,
        'dueLocalDate': update.dueLocalDate,
        'planText': update.planText,
        'body': body,
        'status': current.status.name,
      });
      final affected =
          await (db.update(db.tasks)..where(
                (task) =>
                    task.id.equals(id.value) &
                    task.rowVersion.equals(expectedVersion),
              ))
              .write(
                TasksCompanion(
                  title: Value(title),
                  dueLocalDate: Value(update.dueLocalDate),
                  planText: Value(update.planText),
                  semanticHash: Value(hash),
                  updatedAtUtc: Value(nowMicros),
                  rowVersion: Value(expectedVersion + 1),
                ),
              );
      if (affected != 1) {
        throw const StateConflictException('事项已在其他操作中更新。');
      }
      await putSearchRecord(
        scope: SearchScope.task,
        entityId: id.value,
        documentId: current.documentId,
        title: title,
        body: '${update.planText}\n$body',
        dateKey: update.dueLocalDate ?? '',
      );
      return mapTask(
        await (db.select(
          db.tasks,
        )..where((task) => task.id.equals(id.value))).getSingle(),
      );
    });
  }

  @override
  Future<ReminderModel?> getReminder(TaskId taskId) async {
    final row =
        await (db.select(db.reminders)
              ..where((reminder) => reminder.taskId.equals(taskId.value)))
            .getSingleOrNull();
    return row == null ? null : mapReminder(row);
  }

  @override
  Future<ReminderModel> setReminder(ReminderDraft draft) async {
    if (!draft.scheduledAtUtc.toUtc().isAfter(clock.nowUtc())) {
      throw const ValidationException('提醒时间必须晚于当前时间。');
    }
    return db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(draft.taskId.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      if (task.status != TaskStatus.active) {
        throw const StateConflictException('只有开启中的事项可以设置提醒。');
      }
      final current =
          await (db.select(db.reminders)
                ..where((row) => row.taskId.equals(draft.taskId.value)))
              .getSingleOrNull();
      final now = nowMicros;
      final revision = (current?.scheduleRevision ?? 0) + 1;
      final reminderId = current?.id ?? ids.next();
      if (current == null) {
        await db
            .into(db.reminders)
            .insert(
              RemindersCompanion.insert(
                id: reminderId,
                taskId: draft.taskId.value,
                scheduledLocalDateTime: draft.scheduledLocalDateTime,
                scheduledZoneId: draft.scheduledZoneId,
                scheduledAtUtc: utcMicros(draft.scheduledAtUtc),
                soundEnabled: draft.soundEnabled,
                vibrationEnabled: draft.vibrationEnabled,
                status: ReminderStatus.scheduled,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      } else {
        await (db.update(
          db.reminders,
        )..where((row) => row.id.equals(current.id))).write(
          RemindersCompanion(
            scheduledLocalDateTime: Value(draft.scheduledLocalDateTime),
            scheduledZoneId: Value(draft.scheduledZoneId),
            scheduledAtUtc: Value(utcMicros(draft.scheduledAtUtc)),
            snoozedUntilUtc: const Value(null),
            soundEnabled: Value(draft.soundEnabled),
            vibrationEnabled: Value(draft.vibrationEnabled),
            status: const Value(ReminderStatus.scheduled),
            pauseReason: const Value(null),
            snoozeCount: const Value(0),
            scheduleRevision: Value(revision),
            updatedAtUtc: Value(now),
            rowVersion: Value(current.rowVersion + 1),
          ),
        );
      }
      await enqueueJob(
        kind: PlatformJobKind.scheduleReminder,
        aggregateId: reminderId,
        aggregateRevision: revision,
        payload: {
          'reminderId': reminderId,
          'taskId': draft.taskId.value,
          'scheduledAtUtc': utcMicros(draft.scheduledAtUtc),
        },
      );
      final row = await (db.select(
        db.reminders,
      )..where((reminder) => reminder.id.equals(reminderId))).getSingle();
      return mapReminder(row);
    });
  }

  @override
  Future<void> removeReminder(TaskId taskId) async {
    await db.transaction(() async {
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(taskId.value))).getSingleOrNull();
      if (reminder == null) return;
      final revision = reminder.scheduleRevision + 1;
      await (db.update(
        db.reminders,
      )..where((row) => row.id.equals(reminder.id))).write(
        RemindersCompanion(
          status: const Value(ReminderStatus.cancelled),
          pauseReason: const Value(null),
          scheduleRevision: Value(revision),
          updatedAtUtc: Value(nowMicros),
          rowVersion: Value(reminder.rowVersion + 1),
        ),
      );
      await enqueueJob(
        kind: PlatformJobKind.cancelReminder,
        aggregateId: reminder.id,
        aggregateRevision: revision,
        payload: {'reminderId': reminder.id, 'reason': 'removed'},
      );
    });
  }

  @override
  Future<void> closeTask(
    TaskId id, {
    required String localDate,
    required String localTime,
    required String zoneId,
  }) async {
    try {
      validateIsoDate(localDate);
      validateLocalTime(localTime);
    } on FormatException catch (error) {
      throw ValidationException(error.message.toString());
    }
    if (zoneId.trim().isEmpty) {
      throw const ValidationException('关闭事项时必须记录时区。');
    }
    await db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      if (task.status != TaskStatus.active) {
        throw const StateConflictException('只有开启中的事项可以关闭。');
      }
      final now = nowMicros;
      final hash = await sha256Hex({
        'title': task.title,
        'dueLocalDate': task.dueLocalDate,
        'planText': task.planText,
        'status': TaskStatus.completionPending.name,
      });
      await (db.update(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).write(
        TasksCompanion(
          status: const Value(TaskStatus.completionPending),
          closedAtUtc: Value(now),
          closedLocalDate: Value(localDate),
          closedLocalTime: Value(localTime),
          closedZoneId: Value(zoneId),
          semanticHash: Value(hash),
          updatedAtUtc: Value(now),
          rowVersion: Value(task.rowVersion + 1),
        ),
      );
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(id.value))).getSingleOrNull();
      if (reminder != null && reminder.status != ReminderStatus.cancelled) {
        final revision = reminder.scheduleRevision + 1;
        await (db.update(
          db.reminders,
        )..where((row) => row.id.equals(reminder.id))).write(
          RemindersCompanion(
            status: const Value(ReminderStatus.paused),
            pauseReason: const Value(ReminderPauseReason.taskClosed),
            scheduleRevision: Value(revision),
            updatedAtUtc: Value(now),
            rowVersion: Value(reminder.rowVersion + 1),
          ),
        );
        await enqueueJob(
          kind: PlatformJobKind.cancelReminder,
          aggregateId: reminder.id,
          aggregateRevision: revision,
          payload: {'reminderId': reminder.id, 'reason': 'taskClosed'},
        );
      }
    });
  }

  @override
  Future<void> reopenTask(TaskId id) async {
    await db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      if (task.status != TaskStatus.completionPending) {
        throw const StateConflictException('事项不处于关闭待处理状态。');
      }
      final now = nowMicros;
      await (db.update(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).write(
        TasksCompanion(
          status: const Value(TaskStatus.active),
          closedAtUtc: const Value(null),
          closedLocalDate: const Value(null),
          closedLocalTime: const Value(null),
          closedZoneId: const Value(null),
          updatedAtUtc: Value(now),
          rowVersion: Value(task.rowVersion + 1),
        ),
      );
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(id.value))).getSingleOrNull();
      if (reminder == null ||
          reminder.pauseReason != ReminderPauseReason.taskClosed) {
        return;
      }
      final revision = reminder.scheduleRevision + 1;
      final isFuture = reminder.scheduledAtUtc > now;
      await (db.update(
        db.reminders,
      )..where((row) => row.id.equals(reminder.id))).write(
        RemindersCompanion(
          status: Value(
            isFuture ? ReminderStatus.scheduled : ReminderStatus.expired,
          ),
          pauseReason: const Value(null),
          scheduleRevision: Value(revision),
          updatedAtUtc: Value(now),
          rowVersion: Value(reminder.rowVersion + 1),
        ),
      );
      if (isFuture) {
        await enqueueJob(
          kind: PlatformJobKind.scheduleReminder,
          aggregateId: reminder.id,
          aggregateRevision: revision,
          payload: {'reminderId': reminder.id, 'reason': 'taskReopened'},
        );
      }
    });
  }

  @override
  Future<void> moveTaskToTrash(TaskId id) async {
    await db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      if (task.status == TaskStatus.trashed) return;
      final now = nowMicros;
      final context = {
        'status': task.status.name,
        'manualRank': task.manualRank,
        'closedAtUtc': task.closedAtUtc,
        'closedLocalDate': task.closedLocalDate,
        'closedLocalTime': task.closedLocalTime,
        'closedZoneId': task.closedZoneId,
      };
      final snapshotHash = await sha256Hex(context);
      await (db.update(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).write(
        TasksCompanion(
          status: const Value(TaskStatus.trashed),
          deletedAtUtc: Value(now),
          updatedAtUtc: Value(now),
          rowVersion: Value(task.rowVersion + 1),
        ),
      );
      await db
          .into(db.trashEntries)
          .insert(
            TrashEntriesCompanion.insert(
              id: ids.next(),
              entityType: TrashEntityType.task,
              entityId: id.value,
              deletedAtUtc: now,
              purgeAfterUtc: now + const Duration(days: 30).inMicroseconds,
              restoreContextJson: canonicalJson(context),
              snapshotSha256: snapshotHash,
            ),
          );
      await (db.delete(db.searchRecords)..where(
            (row) =>
                row.scope.equalsValue(SearchScope.task) &
                row.entityId.equals(id.value),
          ))
          .go();
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(id.value))).getSingleOrNull();
      if (reminder != null && reminder.status != ReminderStatus.cancelled) {
        final revision = reminder.scheduleRevision + 1;
        await (db.update(
          db.reminders,
        )..where((row) => row.id.equals(reminder.id))).write(
          RemindersCompanion(
            status: const Value(ReminderStatus.paused),
            pauseReason: const Value(ReminderPauseReason.user),
            scheduleRevision: Value(revision),
            updatedAtUtc: Value(now),
            rowVersion: Value(reminder.rowVersion + 1),
          ),
        );
        await enqueueJob(
          kind: PlatformJobKind.cancelReminder,
          aggregateId: reminder.id,
          aggregateRevision: revision,
          payload: {'reminderId': reminder.id, 'reason': 'taskTrashed'},
        );
      }
    });
  }

  @override
  Future<void> restoreTask(TaskId id) async {
    await db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      final trash =
          await (db.select(db.trashEntries)..where(
                (row) =>
                    row.entityType.equalsValue(TrashEntityType.task) &
                    row.entityId.equals(id.value),
              ))
              .getSingleOrNull();
      if (trash == null || task.status != TaskStatus.trashed) {
        throw const StateConflictException('事项不在最近删除中。');
      }
      final context =
          jsonDecode(trash.restoreContextJson) as Map<String, Object?>;
      final previous = TaskStatus.values.byName(context['status']! as String);
      final now = nowMicros;
      await (db.update(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).write(
        TasksCompanion(
          status: Value(previous),
          manualRank: Value(context['manualRank']! as int),
          closedAtUtc: Value(context['closedAtUtc'] as int?),
          closedLocalDate: Value(context['closedLocalDate'] as String?),
          closedLocalTime: Value(context['closedLocalTime'] as String?),
          closedZoneId: Value(context['closedZoneId'] as String?),
          deletedAtUtc: const Value(null),
          updatedAtUtc: Value(now),
          rowVersion: Value(task.rowVersion + 1),
        ),
      );
      await (db.delete(
        db.trashEntries,
      )..where((row) => row.id.equals(trash.id))).go();
      final body = await documentPlainText(task.documentId);
      await putSearchRecord(
        scope: SearchScope.task,
        entityId: task.id,
        documentId: task.documentId,
        title: task.title,
        body: '${task.planText}\n$body',
        dateKey: task.dueLocalDate ?? '',
      );
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(task.id))).getSingleOrNull();
      if (reminder != null &&
          reminder.status == ReminderStatus.paused &&
          reminder.pauseReason == ReminderPauseReason.user) {
        final revision = reminder.scheduleRevision + 1;
        final shouldSchedule =
            previous == TaskStatus.active && reminder.scheduledAtUtc > now;
        final reminderStatus = shouldSchedule
            ? ReminderStatus.scheduled
            : previous == TaskStatus.completionPending
            ? ReminderStatus.paused
            : ReminderStatus.expired;
        final pauseReason = previous == TaskStatus.completionPending
            ? ReminderPauseReason.taskClosed
            : null;
        await (db.update(
          db.reminders,
        )..where((row) => row.id.equals(reminder.id))).write(
          RemindersCompanion(
            status: Value(reminderStatus),
            pauseReason: Value(pauseReason),
            scheduleRevision: Value(revision),
            updatedAtUtc: Value(now),
            rowVersion: Value(reminder.rowVersion + 1),
          ),
        );
        if (shouldSchedule) {
          await enqueueJob(
            kind: PlatformJobKind.scheduleReminder,
            aggregateId: reminder.id,
            aggregateRevision: revision,
            payload: {'reminderId': reminder.id, 'reason': 'taskRestored'},
          );
        }
      }
    });
  }

  @override
  Future<int> purgeExpiredTrash() async {
    return db.transaction(() async {
      final expired =
          await (db.select(db.trashEntries)..where(
                (row) => row.purgeAfterUtc.isSmallerOrEqualValue(nowMicros),
              ))
              .get();
      var purged = 0;
      for (final entry in expired) {
        if (entry.entityType == TrashEntityType.task) {
          final task = await (db.select(
            db.tasks,
          )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
          if (task != null && task.status == TaskStatus.trashed) {
            await (db.delete(
              db.tasks,
            )..where((row) => row.id.equals(task.id))).go();
            await (db.delete(
              db.documents,
            )..where((row) => row.id.equals(task.documentId))).go();
          }
        } else {
          final note = await (db.select(
            db.notes,
          )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
          if (note != null && note.deletedAtUtc != null) {
            await (db.delete(
              db.notes,
            )..where((row) => row.id.equals(note.id))).go();
            await (db.delete(
              db.documents,
            )..where((row) => row.id.equals(note.documentId))).go();
          }
        }
        await (db.delete(
          db.trashEntries,
        )..where((row) => row.id.equals(entry.id))).go();
        purged++;
      }
      return purged;
    });
  }
}

const _zeroHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

final class DriftNoteRepository extends _RepositoryBase
    implements NoteRepository {
  DriftNoteRepository(super.db, {super.clock, super.ids});

  @override
  Stream<List<NoteModel>> watchNotes() {
    final query = db.select(db.notes)
      ..where((note) => note.deletedAtUtc.isNull())
      ..orderBy([
        (note) =>
            OrderingTerm(expression: note.pinnedAtUtc, mode: OrderingMode.desc),
        (note) => OrderingTerm(
          expression: note.updatedAtUtc,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(mapNote).toList());
  }

  @override
  Future<NoteModel> createNote(NoteDraft draft) async {
    return db.transaction(() async {
      if (draft.folderId != null) {
        final folderExists =
            await (db.select(db.folders)
                  ..where((row) => row.id.equals(draft.folderId!.value)))
                .getSingleOrNull();
        if (folderExists == null) {
          throw const ValidationException('所选文件夹不存在。');
        }
      }
      final noteId = ids.next();
      final documentId = ids.next();
      final now = nowMicros;
      final bodyHash = await sha256Hex({'body': draft.body});
      final noteHash = await sha256Hex({
        'title': draft.title,
        'folderId': draft.folderId?.value,
        'body': draft.body,
      });
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              id: documentId,
              kind: DocumentKind.note,
              semanticHash: bodyHash,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      if (draft.body.isNotEmpty) {
        await db
            .into(db.documentBlocks)
            .insert(
              DocumentBlocksCompanion.insert(
                id: ids.next(),
                documentId: documentId,
                sortRank: 1024,
                blockType: DocumentBlockType.paragraph,
                plainText: Value(draft.body),
                semanticHash: bodyHash,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      }
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              id: noteId,
              documentId: documentId,
              folderId: Value(draft.folderId?.value),
              title: Value(draft.title),
              semanticHash: noteHash,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      await putSearchRecord(
        scope: SearchScope.note,
        entityId: noteId,
        documentId: documentId,
        title: draft.title,
        body: draft.body,
      );
      return mapNote(
        await (db.select(
          db.notes,
        )..where((row) => row.id.equals(noteId))).getSingle(),
      );
    });
  }

  @override
  Future<NoteModel> updateNote(
    NoteId id,
    NoteUpdate update, {
    required int expectedVersion,
  }) async {
    return db.transaction(() async {
      final note = await (db.select(
        db.notes,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (note == null) throw const NotFoundException('笔记不存在。');
      if (note.deletedAtUtc != null) {
        throw const StateConflictException('最近删除中的笔记不能编辑。');
      }
      if (note.rowVersion != expectedVersion) {
        throw const StateConflictException('笔记已在其他操作中更新。');
      }
      if (update.folderId != null) {
        final folderExists =
            await (db.select(db.folders)
                  ..where((row) => row.id.equals(update.folderId!.value)))
                .getSingleOrNull();
        if (folderExists == null) {
          throw const ValidationException('所选文件夹不存在。');
        }
      }
      final body = await documentPlainText(note.documentId);
      final hash = await sha256Hex({
        'title': update.title,
        'folderId': update.folderId?.value,
        'body': body,
      });
      final affected =
          await (db.update(db.notes)..where(
                (row) =>
                    row.id.equals(id.value) &
                    row.rowVersion.equals(expectedVersion),
              ))
              .write(
                NotesCompanion(
                  folderId: Value(update.folderId?.value),
                  title: Value(update.title),
                  semanticHash: Value(hash),
                  updatedAtUtc: Value(nowMicros),
                  rowVersion: Value(expectedVersion + 1),
                ),
              );
      if (affected != 1) {
        throw const StateConflictException('笔记已在其他操作中更新。');
      }
      await putSearchRecord(
        scope: SearchScope.note,
        entityId: note.id,
        documentId: note.documentId,
        title: update.title,
        body: body,
      );
      return mapNote(
        await (db.select(
          db.notes,
        )..where((row) => row.id.equals(id.value))).getSingle(),
      );
    });
  }

  @override
  Future<FolderModel> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('文件夹名称不能为空。');
    }
    return db.transaction(() async {
      final maxRank = db.folders.sortRank.max();
      final result = await (db.selectOnly(
        db.folders,
      )..addColumns([maxRank])).getSingle();
      final rank = (result.read(maxRank) ?? 0) + 1024;
      final id = ids.next();
      final now = nowMicros;
      await db
          .into(db.folders)
          .insert(
            FoldersCompanion.insert(
              id: id,
              name: trimmed,
              normalizedName: normalizedSearchText(trimmed),
              sortRank: rank,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      return FolderModel(id: FolderId(id), name: trimmed, sortRank: rank);
    });
  }

  @override
  Future<void> deleteFolder(FolderId id) async {
    await db.transaction(() async {
      final folder = await (db.select(
        db.folders,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (folder == null) throw const NotFoundException('文件夹不存在。');
      await (db.update(
        db.notes,
      )..where((row) => row.folderId.equals(id.value))).write(
        NotesCompanion(
          folderId: const Value(null),
          updatedAtUtc: Value(nowMicros),
        ),
      );
      await (db.delete(
        db.folders,
      )..where((row) => row.id.equals(id.value))).go();
    });
  }

  @override
  Future<void> moveNoteToTrash(NoteId id) async {
    await db.transaction(() async {
      final note = await (db.select(
        db.notes,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (note == null) throw const NotFoundException('笔记不存在。');
      if (note.deletedAtUtc != null) return;
      final now = nowMicros;
      final context = {
        'folderId': note.folderId,
        'pinnedAtUtc': note.pinnedAtUtc,
      };
      await (db.update(
        db.notes,
      )..where((row) => row.id.equals(id.value))).write(
        NotesCompanion(
          deletedAtUtc: Value(now),
          updatedAtUtc: Value(now),
          rowVersion: Value(note.rowVersion + 1),
        ),
      );
      await db
          .into(db.trashEntries)
          .insert(
            TrashEntriesCompanion.insert(
              id: ids.next(),
              entityType: TrashEntityType.note,
              entityId: note.id,
              deletedAtUtc: now,
              purgeAfterUtc: now + const Duration(days: 30).inMicroseconds,
              restoreContextJson: canonicalJson(context),
              snapshotSha256: await sha256Hex(context),
            ),
          );
      await (db.delete(db.searchRecords)..where(
            (row) =>
                row.scope.equalsValue(SearchScope.note) &
                row.entityId.equals(note.id),
          ))
          .go();
    });
  }

  @override
  Future<void> restoreNote(NoteId id) async {
    await db.transaction(() async {
      final note = await (db.select(
        db.notes,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (note == null) throw const NotFoundException('笔记不存在。');
      final trash =
          await (db.select(db.trashEntries)..where(
                (row) =>
                    row.entityType.equalsValue(TrashEntityType.note) &
                    row.entityId.equals(id.value),
              ))
              .getSingleOrNull();
      if (trash == null || note.deletedAtUtc == null) {
        throw const StateConflictException('笔记不在最近删除中。');
      }
      final context =
          jsonDecode(trash.restoreContextJson) as Map<String, Object?>;
      final requestedFolder = context['folderId'] as String?;
      String? folderId;
      if (requestedFolder != null) {
        final folder = await (db.select(
          db.folders,
        )..where((row) => row.id.equals(requestedFolder))).getSingleOrNull();
        folderId = folder?.id;
      }
      await (db.update(
        db.notes,
      )..where((row) => row.id.equals(id.value))).write(
        NotesCompanion(
          folderId: Value(folderId),
          pinnedAtUtc: Value(context['pinnedAtUtc'] as int?),
          deletedAtUtc: const Value(null),
          updatedAtUtc: Value(nowMicros),
          rowVersion: Value(note.rowVersion + 1),
        ),
      );
      await (db.delete(
        db.trashEntries,
      )..where((row) => row.id.equals(trash.id))).go();
      await putSearchRecord(
        scope: SearchScope.note,
        entityId: note.id,
        documentId: note.documentId,
        title: note.title,
        body: await documentPlainText(note.documentId),
      );
    });
  }
}

final class DriftDocumentRepository extends _RepositoryBase
    implements DocumentRepository {
  DriftDocumentRepository(super.db, {super.clock, super.ids});

  @override
  Future<List<DocumentBlockModel>> getBlocks(DocumentId documentId) async {
    final query = db.select(db.documentBlocks)
      ..where((row) => row.documentId.equals(documentId.value))
      ..orderBy([
        (row) => OrderingTerm(expression: row.sortRank),
        (row) => OrderingTerm(expression: row.id),
      ]);
    return (await query.get()).map(_mapBlock).toList(growable: false);
  }

  @override
  Stream<List<DocumentBlockModel>> watchBlocks(DocumentId documentId) {
    final query = db.select(db.documentBlocks)
      ..where((row) => row.documentId.equals(documentId.value))
      ..orderBy([
        (row) => OrderingTerm(expression: row.sortRank),
        (row) => OrderingTerm(expression: row.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_mapBlock).toList(growable: false),
    );
  }

  @override
  Future<int> replaceBlocks(
    DocumentId documentId,
    List<DocumentBlockModel> blocks, {
    required int expectedRevision,
    Map<String, List<String>> replacements = const {},
  }) async {
    return db.transaction(() async {
      final document = await (db.select(
        db.documents,
      )..where((row) => row.id.equals(documentId.value))).getSingleOrNull();
      if (document == null) throw const NotFoundException('文档不存在。');
      if (document.revision != expectedRevision) {
        throw const StateConflictException('文档已在其他操作中更新。');
      }
      if (blocks.any((block) => block.documentId != documentId)) {
        throw const ValidationException('文档块不属于目标文档。');
      }
      final idsInPatch = blocks.map((block) => block.id).toSet();
      if (idsInPatch.length != blocks.length) {
        throw const ValidationException('文档块 ID 不能重复。');
      }

      final oldRows = await (db.select(
        db.documentBlocks,
      )..where((row) => row.documentId.equals(documentId.value))).get();
      final oldById = {for (final row in oldRows) row.id: row};
      final snapshot = canonicalJson({
        'documentId': document.id,
        'revision': document.revision,
        'blocks': [
          for (final row in oldRows)
            {
              'id': row.id,
              'parentBlockId': row.parentBlockId,
              'sortRank': row.sortRank,
              'blockType': row.blockType.name,
              'plainText': row.plainText,
              'payloadJson': row.payloadJson,
              'attributesJson': row.attributesJson,
              'isChecked': row.isChecked,
            },
        ],
      });
      await db
          .into(db.documentRevisions)
          .insert(
            DocumentRevisionsCompanion.insert(
              id: ids.next(),
              documentId: document.id,
              revision: document.revision,
              reason: 'beforeDestructiveEdit',
              snapshotBlob: Uint8List.fromList(utf8.encode(snapshot)),
              snapshotSha256: await sha256Hex(jsonDecode(snapshot)),
              createdAtUtc: nowMicros,
            ),
          );

      final deletedIds = oldRows
          .map((row) => row.id)
          .where((id) => !idsInPatch.contains(id))
          .toSet();
      for (final replacement in replacements.entries) {
        if (!deletedIds.contains(replacement.key) ||
            replacement.value.toSet().length != replacement.value.length ||
            replacement.value.any((target) => !idsInPatch.contains(target))) {
          throw const ValidationException('文档块替换映射无效。');
        }
      }
      final now = nowMicros;
      final blocksToWrite = blocks
          .where((block) {
            final old = oldById[block.id];
            return old == null || !_samePersistedBlock(old, block);
          })
          .toList(growable: false);
      final semanticChangedBlockIds = <String>{
        for (final block in blocksToWrite)
          if (oldById[block.id] == null ||
              !_sameSemanticBlock(oldById[block.id]!, block))
            block.id,
      };
      final calculatedHashes = await Future.wait<String>([
        for (final block in blocksToWrite)
          semanticChangedBlockIds.contains(block.id)
              ? sha256Hex(_blockHashInput(block))
              : Future<String>.value(oldById[block.id]!.semanticHash),
      ]);
      final changedHashes = <String, String>{
        for (var index = 0; index < blocksToWrite.length; index++)
          blocksToWrite[index].id: calculatedHashes[index],
      };
      final blockHashes = <String, String>{
        for (final block in blocks)
          block.id: changedHashes[block.id] ?? oldById[block.id]!.semanticHash,
      };
      if (blocksToWrite.isNotEmpty) {
        await db.batch((batch) {
          for (final block in blocksToWrite) {
            final hash = changedHashes[block.id]!;
            final old = oldById[block.id];
            if (old == null) {
              batch.customStatement(
                'INSERT INTO document_blocks '
                '(id, document_id, parent_block_id, sort_rank, block_type, '
                'plain_text, payload_json, attributes_json, is_checked, '
                'semantic_hash, created_at_utc, updated_at_utc, row_version) '
                'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
                <Object?>[
                  block.id,
                  document.id,
                  block.parentBlockId,
                  block.sortRank,
                  block.blockType.name,
                  block.plainText,
                  block.payloadJson,
                  block.attributesJson,
                  _sqliteBool(block.isChecked),
                  hash,
                  now,
                  now,
                ],
              );
            } else {
              batch.customStatement(
                'UPDATE document_blocks SET parent_block_id = ?, '
                'sort_rank = ?, block_type = ?, plain_text = ?, '
                'payload_json = ?, attributes_json = ?, is_checked = ?, '
                'semantic_hash = ?, updated_at_utc = ?, row_version = ? '
                'WHERE id = ? AND document_id = ?',
                <Object?>[
                  block.parentBlockId,
                  block.sortRank,
                  block.blockType.name,
                  block.plainText,
                  block.payloadJson,
                  block.attributesJson,
                  _sqliteBool(block.isChecked),
                  hash,
                  now,
                  old.rowVersion + 1,
                  block.id,
                  document.id,
                ],
              );
            }
          }
        });
      }
      await _remapOrDetachAnchors(deletedIds, replacements);
      await _updateAnchorHashes(blockHashes, <String>{
        ...semanticChangedBlockIds,
        for (final targets in replacements.values) ...targets,
      }, now);
      if (deletedIds.isNotEmpty) {
        for (final chunk in _chunks(deletedIds)) {
          await (db.delete(db.documentBlocks)..where(
                (row) =>
                    row.documentId.equals(document.id) & row.id.isIn(chunk),
              ))
              .go();
        }
      }

      final canonicalBlocks = [
        for (final block in blocks)
          {
            'id': block.id,
            'parentBlockId': block.parentBlockId,
            'sortRank': block.sortRank,
            'blockType': block.blockType.name,
            'plainText': block.plainText,
            'payloadJson': block.payloadJson,
            'attributesJson': block.attributesJson,
            'isChecked': block.isChecked,
          },
      ];
      final newRevision = expectedRevision + 1;
      await (db.update(db.documents)..where(
            (row) =>
                row.id.equals(document.id) &
                row.revision.equals(expectedRevision),
          ))
          .write(
            DocumentsCompanion(
              revision: Value(newRevision),
              semanticHash: Value(await sha256Hex(canonicalBlocks)),
              updatedAtUtc: Value(now),
              rowVersion: Value(document.rowVersion + 1),
            ),
          );
      if (document.kind == DocumentKind.past) {
        await _reconcilePastEventStates(document.id);
      }
      await _refreshOwnerSearch(document);
      return newRevision;
    });
  }

  Future<void> _remapOrDetachAnchors(
    Set<String> deletedIds,
    Map<String, List<String>> replacements,
  ) async {
    if (deletedIds.isEmpty) return;
    final targetSourceCounts = <String, int>{};
    for (final oldId in deletedIds) {
      for (final target in replacements[oldId] ?? const <String>[]) {
        targetSourceCounts.update(
          target,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final links = <PastAnchorLinkRow>[];
    for (final chunk in _chunks(deletedIds)) {
      links.addAll(
        await (db.select(
          db.pastAnchorLinks,
        )..where((link) => link.currentBlockId.isIn(chunk))).get(),
      );
    }
    if (links.isEmpty) return;
    final now = nowMicros;
    await db.batch((batch) {
      for (final link in links) {
        final oldId = link.currentBlockId!;
        final targets = replacements[oldId] ?? const <String>[];
        if (targets.isEmpty) {
          batch.customStatement(
            'UPDATE past_anchor_links SET current_block_id = NULL, '
            'link_state = ?, updated_at_utc = ? WHERE id = ?',
            <Object?>[AnchorLinkState.deleted.name, now, link.id],
          );
          continue;
        }
        batch.customStatement(
          'UPDATE past_anchor_links SET current_block_id = ?, '
          'last_known_block_id = ?, relation = ?, link_state = ?, '
          'updated_at_utc = ? WHERE id = ?',
          <Object?>[
            targets.first,
            targets.first,
            _anchorRelationFor(
              sourceTargetCount: targets.length,
              targetSourceCount: targetSourceCounts[targets.first] ?? 1,
            ).name,
            AnchorLinkState.linked.name,
            now,
            link.id,
          ],
        );
        for (final target in targets.skip(1)) {
          batch.customStatement(
            'INSERT INTO past_anchor_links '
            '(id, part_id, current_block_id, last_known_block_id, relation, '
            'link_state, current_sha256, updated_at_utc) '
            'VALUES (?, ?, ?, ?, ?, ?, NULL, ?)',
            <Object?>[
              ids.next(),
              link.partId,
              target,
              target,
              _anchorRelationFor(
                sourceTargetCount: targets.length,
                targetSourceCount: targetSourceCounts[target] ?? 1,
              ).name,
              AnchorLinkState.linked.name,
              now,
            ],
          );
        }
      }
    });
  }

  Future<void> _updateAnchorHashes(
    Map<String, String> blockHashes,
    Set<String> candidateBlockIds,
    int now,
  ) async {
    if (candidateBlockIds.isEmpty) return;
    final linkedBlockIds = <String>{};
    for (final chunk in _chunks(candidateBlockIds)) {
      final links = await (db.select(
        db.pastAnchorLinks,
      )..where((link) => link.currentBlockId.isIn(chunk))).get();
      linkedBlockIds.addAll(links.map((link) => link.currentBlockId!));
    }
    if (linkedBlockIds.isEmpty) return;
    await db.batch((batch) {
      for (final blockId in linkedBlockIds) {
        batch.customStatement(
          'UPDATE past_anchor_links SET current_sha256 = ?, '
          'updated_at_utc = ? WHERE current_block_id = ?',
          <Object?>[blockHashes[blockId], now, blockId],
        );
      }
    });
  }

  AnchorRelation _anchorRelationFor({
    required int sourceTargetCount,
    required int targetSourceCount,
  }) {
    if (targetSourceCount > 1) return AnchorRelation.merged;
    if (sourceTargetCount > 1) return AnchorRelation.split;
    return AnchorRelation.replacement;
  }

  Future<void> _reconcilePastEventStates(String documentId) async {
    final rows = await db
        .customSelect(
          'SELECT e.id AS event_id, e.anchor_state, e.row_version, '
          'p.id AS part_id, p.original_sha256, l.id AS link_id, '
          'l.current_block_id, l.relation, l.link_state, l.current_sha256 '
          'FROM past_events e '
          'LEFT JOIN past_event_parts p ON p.event_id = e.id '
          'LEFT JOIN past_anchor_links l ON l.part_id = p.id '
          'WHERE e.document_id = ? ORDER BY e.id, p.id, l.id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
          readsFrom: <ResultSetImplementation>{
            db.pastEvents,
            db.pastEventParts,
            db.pastAnchorLinks,
          },
        )
        .get();
    final events = <String, _PastEventReconciliation>{};
    for (final queryRow in rows) {
      final data = queryRow.data;
      final eventId = data['event_id']! as String;
      final event = events.putIfAbsent(
        eventId,
        () => _PastEventReconciliation(
          id: eventId,
          currentState: PastAnchorState.values.byName(
            data['anchor_state']! as String,
          ),
          rowVersion: data['row_version']! as int,
        ),
      );
      final partId = data['part_id'] as String?;
      if (partId == null) continue;
      final part = event.parts.putIfAbsent(
        partId,
        () => _PastPartReconciliation(
          originalSha256: data['original_sha256']! as String,
        ),
      );
      if (data['link_state'] == AnchorLinkState.linked.name &&
          data['current_block_id'] != null) {
        part.activeLinks++;
        if (data['relation'] != AnchorRelation.original.name ||
            data['current_sha256'] != part.originalSha256) {
          part.allActiveLinksOriginal = false;
        }
      }
    }
    final changed = <_PastEventReconciliation>[];
    for (final event in events.values) {
      final hasLinked = event.parts.values.any((part) => part.activeLinks > 0);
      final allOriginal = event.parts.values.every(
        (part) => part.activeLinks == 1 && part.allActiveLinksOriginal,
      );
      event.nextState = !hasLinked
          ? PastAnchorState.detached
          : allOriginal
          ? PastAnchorState.attached
          : PastAnchorState.modified;
      if (event.nextState != event.currentState) changed.add(event);
    }
    if (changed.isEmpty) return;
    final now = nowMicros;
    await db.batch((batch) {
      for (final event in changed) {
        batch.customStatement(
          'UPDATE past_events SET anchor_state = ?, updated_at_utc = ?, '
          'row_version = ? WHERE id = ?',
          <Object?>[event.nextState.name, now, event.rowVersion + 1, event.id],
        );
      }
    });
  }

  Future<void> _refreshOwnerSearch(DocumentRow document) async {
    final body = await documentPlainText(document.id);
    if (document.kind == DocumentKind.taskBody) {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.documentId.equals(document.id))).getSingleOrNull();
      if (task != null && task.deletedAtUtc == null) {
        await putSearchRecord(
          scope: SearchScope.task,
          entityId: task.id,
          documentId: document.id,
          title: task.title,
          body: '${task.planText}\n$body',
          dateKey: task.dueLocalDate ?? '',
        );
      }
    } else if (document.kind == DocumentKind.note) {
      final note = await (db.select(
        db.notes,
      )..where((row) => row.documentId.equals(document.id))).getSingleOrNull();
      if (note != null && note.deletedAtUtc == null) {
        await putSearchRecord(
          scope: SearchScope.note,
          entityId: note.id,
          documentId: document.id,
          title: note.title,
          body: body,
        );
      }
    } else {
      await putSearchRecord(
        scope: SearchScope.past,
        entityId: 'past.main',
        documentId: document.id,
        title: '',
        body: body,
      );
    }
  }

  DocumentBlockModel _mapBlock(DocumentBlockRow row) => DocumentBlockModel(
    id: row.id,
    documentId: DocumentId(row.documentId),
    parentBlockId: row.parentBlockId,
    sortRank: row.sortRank,
    blockType: row.blockType,
    plainText: row.plainText,
    payloadJson: row.payloadJson,
    attributesJson: row.attributesJson,
    isChecked: row.isChecked,
  );

  bool _samePersistedBlock(DocumentBlockRow old, DocumentBlockModel block) =>
      old.parentBlockId == block.parentBlockId &&
      old.sortRank == block.sortRank &&
      old.blockType == block.blockType &&
      old.plainText == block.plainText &&
      old.payloadJson == block.payloadJson &&
      old.attributesJson == block.attributesJson &&
      old.isChecked == block.isChecked;

  bool _sameSemanticBlock(DocumentBlockRow old, DocumentBlockModel block) =>
      old.blockType == block.blockType &&
      old.plainText == block.plainText &&
      old.payloadJson == block.payloadJson &&
      old.attributesJson == block.attributesJson &&
      old.isChecked == block.isChecked;

  Map<String, Object?> _blockHashInput(DocumentBlockModel block) =>
      <String, Object?>{
        'type': block.blockType.name,
        'text': block.plainText,
        'payload': block.payloadJson,
        'attributes': block.attributesJson,
        'checked': block.isChecked,
      };
}

int? _sqliteBool(bool? value) => value == null ? null : (value ? 1 : 0);

Iterable<List<T>> _chunks<T>(Iterable<T> values, {int size = 400}) sync* {
  var chunk = <T>[];
  for (final value in values) {
    chunk.add(value);
    if (chunk.length == size) {
      yield chunk;
      chunk = <T>[];
    }
  }
  if (chunk.isNotEmpty) yield chunk;
}

final class _PastEventReconciliation {
  _PastEventReconciliation({
    required this.id,
    required this.currentState,
    required this.rowVersion,
  });

  final String id;
  final PastAnchorState currentState;
  final int rowVersion;
  final Map<String, _PastPartReconciliation> parts =
      <String, _PastPartReconciliation>{};
  PastAnchorState nextState = PastAnchorState.detached;
}

final class _PastPartReconciliation {
  _PastPartReconciliation({required this.originalSha256});

  final String originalSha256;
  int activeLinks = 0;
  bool allActiveLinksOriginal = true;
}

final class DriftPastRepository extends _RepositoryBase
    implements PastRepository {
  DriftPastRepository(super.db, {super.clock, super.ids});

  @override
  Future<PastEventModel> addClosedTaskToPast(TaskId id) async {
    return db.transaction(() async {
      final task = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals(id.value))).getSingleOrNull();
      if (task == null) throw const NotFoundException('事项不存在。');
      if (task.status != TaskStatus.completionPending ||
          task.closedAtUtc == null ||
          task.closedLocalDate == null ||
          task.closedLocalTime == null ||
          task.closedZoneId == null) {
        throw const StateConflictException('事项尚未处于可加入过往的关闭状态。');
      }
      final pastDocument = await (db.select(
        db.documents,
      )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
      final taskBlocks =
          await (db.select(db.documentBlocks)
                ..where((row) => row.documentId.equals(task.documentId))
                ..orderBy([
                  (row) => OrderingTerm(expression: row.sortRank),
                  (row) => OrderingTerm(expression: row.id),
                ]))
              .get();
      final snapshot = {
        'schema': 1,
        'taskId': task.id,
        'closedAtUtc': task.closedAtUtc,
        'closedLocalDate': task.closedLocalDate,
        'closedLocalTime': task.closedLocalTime,
        'closedZoneId': task.closedZoneId,
        'title': task.title,
        'dueLocalDate': task.dueLocalDate,
        'planText': task.planText,
        'blocks': [
          for (final block in taskBlocks)
            {
              'id': block.id,
              'type': block.blockType.name,
              'text': block.plainText,
              'payloadJson': block.payloadJson,
              'attributesJson': block.attributesJson,
              'checked': block.isChecked,
            },
        ],
      };
      final sourceSnapshotJson = canonicalJson(snapshot);
      final sourceHash = await sha256Hex(snapshot);
      final maxSequence = db.pastEvents.appendSequence.max();
      final sequenceRow = await (db.selectOnly(
        db.pastEvents,
      )..addColumns([maxSequence])).getSingle();
      final appendSequence = (sequenceRow.read(maxSequence) ?? 0) + 1;
      final lastEventQuery = db.select(db.pastEvents)
        ..orderBy([
          (row) => OrderingTerm(
            expression: row.appendSequence,
            mode: OrderingMode.desc,
          ),
        ])
        ..limit(1);
      final lastEvent = await lastEventQuery.getSingleOrNull();
      final maxRank = db.documentBlocks.sortRank.max();
      final rankRow =
          await (db.selectOnly(db.documentBlocks)
                ..addColumns([maxRank])
                ..where(db.documentBlocks.documentId.equals(pastDocument.id)))
              .getSingle();
      var rank = rankRow.read(maxRank) ?? 0;
      final now = nowMicros;
      if (lastEvent?.completionLocalDate != task.closedLocalDate) {
        rank += 1024;
        final headingText = task.closedLocalDate!;
        await db
            .into(db.documentBlocks)
            .insert(
              DocumentBlocksCompanion.insert(
                id: ids.next(),
                documentId: pastDocument.id,
                sortRank: rank,
                blockType: DocumentBlockType.pastDate,
                plainText: Value(headingText),
                attributesJson: Value(
                  canonicalJson({'localDate': task.closedLocalDate}),
                ),
                semanticHash: await sha256Hex({
                  'type': DocumentBlockType.pastDate.name,
                  'text': headingText,
                }),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      }

      final eventId = ids.next();
      await db
          .into(db.pastEvents)
          .insert(
            PastEventsCompanion.insert(
              id: eventId,
              documentId: pastDocument.id,
              sourceTaskId: task.id,
              appendSequence: appendSequence,
              completedAtUtc: task.closedAtUtc!,
              completionLocalDate: task.closedLocalDate!,
              completionZoneId: task.closedZoneId!,
              sourceSnapshotJson: sourceSnapshotJson,
              sourceSha256: sourceHash,
              anchorState: PastAnchorState.attached,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      var sourceOrder = 0;
      Future<void> appendPart({
        required PastPartRole role,
        required String text,
        DocumentBlockType type = DocumentBlockType.pastEntry,
        String payloadJson = '{}',
        String attributesJson = '{}',
        bool? isChecked,
      }) async {
        rank += 1024;
        final blockId = ids.next();
        final blockHash = await sha256Hex({
          'type': type.name,
          'text': text,
          'payload': payloadJson,
          'attributes': attributesJson,
          'checked': isChecked,
        });
        await db
            .into(db.documentBlocks)
            .insert(
              DocumentBlocksCompanion.insert(
                id: blockId,
                documentId: pastDocument.id,
                sortRank: rank,
                blockType: type,
                plainText: Value(text),
                payloadJson: Value(payloadJson),
                attributesJson: Value(attributesJson),
                isChecked: Value(isChecked),
                semanticHash: blockHash,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        final partId = ids.next();
        await db
            .into(db.pastEventParts)
            .insert(
              PastEventPartsCompanion.insert(
                id: partId,
                eventId: eventId,
                role: role,
                sourceOrder: sourceOrder++,
                originalPayloadJson: canonicalJson({
                  'type': type.name,
                  'payloadJson': payloadJson,
                  'attributesJson': attributesJson,
                  'checked': isChecked,
                }),
                originalPlainText: text,
                originalSha256: blockHash,
              ),
            );
        await db
            .into(db.pastAnchorLinks)
            .insert(
              PastAnchorLinksCompanion.insert(
                id: ids.next(),
                partId: partId,
                currentBlockId: Value(blockId),
                lastKnownBlockId: blockId,
                relation: AnchorRelation.original,
                linkState: AnchorLinkState.linked,
                currentSha256: Value(blockHash),
                updatedAtUtc: now,
              ),
            );
      }

      await appendPart(
        role: PastPartRole.time,
        text: task.closedLocalTime!,
        attributesJson: canonicalJson({'role': 'completionTime'}),
      );
      await appendPart(
        role: PastPartRole.title,
        text: task.title,
        attributesJson: canonicalJson({'role': 'taskTitle'}),
      );
      for (final block in taskBlocks) {
        await appendPart(
          role: block.blockType == DocumentBlockType.checklist
              ? PastPartRole.checklist
              : PastPartRole.body,
          text: block.plainText,
          type: block.blockType,
          payloadJson: block.payloadJson,
          attributesJson: block.attributesJson,
          isChecked: block.isChecked,
        );
      }
      if (task.dueLocalDate != null) {
        await appendPart(
          role: PastPartRole.dueDate,
          text: '原计划：${task.dueLocalDate}',
          type: DocumentBlockType.paragraph,
          attributesJson: canonicalJson({'sourceDueDate': task.dueLocalDate}),
        );
      }
      if (task.planText.trim().isNotEmpty) {
        await appendPart(
          role: PastPartRole.plan,
          text: task.planText,
          type: DocumentBlockType.paragraph,
          attributesJson: canonicalJson({'role': 'sourcePlan'}),
        );
      }

      final pastBody = await documentPlainText(pastDocument.id);
      await (db.update(
        db.documents,
      )..where((row) => row.id.equals(pastDocument.id))).write(
        DocumentsCompanion(
          revision: Value(pastDocument.revision + 1),
          semanticHash: Value(await sha256Hex({'body': pastBody})),
          updatedAtUtc: Value(now),
          rowVersion: Value(pastDocument.rowVersion + 1),
        ),
      );
      await putSearchRecord(
        scope: SearchScope.past,
        entityId: 'past.main',
        documentId: pastDocument.id,
        title: '',
        body: pastBody,
        dateKey: task.closedLocalDate!,
      );
      await (db.update(db.tasks)..where((row) => row.id.equals(task.id))).write(
        TasksCompanion(
          status: const Value(TaskStatus.archived),
          archivedAtUtc: Value(now),
          semanticHash: Value(
            await sha256Hex({
              'title': task.title,
              'dueLocalDate': task.dueLocalDate,
              'planText': task.planText,
              'status': TaskStatus.archived.name,
            }),
          ),
          updatedAtUtc: Value(now),
          rowVersion: Value(task.rowVersion + 1),
        ),
      );
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(task.id))).getSingleOrNull();
      if (reminder != null && reminder.status != ReminderStatus.cancelled) {
        final revision = reminder.scheduleRevision + 1;
        await (db.update(
          db.reminders,
        )..where((row) => row.id.equals(reminder.id))).write(
          RemindersCompanion(
            status: const Value(ReminderStatus.cancelled),
            pauseReason: const Value(null),
            scheduleRevision: Value(revision),
            updatedAtUtc: Value(now),
            rowVersion: Value(reminder.rowVersion + 1),
          ),
        );
        await enqueueJob(
          kind: PlatformJobKind.cancelReminder,
          aggregateId: reminder.id,
          aggregateRevision: revision,
          payload: {'reminderId': reminder.id, 'reason': 'addedToPast'},
        );
      }
      return PastEventModel(
        id: PastEventId(eventId),
        sourceTaskId: id,
        appendSequence: appendSequence,
        completedAtUtc: dateTimeFromUtcMicros(task.closedAtUtc!),
        completionLocalDate: task.closedLocalDate!,
        completionZoneId: task.closedZoneId!,
        anchorState: PastAnchorState.attached,
      );
    });
  }

  @override
  Stream<List<DocumentBlockModel>> watchPastBlocks() {
    final query = db.select(db.documentBlocks).join([
      innerJoin(
        db.documents,
        db.documents.id.equalsExp(db.documentBlocks.documentId),
      ),
    ])..where(db.documents.singletonKey.equals('past.main'));
    query.orderBy([
      OrderingTerm(expression: db.documentBlocks.sortRank),
      OrderingTerm(expression: db.documentBlocks.id),
    ]);
    return query.watch().map(
      (rows) => rows
          .map((row) => row.readTable(db.documentBlocks))
          .map(
            (row) => DocumentBlockModel(
              id: row.id,
              documentId: DocumentId(row.documentId),
              parentBlockId: row.parentBlockId,
              sortRank: row.sortRank,
              blockType: row.blockType,
              plainText: row.plainText,
              payloadJson: row.payloadJson,
              attributesJson: row.attributesJson,
              isChecked: row.isChecked,
            ),
          )
          .toList(growable: false),
    );
  }
}

final class DriftSettingsRepository extends _RepositoryBase
    implements SettingsRepository {
  DriftSettingsRepository(super.db, {super.clock, super.ids});

  @override
  Stream<AppSettingsModel> watchSettings() => (db.select(
    db.appSettingsTable,
  )..where((row) => row.id.equals(1))).watchSingle().map(_mapSettings);

  @override
  Future<AppSettingsModel> getSettings() async => _mapSettings(
    await (db.select(
      db.appSettingsTable,
    )..where((row) => row.id.equals(1))).getSingle(),
  );

  @override
  Future<AppSettingsModel> saveSettings(
    AppSettingsModel settings, {
    required int expectedVersion,
  }) async {
    if (settings.textScalePercent < 90 || settings.textScalePercent > 120) {
      throw const ValidationException('应用字号必须在 90% 到 120% 之间。');
    }
    if (!const {10, 30, 60}.contains(settings.defaultSnoozeMinutes)) {
      throw const ValidationException('稍后提醒仅支持 10、30 或 60 分钟。');
    }
    if (settings.autoBackupHourLocal < 0 ||
        settings.autoBackupHourLocal > 23 ||
        settings.autoBackupMinuteLocal < 0 ||
        settings.autoBackupMinuteLocal > 59) {
      throw const ValidationException('每日备份时间无效。');
    }
    return db.transaction(() async {
      final previous = await (db.select(
        db.appSettingsTable,
      )..where((row) => row.id.equals(1))).getSingle();
      if (previous.rowVersion != expectedVersion) {
        throw const StateConflictException('设置已在其他操作中更新。');
      }
      final affected =
          await (db.update(db.appSettingsTable)..where(
                (row) =>
                    row.id.equals(1) & row.rowVersion.equals(expectedVersion),
              ))
              .write(
                AppSettingsTableCompanion(
                  localeMode: Value(settings.localeMode),
                  fontMode: Value(settings.fontMode),
                  textScalePercent: Value(settings.textScalePercent),
                  density: Value(settings.density),
                  defaultSoundEnabled: Value(settings.defaultSoundEnabled),
                  defaultVibrationEnabled: Value(
                    settings.defaultVibrationEnabled,
                  ),
                  defaultSnoozeMinutes: Value(settings.defaultSnoozeMinutes),
                  autoBackupEnabled: Value(settings.autoBackupEnabled),
                  autoBackupHourLocal: Value(settings.autoBackupHourLocal),
                  autoBackupMinuteLocal: Value(settings.autoBackupMinuteLocal),
                  backupEncryptionEnabled: Value(
                    settings.backupEncryptionEnabled,
                  ),
                  helpSeenVersion: Value(settings.helpSeenVersion),
                  updatedAtUtc: Value(nowMicros),
                  rowVersion: Value(expectedVersion + 1),
                ),
              );
      if (affected != 1) {
        throw const StateConflictException('设置已在其他操作中更新。');
      }
      if (settings.localeMode != previous.localeMode) {
        final reminders =
            await (db.select(db.reminders)..where(
                  (row) =>
                      row.status.equalsValue(ReminderStatus.scheduled) &
                      row.scheduledAtUtc.isBiggerThanValue(nowMicros),
                ))
                .get();
        for (final reminder in reminders) {
          final scheduleRevision = reminder.scheduleRevision + 1;
          await (db.update(
            db.reminders,
          )..where((row) => row.id.equals(reminder.id))).write(
            RemindersCompanion(
              scheduleRevision: Value(scheduleRevision),
              updatedAtUtc: Value(nowMicros),
              rowVersion: Value(reminder.rowVersion + 1),
            ),
          );
          await enqueueJob(
            kind: PlatformJobKind.refreshReminderLocale,
            aggregateId: reminder.id,
            aggregateRevision: scheduleRevision,
            payload: {
              'reminderId': reminder.id,
              'localeMode': settings.localeMode.name,
            },
          );
        }
      }
      final row = await (db.select(
        db.appSettingsTable,
      )..where((entry) => entry.id.equals(1))).getSingle();
      return _mapSettings(row);
    });
  }

  AppSettingsModel _mapSettings(AppSettingsRow row) => AppSettingsModel(
    localeMode: row.localeMode,
    fontMode: row.fontMode,
    textScalePercent: row.textScalePercent,
    density: row.density,
    defaultSoundEnabled: row.defaultSoundEnabled,
    defaultVibrationEnabled: row.defaultVibrationEnabled,
    defaultSnoozeMinutes: row.defaultSnoozeMinutes,
    autoBackupEnabled: row.autoBackupEnabled,
    autoBackupHourLocal: row.autoBackupHourLocal,
    autoBackupMinuteLocal: row.autoBackupMinuteLocal,
    backupEncryptionEnabled: row.backupEncryptionEnabled,
    helpSeenVersion: row.helpSeenVersion,
    rowVersion: row.rowVersion,
  );
}

final class DriftSearchRepository extends _RepositoryBase
    implements SearchRepository {
  DriftSearchRepository(super.db, {super.clock, super.ids});

  @override
  Future<List<SearchHit>> search(String query, {SearchScope? scope}) async {
    final normalized = normalizedSearchText(query);
    if (normalized.isEmpty) return const [];
    final statement = db.select(db.searchRecords)
      ..where((row) {
        final textMatch =
            row.titleNorm.contains(normalized) |
            row.bodyNorm.contains(normalized) |
            row.dateKey.contains(normalized);
        return scope == null
            ? textMatch
            : textMatch & row.scope.equalsValue(scope);
      })
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.updatedAtUtc, mode: OrderingMode.desc),
      ]);
    return (await statement.get())
        .map(
          (row) => SearchHit(
            scope: row.scope,
            entityId: row.entityId,
            title: row.titleNorm,
            body: row.bodyNorm,
          ),
        )
        .toList(growable: false);
  }
}

final class DriftPlatformJobRepository extends _RepositoryBase
    implements PlatformJobRepository {
  DriftPlatformJobRepository(super.db, {super.clock, super.ids});

  @override
  Future<List<PlatformJobModel>> getPending({int limit = 50}) async {
    final query = db.select(db.platformJobs)
      ..where(
        (job) =>
            (job.status.equalsValue(PlatformJobStatus.pending) |
                job.status.equalsValue(PlatformJobStatus.failed)) &
            job.nextAttemptAtUtc.isSmallerOrEqualValue(nowMicros),
      )
      ..orderBy([
        (job) => OrderingTerm(expression: job.nextAttemptAtUtc),
        (job) => OrderingTerm(expression: job.createdAtUtc),
      ])
      ..limit(limit);
    return (await query.get())
        .map(
          (job) => PlatformJobModel(
            id: job.id,
            kind: job.kind,
            aggregateId: job.aggregateId,
            aggregateRevision: job.aggregateRevision,
            payloadJson: job.payloadJson,
            status: job.status,
            attempts: job.attempts,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markSucceeded(String id) async {
    final affected =
        await (db.update(
          db.platformJobs,
        )..where((job) => job.id.equals(id))).write(
          PlatformJobsCompanion(
            status: const Value(PlatformJobStatus.succeeded),
            lastErrorCode: const Value(null),
            updatedAtUtc: Value(nowMicros),
          ),
        );
    if (affected != 1) throw const NotFoundException('平台任务不存在。');
  }

  @override
  Future<void> markFailed(String id, {required String errorCode}) async {
    final job = await (db.select(
      db.platformJobs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (job == null) throw const NotFoundException('平台任务不存在。');
    final attempts = job.attempts + 1;
    final delayMinutes = attempts >= 6 ? 60 : 1 << (attempts - 1);
    await (db.update(db.platformJobs)..where((row) => row.id.equals(id))).write(
      PlatformJobsCompanion(
        status: const Value(PlatformJobStatus.failed),
        attempts: Value(attempts),
        nextAttemptAtUtc: Value(
          nowMicros + Duration(minutes: delayMinutes).inMicroseconds,
        ),
        lastErrorCode: Value(errorCode),
        updatedAtUtc: Value(nowMicros),
      ),
    );
  }
}

final class DriftTrashRepository extends _RepositoryBase
    implements TrashRepository {
  DriftTrashRepository(super.db, {super.clock, super.ids});

  @override
  Stream<List<TrashItemModel>> watchTrash() {
    const sql = '''
SELECT tr.id,
       tr.entity_type,
       tr.entity_id,
       tr.deleted_at_utc,
       tr.purge_after_utc,
       CASE tr.entity_type
         WHEN 'task' THEN COALESCE(t.title, '')
         WHEN 'note' THEN COALESCE(n.title, '')
         ELSE ''
       END AS display_title
FROM trash_entries AS tr
LEFT JOIN tasks AS t
  ON tr.entity_type = 'task' AND t.id = tr.entity_id
LEFT JOIN notes AS n
  ON tr.entity_type = 'note' AND n.id = tr.entity_id
ORDER BY tr.deleted_at_utc DESC, tr.id
''';
    return db
        .customSelect(sql, readsFrom: {db.trashEntries, db.tasks, db.notes})
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => TrashItemModel(
                  id: TrashId(row.read<String>('id')),
                  entityType: TrashEntityType.values.byName(
                    row.read<String>('entity_type'),
                  ),
                  entityId: row.read<String>('entity_id'),
                  displayTitle: row.read<String>('display_title'),
                  deletedAtUtc: dateTimeFromUtcMicros(
                    row.read<int>('deleted_at_utc'),
                  ),
                  purgeAfterUtc: dateTimeFromUtcMicros(
                    row.read<int>('purge_after_utc'),
                  ),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> restore(TrashId id) async {
    final entry = await (db.select(
      db.trashEntries,
    )..where((row) => row.id.equals(id.value))).getSingleOrNull();
    if (entry == null) throw const NotFoundException('最近删除记录不存在。');
    if (entry.entityType == TrashEntityType.task) {
      await DriftTaskRepository(
        db,
        clock: clock,
        ids: ids,
      ).restoreTask(TaskId(entry.entityId));
    } else {
      await DriftNoteRepository(
        db,
        clock: clock,
        ids: ids,
      ).restoreNote(NoteId(entry.entityId));
    }
  }

  @override
  Future<int> purgeExpired() =>
      DriftTaskRepository(db, clock: clock, ids: ids).purgeExpiredTrash();
}
