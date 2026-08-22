import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_store.dart';
import '../../data/data_support.dart';
import '../../data/database.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';

/// The read model exposed to the recently-deleted interface.
final class RecentlyDeletedItem {
  const RecentlyDeletedItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.deletedAtUtc,
    required this.purgeAfterUtc,
    required this.remainingDays,
  });

  final String id;
  final TrashEntityType entityType;
  final String entityId;
  final String title;
  final DateTime deletedAtUtc;
  final DateTime purgeAfterUtc;
  final int remainingDays;
}

abstract interface class TrashServiceApi {
  Stream<List<RecentlyDeletedItem>> watchItems();

  Future<List<RecentlyDeletedItem>> loadItems();

  Future<int> purgeExpired();

  Future<void> restore(String trashEntryId);

  Future<void> permanentlyDelete(String trashEntryId);
}

final trashServiceProvider = Provider<TrashServiceApi>((ref) {
  return TrashService(() => ref.read(databaseProvider.future));
});

/// Owns every destructive or restorative recently-deleted transaction.
///
/// Keeping this logic outside the page makes it possible to verify that an
/// entity, its document, the trash marker and its search record never drift
/// apart after a partial operation.
final class TrashService implements TrashServiceApi {
  TrashService(
    this._readDatabase, {
    this.clock = const SystemClock(),
    this.ids = const UuidIdGenerator(),
  });

  final Future<DangguiDatabase> Function() _readDatabase;
  final Clock clock;
  final IdGenerator ids;

  int get _nowMicros => utcMicros(clock.nowUtc());

  @override
  Stream<List<RecentlyDeletedItem>> watchItems() async* {
    final database = await _readDatabase();
    yield* _itemsQuery(database).watch().map(_mapRows);
  }

  @override
  Future<List<RecentlyDeletedItem>> loadItems() async {
    final database = await _readDatabase();
    return _mapRows(await _itemsQuery(database).get());
  }

  @override
  Future<int> purgeExpired() async {
    final database = await _readDatabase();
    final cutoff = _nowMicros;
    return database.transaction(() async {
      final expired =
          await (database.select(database.trashEntries)
                ..where(
                  (entry) => entry.purgeAfterUtc.isSmallerOrEqualValue(cutoff),
                )
                ..orderBy([
                  (entry) => OrderingTerm(expression: entry.purgeAfterUtc),
                  (entry) => OrderingTerm(expression: entry.id),
                ]))
              .get();
      for (final entry in expired) {
        await _deleteEntry(database, entry, tolerateRestoredEntity: true);
      }
      return expired.length;
    });
  }

  @override
  Future<void> restore(String trashEntryId) async {
    final database = await _readDatabase();
    final now = _nowMicros;
    await database.transaction(() async {
      final entry = await _requireEntry(database, trashEntryId);
      switch (entry.entityType) {
        case TrashEntityType.task:
          await _restoreTask(database, entry, now);
          break;
        case TrashEntityType.note:
          await _restoreNote(database, entry, now);
          break;
      }
    });
  }

  @override
  Future<void> permanentlyDelete(String trashEntryId) async {
    final database = await _readDatabase();
    await database.transaction(() async {
      final entry = await _requireEntry(database, trashEntryId);
      await _deleteEntry(database, entry, tolerateRestoredEntity: false);
    });
  }

  Selectable<QueryRow> _itemsQuery(DangguiDatabase database) {
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
    return database.customSelect(
      sql,
      readsFrom: {database.trashEntries, database.tasks, database.notes},
    );
  }

  List<RecentlyDeletedItem> _mapRows(List<QueryRow> rows) {
    final now = _nowMicros;
    return rows
        .map((row) {
          final purgeAfter = row.read<int>('purge_after_utc');
          final remainingMicros = purgeAfter - now;
          final remainingDays = remainingMicros <= 0
              ? 0
              : (remainingMicros + Duration.microsecondsPerDay - 1) ~/
                    Duration.microsecondsPerDay;
          return RecentlyDeletedItem(
            id: row.read<String>('id'),
            entityType: TrashEntityType.values.byName(
              row.read<String>('entity_type'),
            ),
            entityId: row.read<String>('entity_id'),
            title: row.read<String>('display_title'),
            deletedAtUtc: dateTimeFromUtcMicros(
              row.read<int>('deleted_at_utc'),
            ),
            purgeAfterUtc: dateTimeFromUtcMicros(purgeAfter),
            remainingDays: remainingDays,
          );
        })
        .toList(growable: false);
  }

  Future<TrashEntryRow> _requireEntry(
    DangguiDatabase database,
    String id,
  ) async {
    final entry = await (database.select(
      database.trashEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (entry == null) throw const TrashEntryNotFoundException();
    return entry;
  }

  Future<void> _restoreTask(
    DangguiDatabase database,
    TrashEntryRow entry,
    int now,
  ) async {
    final task = await (database.select(
      database.tasks,
    )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
    if (task == null) {
      throw const TrashStateException('The deleted task no longer exists.');
    }
    if (task.status != TaskStatus.trashed || task.deletedAtUtc == null) {
      throw const TrashStateException('The task is no longer in trash.');
    }

    final context = _decodeContext(entry.restoreContextJson);
    final previousStatus =
        context['status'] == TaskStatus.completionPending.name
        ? TaskStatus.completionPending
        : TaskStatus.active;
    final closedAtUtc = context.containsKey('closedAtUtc')
        ? _asInt(context['closedAtUtc'])
        : task.closedAtUtc;
    final closedLocalDate = context.containsKey('closedLocalDate')
        ? _asString(context['closedLocalDate'])
        : task.closedLocalDate;
    final closedLocalTime = context.containsKey('closedLocalTime')
        ? _asString(context['closedLocalTime'])
        : task.closedLocalTime;
    final closedZoneId = context.containsKey('closedZoneId')
        ? _asString(context['closedZoneId'])
        : task.closedZoneId;
    if (previousStatus == TaskStatus.completionPending &&
        (closedAtUtc == null ||
            closedLocalDate == null ||
            closedLocalTime == null ||
            closedZoneId == null)) {
      throw const TrashStateException(
        'The task completion context is incomplete and cannot be restored.',
      );
    }

    await (database.update(
      database.tasks,
    )..where((row) => row.id.equals(task.id))).write(
      TasksCompanion(
        status: Value(previousStatus),
        manualRank: Value(_asInt(context['manualRank']) ?? task.manualRank),
        closedAtUtc: Value(closedAtUtc),
        closedLocalDate: Value(closedLocalDate),
        closedLocalTime: Value(closedLocalTime),
        closedZoneId: Value(closedZoneId),
        archivedAtUtc: const Value(null),
        deletedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
        rowVersion: Value(task.rowVersion + 1),
      ),
    );

    final body = await _documentPlainText(database, task.documentId);
    await _putSearchRecord(
      database,
      scope: SearchScope.task,
      entityId: task.id,
      documentId: task.documentId,
      title: task.title,
      body: <String>[
        task.planText,
        body,
      ].where((value) => value.trim().isNotEmpty).join('\n'),
      dateKey: task.dueLocalDate ?? '',
      now: now,
    );
    await _restoreTaskReminder(database, task, previousStatus, now);
    await (database.delete(
      database.trashEntries,
    )..where((row) => row.id.equals(entry.id))).go();
  }

  Future<void> _restoreTaskReminder(
    DangguiDatabase database,
    TaskRow task,
    TaskStatus restoredStatus,
    int now,
  ) async {
    final reminder = await (database.select(
      database.reminders,
    )..where((row) => row.taskId.equals(task.id))).getSingleOrNull();
    if (reminder == null ||
        reminder.pauseReason != ReminderPauseReason.user ||
        (reminder.status != ReminderStatus.paused &&
            reminder.status != ReminderStatus.cancelled)) {
      return;
    }

    final revision = reminder.scheduleRevision + 1;
    final shouldSchedule =
        restoredStatus == TaskStatus.active && reminder.scheduledAtUtc > now;
    final status = shouldSchedule
        ? ReminderStatus.scheduled
        : restoredStatus == TaskStatus.completionPending
        ? ReminderStatus.paused
        : ReminderStatus.expired;
    final pauseReason = restoredStatus == TaskStatus.completionPending
        ? ReminderPauseReason.taskClosed
        : null;
    await (database.update(
      database.reminders,
    )..where((row) => row.id.equals(reminder.id))).write(
      RemindersCompanion(
        status: Value(status),
        pauseReason: Value(pauseReason),
        scheduleRevision: Value(revision),
        updatedAtUtc: Value(now),
        rowVersion: Value(reminder.rowVersion + 1),
      ),
    );
    if (shouldSchedule) {
      await _enqueueReminderJob(database, reminder.id, revision, now);
    }
  }

  Future<void> _enqueueReminderJob(
    DangguiDatabase database,
    String reminderId,
    int revision,
    int now,
  ) async {
    final kind = PlatformJobKind.scheduleReminder;
    await database
        .into(database.platformJobs)
        .insert(
          PlatformJobsCompanion.insert(
            id: ids.next(),
            kind: kind,
            aggregateId: reminderId,
            aggregateRevision: revision,
            dedupeKey: '${kind.name}:$reminderId:$revision',
            payloadJson: canonicalJson(<String, Object?>{
              'reminderId': reminderId,
              'reason': 'taskRestored',
            }),
            status: PlatformJobStatus.pending,
            nextAttemptAtUtc: now,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _restoreNote(
    DangguiDatabase database,
    TrashEntryRow entry,
    int now,
  ) async {
    final note = await (database.select(
      database.notes,
    )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
    if (note == null) {
      throw const TrashStateException('The deleted note no longer exists.');
    }
    if (note.deletedAtUtc == null) {
      throw const TrashStateException('The note is no longer in trash.');
    }

    final context = _decodeContext(entry.restoreContextJson);
    final requestedFolder = context.containsKey('folderId')
        ? _asString(context['folderId'])
        : note.folderId;
    String? restoredFolder;
    if (requestedFolder != null) {
      final folder = await (database.select(
        database.folders,
      )..where((row) => row.id.equals(requestedFolder))).getSingleOrNull();
      restoredFolder = folder?.id;
    }

    final int? restoredPinnedAt;
    if (context.containsKey('pinnedAtUtc')) {
      restoredPinnedAt = _asInt(context['pinnedAtUtc']);
    } else if (context['pinned'] == false) {
      restoredPinnedAt = null;
    } else if (context['pinned'] == true) {
      restoredPinnedAt = note.pinnedAtUtc ?? entry.deletedAtUtc;
    } else {
      restoredPinnedAt = note.pinnedAtUtc;
    }

    await (database.update(
      database.notes,
    )..where((row) => row.id.equals(note.id))).write(
      NotesCompanion(
        folderId: Value(restoredFolder),
        pinnedAtUtc: Value(restoredPinnedAt),
        deletedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
        rowVersion: Value(note.rowVersion + 1),
      ),
    );

    await _putSearchRecord(
      database,
      scope: SearchScope.note,
      entityId: note.id,
      documentId: note.documentId,
      title: note.title,
      body: await _documentPlainText(database, note.documentId),
      dateKey: '',
      now: now,
    );
    await (database.delete(
      database.trashEntries,
    )..where((row) => row.id.equals(entry.id))).go();
  }

  Future<void> _deleteEntry(
    DangguiDatabase database,
    TrashEntryRow entry, {
    required bool tolerateRestoredEntity,
  }) async {
    switch (entry.entityType) {
      case TrashEntityType.task:
        final task = await (database.select(
          database.tasks,
        )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
        if (task != null) {
          if (task.status != TaskStatus.trashed || task.deletedAtUtc == null) {
            if (!tolerateRestoredEntity) {
              throw const TrashStateException(
                'The task is no longer in trash.',
              );
            }
          } else {
            final reminderIds =
                await (database.selectOnly(database.reminders)
                      ..addColumns([database.reminders.id])
                      ..where(database.reminders.taskId.equals(task.id)))
                    .map((row) => row.read(database.reminders.id)!)
                    .get();
            for (final reminderId in reminderIds) {
              await (database.delete(
                database.platformJobs,
              )..where((job) => job.aggregateId.equals(reminderId))).go();
            }
            await _deleteSearchRecord(database, SearchScope.task, task.id);
            await (database.delete(
              database.tasks,
            )..where((row) => row.id.equals(task.id))).go();
            await (database.delete(
              database.documents,
            )..where((row) => row.id.equals(task.documentId))).go();
          }
        }
        break;
      case TrashEntityType.note:
        final note = await (database.select(
          database.notes,
        )..where((row) => row.id.equals(entry.entityId))).getSingleOrNull();
        if (note != null) {
          if (note.deletedAtUtc == null) {
            if (!tolerateRestoredEntity) {
              throw const TrashStateException(
                'The note is no longer in trash.',
              );
            }
          } else {
            await _deleteSearchRecord(database, SearchScope.note, note.id);
            await (database.delete(
              database.notes,
            )..where((row) => row.id.equals(note.id))).go();
            await (database.delete(
              database.documents,
            )..where((row) => row.id.equals(note.documentId))).go();
          }
        }
        break;
    }
    await (database.delete(
      database.trashEntries,
    )..where((row) => row.id.equals(entry.id))).go();
  }

  Future<String> _documentPlainText(
    DangguiDatabase database,
    String documentId,
  ) async {
    final rows =
        await (database.select(database.documentBlocks)
              ..where((block) => block.documentId.equals(documentId))
              ..orderBy([
                (block) => OrderingTerm(expression: block.sortRank),
                (block) => OrderingTerm(expression: block.id),
              ]))
            .get();
    return rows
        .map((row) => row.plainText)
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
  }

  Future<void> _putSearchRecord(
    DangguiDatabase database, {
    required SearchScope scope,
    required String entityId,
    required String documentId,
    required String title,
    required String body,
    required String dateKey,
    required int now,
  }) async {
    await database
        .into(database.searchRecords)
        .insert(
          SearchRecordsCompanion.insert(
            scope: scope,
            entityId: entityId,
            documentId: Value(documentId),
            titleNorm: Value(normalizedSearchText(title)),
            bodyNorm: Value(normalizedSearchText(body)),
            dateKey: Value(dateKey),
            updatedAtUtc: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _deleteSearchRecord(
    DangguiDatabase database,
    SearchScope scope,
    String entityId,
  ) async {
    await (database.delete(database.searchRecords)..where(
          (row) => row.scope.equalsValue(scope) & row.entityId.equals(entityId),
        ))
        .go();
  }
}

Map<String, Object?> _decodeContext(String source) {
  try {
    final value = jsonDecode(source);
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    // A damaged restore context is handled conservatively by each entity path.
  }
  return <String, Object?>{};
}

int? _asInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  _ => null,
};

String? _asString(Object? value) => value is String ? value : null;

sealed class TrashServiceException implements Exception {
  const TrashServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class TrashEntryNotFoundException extends TrashServiceException {
  const TrashEntryNotFoundException()
    : super('The recently-deleted entry no longer exists.');
}

final class TrashStateException extends TrashServiceException {
  const TrashStateException(super.message);
}
