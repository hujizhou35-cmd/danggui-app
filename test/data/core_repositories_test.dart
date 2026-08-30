import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/data_support.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase db;
  late MutableClock clock;
  late SequenceIds ids;
  late DriftTaskRepository tasks;
  late DriftNoteRepository notes;
  late DriftPastRepository past;
  late DriftDocumentRepository documents;
  late DriftSettingsRepository settings;
  late DriftTrashRepository trash;

  setUp(() {
    db = DangguiDatabase(NativeDatabase.memory());
    clock = MutableClock(DateTime.utc(2026, 8, 22, 10));
    ids = SequenceIds();
    tasks = DriftTaskRepository(db, clock: clock, ids: ids);
    notes = DriftNoteRepository(db, clock: clock, ids: ids);
    past = DriftPastRepository(db, clock: clock, ids: ids);
    documents = DriftDocumentRepository(db, clock: clock, ids: ids);
    settings = DriftSettingsRepository(db, clock: clock, ids: ids);
    trash = DriftTrashRepository(db, clock: clock, ids: ids);
  });

  tearDown(() => db.close());

  test('new database seeds settings and the singleton past document', () async {
    final value = await settings.getSettings();
    expect(value.localeMode, LocaleMode.system);
    expect(value.autoBackupHourLocal, 2);
    expect(value.autoBackupMinuteLocal, 0);
    expect(value.rowVersion, 1);

    final pastDocument = await (db.select(
      db.documents,
    )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
    expect(pastDocument.kind, DocumentKind.past);
    expect(await db.quickCheck(), ['ok']);
    expect(await db.foreignKeyCheck(), isEmpty);
  });

  test(
    'closing a task persists its completion context and reminder outbox',
    () async {
      final task = await tasks.createTask(
        const TaskDraft(title: '修改论文引言', dueLocalDate: '2026-08-25'),
      );
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
        localTime: '18:00',
        zoneId: 'Asia/Shanghai',
      );

      final closed = await tasks.getTask(task.id);
      expect(closed!.status, TaskStatus.completionPending);
      expect(closed.closedLocalDate, '2026-08-22');
      expect(closed.closedLocalTime, '18:00');
      final reminder = await tasks.getReminder(task.id);
      expect(reminder!.status, ReminderStatus.paused);
      expect(reminder.pauseReason, ReminderPauseReason.taskClosed);

      final jobs =
          await (db.select(db.platformJobs)..where(
                (row) => row.kind.equalsValue(PlatformJobKind.cancelReminder),
              ))
              .get();
      expect(jobs, hasLength(1));
      expect(jobs.single.aggregateRevision, reminder.scheduleRevision);
    },
  );

  test('adding a closed task to past is one durable transaction', () async {
    final task = await tasks.createTask(
      const TaskDraft(
        title: '核对新增引用',
        dueLocalDate: '2026-08-25',
        planText: '晚饭后开始',
      ),
    );
    await documents.replaceBlocks(task.documentId, [
      DocumentBlockModel(
        id: ids.next(),
        documentId: task.documentId,
        sortRank: 1024,
        blockType: DocumentBlockType.checklist,
        plainText: '补充理论背景',
        isChecked: true,
      ),
    ], expectedRevision: 0);
    await tasks.closeTask(
      task.id,
      localDate: '2026-08-22',
      localTime: '19:10',
      zoneId: 'Asia/Shanghai',
    );

    final event = await past.addClosedTaskToPast(task.id);

    expect(event.anchorState, PastAnchorState.attached);
    expect((await tasks.getTask(task.id))!.status, TaskStatus.archived);
    final eventRow = await (db.select(
      db.pastEvents,
    )..where((row) => row.id.equals(event.id.value))).getSingle();
    expect(eventRow.sourceSnapshotJson, contains('补充理论背景'));
    final parts = await (db.select(
      db.pastEventParts,
    )..where((row) => row.eventId.equals(event.id.value))).get();
    expect(parts.map((part) => part.role), contains(PastPartRole.checklist));
    final links = await db.select(db.pastAnchorLinks).get();
    expect(links, isNotEmpty);
    expect(links.every((link) => link.currentBlockId != null), isTrue);
  });

  test('deleting all anchored blocks marks the past event detached', () async {
    final task = await tasks.createTask(const TaskDraft(title: '整理实验数据'));
    await tasks.closeTask(
      task.id,
      localDate: '2026-08-22',
      localTime: '19:20',
      zoneId: 'Asia/Shanghai',
    );
    final event = await past.addClosedTaskToPast(task.id);
    final pastDocument = await (db.select(
      db.documents,
    )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
    final current = await documents.getBlocks(DocumentId(pastDocument.id));
    final linkedIds = (await db.select(db.pastAnchorLinks).get())
        .map((link) => link.currentBlockId)
        .whereType<String>()
        .toSet();
    final dateHeadings = current
        .where((block) => !linkedIds.contains(block.id))
        .toList(growable: false);

    await documents.replaceBlocks(
      DocumentId(pastDocument.id),
      dateHeadings,
      expectedRevision: pastDocument.revision,
    );

    final changed = await (db.select(
      db.pastEvents,
    )..where((row) => row.id.equals(event.id.value))).getSingle();
    expect(changed.anchorState, PastAnchorState.detached);
  });

  test(
    'replacing an anchored block preserves the link and marks it modified',
    () async {
      final task = await tasks.createTask(const TaskDraft(title: '整理数据'));
      await tasks.closeTask(
        task.id,
        localDate: '2026-08-22',
        localTime: '19:30',
        zoneId: 'Asia/Shanghai',
      );
      final event = await past.addClosedTaskToPast(task.id);
      final pastDocument = await (db.select(
        db.documents,
      )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
      final current = await documents.getBlocks(DocumentId(pastDocument.id));
      final firstPart =
          await (db.select(db.pastEventParts)
                ..where((row) => row.eventId.equals(event.id.value))
                ..limit(1))
              .getSingle();
      final firstLink =
          await (db.select(db.pastAnchorLinks)
                ..where((row) => row.partId.equals(firstPart.id))
                ..limit(1))
              .getSingle();
      final oldId = firstLink.currentBlockId!;
      final oldBlock = current.singleWhere((block) => block.id == oldId);
      final newId = ids.next();
      final replacement = DocumentBlockModel(
        id: newId,
        documentId: oldBlock.documentId,
        parentBlockId: oldBlock.parentBlockId,
        sortRank: oldBlock.sortRank,
        blockType: oldBlock.blockType,
        plainText: '${oldBlock.plainText}（已修改）',
        payloadJson: oldBlock.payloadJson,
        attributesJson: oldBlock.attributesJson,
        isChecked: oldBlock.isChecked,
      );

      await documents.replaceBlocks(
        DocumentId(pastDocument.id),
        [
          for (final block in current)
            if (block.id == oldId) replacement else block,
        ],
        expectedRevision: pastDocument.revision,
        replacements: {
          oldId: [newId],
        },
      );

      final changedLink = await (db.select(
        db.pastAnchorLinks,
      )..where((row) => row.id.equals(firstLink.id))).getSingle();
      expect(changedLink.currentBlockId, newId);
      expect(changedLink.relation, AnchorRelation.replacement);
      final changedEvent = await (db.select(
        db.pastEvents,
      )..where((row) => row.id.equals(event.id.value))).getSingle();
      expect(changedEvent.anchorState, PastAnchorState.modified);
    },
  );

  test('merging anchored blocks retains both provenance links', () async {
    final task = await tasks.createTask(const TaskDraft(title: '合并过往段落'));
    await tasks.closeTask(
      task.id,
      localDate: '2026-08-22',
      localTime: '19:35',
      zoneId: 'Asia/Shanghai',
    );
    final event = await past.addClosedTaskToPast(task.id);
    final pastDocument = await (db.select(
      db.documents,
    )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
    final current = await documents.getBlocks(DocumentId(pastDocument.id));
    final eventParts = await (db.select(
      db.pastEventParts,
    )..where((row) => row.eventId.equals(event.id.value))).get();
    final links = <PastAnchorLinkRow>[];
    for (final part in eventParts.take(2)) {
      links.add(
        await (db.select(
          db.pastAnchorLinks,
        )..where((row) => row.partId.equals(part.id))).getSingle(),
      );
    }
    final oldIds = links.map((link) => link.currentBlockId!).toList();
    final first = current.singleWhere((block) => block.id == oldIds.first);
    final mergedId = ids.next();
    final merged = DocumentBlockModel(
      id: mergedId,
      documentId: first.documentId,
      sortRank: first.sortRank,
      blockType: DocumentBlockType.pastEntry,
      plainText: '19:35 合并过往段落',
    );

    await documents.replaceBlocks(
      DocumentId(pastDocument.id),
      [
        for (final block in current)
          if (block.id == oldIds.first)
            merged
          else if (!oldIds.contains(block.id))
            block,
      ],
      expectedRevision: pastDocument.revision,
      replacements: {
        for (final oldId in oldIds) oldId: [mergedId],
      },
    );

    final mergedLinks = await (db.select(
      db.pastAnchorLinks,
    )..where((row) => row.currentBlockId.equals(mergedId))).get();
    expect(mergedLinks, hasLength(2));
    expect(
      mergedLinks.every((link) => link.relation == AnchorRelation.merged),
      isTrue,
    );
  });

  test(
    'task and note soft deletion retains data for 30 days then purges',
    () async {
      final task = await tasks.createTask(const TaskDraft(title: '购买记录本'));
      final note = await notes.createNote(
        const NoteDraft(title: '实验想法', body: '记录变量命名。'),
      );
      await tasks.moveTaskToTrash(task.id);
      await notes.moveNoteToTrash(note.id);

      expect(await tasks.purgeExpiredTrash(), 0);
      expect(await tasks.getTask(task.id), isNotNull);

      clock.advance(const Duration(days: 31));
      expect(await tasks.purgeExpiredTrash(), 2);
      expect(await tasks.getTask(task.id), isNull);
      expect(
        await (db.select(
          db.notes,
        )..where((row) => row.id.equals(note.id.value))).getSingleOrNull(),
        isNull,
      );
      expect(await db.select(db.trashEntries).get(), isEmpty);
    },
  );

  test(
    'unified trash restores an active task and its future reminder',
    () async {
      final task = await tasks.createTask(const TaskDraft(title: '复习生理学'));
      await tasks.setReminder(
        ReminderDraft(
          taskId: task.id,
          scheduledLocalDateTime: '2026-08-24T19:50:00',
          scheduledZoneId: 'Asia/Shanghai',
          scheduledAtUtc: DateTime.utc(2026, 8, 24, 11, 50),
        ),
      );
      await tasks.moveTaskToTrash(task.id);
      final items = await trash.watchTrash().first;
      expect(items, hasLength(1));
      expect(items.single.displayTitle, '复习生理学');
      expect((await tasks.getReminder(task.id))!.status, ReminderStatus.paused);

      // Emulate the authenticated restore context written by v1.1.4, before
      // reminder intent was included in the payload.
      final legacyContext = <String, Object?>{
        'status': TaskStatus.active.name,
        'manualRank': task.manualRank,
        'closedAtUtc': null,
        'closedLocalDate': null,
        'closedLocalTime': null,
        'closedZoneId': null,
      };
      await (db.update(
        db.trashEntries,
      )..where((row) => row.id.equals(items.single.id.value))).write(
        TrashEntriesCompanion(
          restoreContextJson: Value(canonicalJson(legacyContext)),
          snapshotSha256: Value(await sha256Hex(legacyContext)),
        ),
      );

      await trash.restore(items.single.id);

      expect((await tasks.getTask(task.id))!.status, TaskStatus.active);
      expect(
        (await tasks.getReminder(task.id))!.status,
        ReminderStatus.scheduled,
      );
      expect(await trash.watchTrash().first, isEmpty);
    },
  );

  test(
    'trash restore preserves a reminder that was already user-paused',
    () async {
      final task = await tasks.createTask(const TaskDraft(title: '暂停后再整理'));
      await tasks.setReminder(
        ReminderDraft(
          taskId: task.id,
          scheduledLocalDateTime: '2026-08-24T19:50:00',
          scheduledZoneId: 'Asia/Shanghai',
          scheduledAtUtc: DateTime.utc(2026, 8, 24, 11, 50),
        ),
      );
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.taskId.equals(task.id.value))).getSingle();
      await (db.update(
        db.reminders,
      )..where((row) => row.id.equals(reminder.id))).write(
        const RemindersCompanion(
          status: Value(ReminderStatus.paused),
          pauseReason: Value(ReminderPauseReason.user),
        ),
      );
      await db.delete(db.platformJobs).go();

      await tasks.moveTaskToTrash(task.id);
      await trash.restore((await trash.watchTrash().first).single.id);

      final restored = await tasks.getReminder(task.id);
      expect(restored!.status, ReminderStatus.paused);
      expect(restored.pauseReason, ReminderPauseReason.user);
      expect(
        await (db.select(db.platformJobs)..where(
              (row) => row.kind.equalsValue(PlatformJobKind.scheduleReminder),
            ))
            .get(),
        isEmpty,
      );
    },
  );

  test('damaged trash context is rejected without restoring data', () async {
    final task = await tasks.createTask(const TaskDraft(title: '不能误恢复'));
    final note = await notes.createNote(
      const NoteDraft(title: '也不能误恢复', body: '保留原始内容'),
    );
    await tasks.moveTaskToTrash(task.id);
    await notes.moveNoteToTrash(note.id);
    await db.customStatement(
      "UPDATE trash_entries SET restore_context_json = '{}'",
    );

    final entries = await db.select(db.trashEntries).get();
    for (final entry in entries) {
      await expectLater(
        trash.restore(TrashId(entry.id)),
        throwsA(isA<StateConflictException>()),
      );
    }

    expect((await tasks.getTask(task.id))!.status, TaskStatus.trashed);
    expect(
      (await (db.select(
            db.notes,
          )..where((row) => row.id.equals(note.id.value))).getSingle())
          .deletedAtUtc,
      isNotNull,
    );
    expect(await db.select(db.trashEntries).get(), hasLength(2));
  });

  test(
    'settings use optimistic locking and preserve explicit locale',
    () async {
      final original = await settings.getSettings();
      final updated = await settings.saveSettings(
        AppSettingsModel(
          localeMode: LocaleMode.ja,
          fontMode: original.fontMode,
          textScalePercent: 110,
          density: original.density,
          defaultSoundEnabled: original.defaultSoundEnabled,
          defaultVibrationEnabled: original.defaultVibrationEnabled,
          defaultSnoozeMinutes: original.defaultSnoozeMinutes,
          autoBackupEnabled: original.autoBackupEnabled,
          autoBackupHourLocal: 3,
          autoBackupMinuteLocal: 45,
          backupEncryptionEnabled: true,
          helpSeenVersion: original.helpSeenVersion,
          rowVersion: original.rowVersion,
        ),
        expectedVersion: original.rowVersion,
      );
      expect(updated.localeMode, LocaleMode.ja);
      expect(updated.backupEncryptionEnabled, isTrue);
      expect(updated.autoBackupHourLocal, 3);
      expect(updated.autoBackupMinuteLocal, 45);
      expect(updated.rowVersion, 2);

      await expectLater(
        settings.saveSettings(original, expectedVersion: original.rowVersion),
        throwsA(isA<StateConflictException>()),
      );
    },
  );
}

final class MutableClock implements Clock {
  MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

final class SequenceIds implements IdGenerator {
  int _next = 0;

  @override
  String next() => 'test-id-${_next++}';
}
