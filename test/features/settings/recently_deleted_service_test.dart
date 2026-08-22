import 'package:danggui/src/data/data_support.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:danggui/src/services/trash/trash_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late _MutableClock clock;
  late _SequenceIds ids;
  late DriftTaskRepository tasks;
  late DriftNoteRepository notes;
  late DriftDocumentRepository documents;
  late TrashService service;

  setUp(() {
    database = DangguiDatabase(NativeDatabase.memory());
    clock = _MutableClock(DateTime.utc(2026, 8, 22, 10));
    ids = _SequenceIds();
    tasks = DriftTaskRepository(database, clock: clock, ids: ids);
    notes = DriftNoteRepository(database, clock: clock, ids: ids);
    documents = DriftDocumentRepository(database, clock: clock, ids: ids);
    service = TrashService(() async => database, clock: clock, ids: ids);
  });

  tearDown(() => database.close());

  test('lists joined task and note titles with retention days', () async {
    final task = await tasks.createTask(const TaskDraft(title: '修改论文引言'));
    final note = await notes.createNote(
      const NoteDraft(title: '实验备忘', body: '整理数据'),
    );
    await tasks.moveTaskToTrash(task.id);
    await notes.moveNoteToTrash(note.id);

    final items = await service.loadItems();

    expect(items, hasLength(2));
    expect(
      items.map((item) => item.entityType),
      containsAll(<TrashEntityType>[
        TrashEntityType.task,
        TrashEntityType.note,
      ]),
    );
    expect(
      items.map((item) => item.title),
      containsAll(<String>['修改论文引言', '实验备忘']),
    );
    expect(items.every((item) => item.remainingDays == 30), isTrue);
    expect(items.every((item) => item.deletedAtUtc.isUtc), isTrue);
  });

  test(
    'entry cleanup permanently removes expired entity and document safely',
    () async {
      final task = await tasks.createTask(
        const TaskDraft(title: '过期事项', planText: '需要清理的正文'),
      );
      final documentId = task.documentId.value;
      await tasks.moveTaskToTrash(task.id);
      clock.value = clock.value.add(const Duration(days: 31));

      expect(await service.purgeExpired(), 1);

      expect(
        await (database.select(
          database.tasks,
        )..where((row) => row.id.equals(task.id.value))).getSingleOrNull(),
        isNull,
      );
      expect(
        await (database.select(
          database.documents,
        )..where((row) => row.id.equals(documentId))).getSingleOrNull(),
        isNull,
      );
      expect(await database.select(database.trashEntries).get(), isEmpty);
      expect(await database.foreignKeyCheck(), isEmpty);
    },
  );

  test(
    'restores completion-pending task and rebuilds its search record',
    () async {
      final task = await tasks.createTask(
        const TaskDraft(
          title: '整理实验数据',
          planText: '晚饭后开始',
          dueLocalDate: '2026-08-25',
        ),
      );
      await documents.replaceBlocks(task.documentId, <DocumentBlockModel>[
        DocumentBlockModel(
          id: ids.next(),
          documentId: task.documentId,
          sortRank: 1024,
          blockType: DocumentBlockType.paragraph,
          plainText: '补充实验表格',
        ),
      ], expectedRevision: 0);
      await tasks.setReminder(
        ReminderDraft(
          taskId: task.id,
          scheduledLocalDateTime: '2026-08-24T19:50:00',
          scheduledZoneId: 'Asia/Shanghai',
          scheduledAtUtc: DateTime.utc(2026, 8, 24, 11, 50),
        ),
      );
      await tasks.closeTask(
        task.id,
        localDate: '2026-08-22',
        localTime: '18:30',
        zoneId: 'Asia/Shanghai',
      );
      await tasks.moveTaskToTrash(task.id);
      final entry = await database.select(database.trashEntries).getSingle();

      // AppStore's existing deletion path stores only the status. The entity
      // row still contains the completion fields and must remain restorable.
      await (database.update(
        database.trashEntries,
      )..where((row) => row.id.equals(entry.id))).write(
        TrashEntriesCompanion(
          restoreContextJson: Value(
            canonicalJson(<String, Object?>{
              'status': TaskStatus.completionPending.name,
            }),
          ),
        ),
      );

      await service.restore(entry.id);

      final restored = await (database.select(
        database.tasks,
      )..where((row) => row.id.equals(task.id.value))).getSingle();
      expect(restored.status, TaskStatus.completionPending);
      expect(restored.deletedAtUtc, isNull);
      expect(restored.closedLocalTime, '18:30');
      final reminder = await tasks.getReminder(task.id);
      expect(reminder!.status, ReminderStatus.paused);
      expect(reminder.pauseReason, ReminderPauseReason.taskClosed);
      final search =
          await (database.select(database.searchRecords)..where(
                (row) =>
                    row.scope.equalsValue(SearchScope.task) &
                    row.entityId.equals(task.id.value),
              ))
              .getSingle();
      expect(search.titleNorm, '整理实验数据');
      expect(search.bodyNorm, contains('晚饭后开始'));
      expect(search.bodyNorm, contains('补充实验表格'));
      expect(search.dateKey, '2026-08-25');
      expect(await database.select(database.trashEntries).get(), isEmpty);
    },
  );

  test('restores active task and reschedules its future reminder', () async {
    final task = await tasks.createTask(const TaskDraft(title: '晚饭后整理数据'));
    final originalReminder = await tasks.setReminder(
      ReminderDraft(
        taskId: task.id,
        scheduledLocalDateTime: '2026-08-24T19:50:00',
        scheduledZoneId: 'Asia/Shanghai',
        scheduledAtUtc: DateTime.utc(2026, 8, 24, 11, 50),
      ),
    );
    await tasks.moveTaskToTrash(task.id);
    final entry = await database.select(database.trashEntries).getSingle();

    // AppStore marks reminders as cancelled while the core repository uses
    // paused. Both deletion paths must be reversible.
    await (database.update(
      database.reminders,
    )..where((row) => row.id.equals(originalReminder.id.value))).write(
      const RemindersCompanion(
        status: Value(ReminderStatus.cancelled),
        pauseReason: Value(ReminderPauseReason.user),
      ),
    );

    await service.restore(entry.id);

    final restoredTask = await tasks.getTask(task.id);
    expect(restoredTask!.status, TaskStatus.active);
    final restoredReminder = await tasks.getReminder(task.id);
    expect(restoredReminder!.status, ReminderStatus.scheduled);
    expect(restoredReminder.pauseReason, isNull);
    final scheduleJob =
        await (database.select(database.platformJobs)..where(
              (row) =>
                  row.kind.equalsValue(PlatformJobKind.scheduleReminder) &
                  row.aggregateId.equals(originalReminder.id.value) &
                  row.aggregateRevision.equals(
                    restoredReminder.scheduleRevision,
                  ),
            ))
            .getSingle();
    expect(scheduleJob.status, PlatformJobStatus.pending);
  });

  test('restores note folder, pinned state and search record', () async {
    final folder = await notes.createFolder('研究');
    final note = await notes.createNote(
      NoteDraft(title: '方法备忘', body: '记录实验参数', folderId: folder.id),
    );
    final pinnedAt = utcMicros(DateTime.utc(2026, 8, 20, 9));
    await (database.update(database.notes)
          ..where((row) => row.id.equals(note.id.value)))
        .write(NotesCompanion(pinnedAtUtc: Value(pinnedAt)));
    await notes.moveNoteToTrash(note.id);
    final entry = await database.select(database.trashEntries).getSingle();

    // Also cover the compact context produced by AppStoreController.
    await (database.update(
      database.trashEntries,
    )..where((row) => row.id.equals(entry.id))).write(
      TrashEntriesCompanion(
        restoreContextJson: Value(
          canonicalJson(<String, Object?>{
            'folderId': folder.id.value,
            'pinned': true,
          }),
        ),
      ),
    );

    await service.restore(entry.id);

    final restored = await (database.select(
      database.notes,
    )..where((row) => row.id.equals(note.id.value))).getSingle();
    expect(restored.folderId, folder.id.value);
    expect(restored.pinnedAtUtc, pinnedAt);
    expect(restored.deletedAtUtc, isNull);
    final search =
        await (database.select(database.searchRecords)..where(
              (row) =>
                  row.scope.equalsValue(SearchScope.note) &
                  row.entityId.equals(note.id.value),
            ))
            .getSingle();
    expect(search.titleNorm, '方法备忘');
    expect(search.bodyNorm, contains('记录实验参数'));
  });

  test('manual permanent deletion removes note, document and marker', () async {
    final note = await notes.createNote(
      const NoteDraft(title: '不再需要', body: '丢弃的内容'),
    );
    final documentId = note.documentId.value;
    await notes.moveNoteToTrash(note.id);
    final entry = await database.select(database.trashEntries).getSingle();

    await service.permanentlyDelete(entry.id);

    expect(
      await (database.select(
        database.notes,
      )..where((row) => row.id.equals(note.id.value))).getSingleOrNull(),
      isNull,
    );
    expect(
      await (database.select(
        database.documents,
      )..where((row) => row.id.equals(documentId))).getSingleOrNull(),
      isNull,
    );
    expect(await database.select(database.trashEntries).get(), isEmpty);
    expect(await database.foreignKeyCheck(), isEmpty);
  });
}

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();
}

final class _SequenceIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'recently-deleted-${++_next}';
}
