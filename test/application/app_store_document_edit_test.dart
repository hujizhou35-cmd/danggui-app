import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => database)],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('replacePastDocumentText merges two anchored blocks', () async {
    final fixture = await _archiveSimpleTask(controller, database);
    final before = container.read(appStoreProvider).requireValue.pastBlocks;
    final date = before.singleWhere(
      (block) => block.type == DocumentBlockType.pastDate,
    );
    final time = before.singleWhere((block) => block.id == fixture.timeBlockId);
    final title = before.singleWhere(
      (block) => block.id == fixture.titleBlockId,
    );

    await controller.replacePastDocumentText(
      '${date.text}\n\n${time.text} ${title.text}',
    );

    final links = await _eventLinks(database, fixture.eventId);
    expect(links, hasLength(2));
    expect(links.map((link) => link.currentBlockId).toSet(), hasLength(1));
    expect(
      links.every((link) => link.relation == AnchorRelation.merged),
      isTrue,
    );
    expect(
      links.every((link) => link.linkState == AnchorLinkState.linked),
      isTrue,
    );
    expect(
      await _eventState(database, fixture.eventId),
      PastAnchorState.modified,
    );
    expect(
      container.read(appStoreProvider).requireValue.pastBlocks.first.id,
      date.id,
      reason: 'the unchanged prefix keeps its stable block id',
    );
  });

  test('replacePastDocumentText splits one anchored block', () async {
    final fixture = await _archiveSimpleTask(controller, database);
    final before = container.read(appStoreProvider).requireValue.pastBlocks;
    final date = before.singleWhere(
      (block) => block.type == DocumentBlockType.pastDate,
    );
    final time = before.singleWhere((block) => block.id == fixture.timeBlockId);
    final title = before.singleWhere(
      (block) => block.id == fixture.titleBlockId,
    );

    await controller.replacePastDocumentText(
      '${date.text}\n\n${time.text}\n\n${title.text}（上）'
      '\n\n${title.text}（下）',
    );

    final titleLinks = await _partLinks(
      database,
      eventId: fixture.eventId,
      role: PastPartRole.title,
    );
    expect(titleLinks, hasLength(2));
    expect(titleLinks.map((link) => link.currentBlockId).toSet(), hasLength(2));
    expect(
      titleLinks.every((link) => link.relation == AnchorRelation.split),
      isTrue,
    );
    final timeLinks = await _partLinks(
      database,
      eventId: fixture.eventId,
      role: PastPartRole.time,
    );
    expect(timeLinks, hasLength(1));
    expect(timeLinks.single.currentBlockId, fixture.timeBlockId);
    expect(timeLinks.single.relation, AnchorRelation.original);
    expect(timeLinks.single.linkState, AnchorLinkState.linked);
    final after = container.read(appStoreProvider).requireValue.pastBlocks;
    final unchangedTime = after.singleWhere(
      (block) => block.id == fixture.timeBlockId,
    );
    expect(unchangedTime.type, DocumentBlockType.pastEntry);
    expect(
      await _eventState(database, fixture.eventId),
      PastAnchorState.modified,
    );
  });

  test(
    'replacePastDocumentText records a one-to-one anchor replacement',
    () async {
      final fixture = await _archiveSimpleTask(controller, database);
      final before = container.read(appStoreProvider).requireValue.pastBlocks;
      final date = before.singleWhere(
        (block) => block.type == DocumentBlockType.pastDate,
      );
      final time = before.singleWhere(
        (block) => block.id == fixture.timeBlockId,
      );
      final title = before.singleWhere(
        (block) => block.id == fixture.titleBlockId,
      );

      await controller.replacePastDocumentText(
        '${date.text}\n\n${time.text}\n\n${title.text}（已校订）',
      );

      final titleLinks = await _partLinks(
        database,
        eventId: fixture.eventId,
        role: PastPartRole.title,
      );
      expect(titleLinks, hasLength(1));
      expect(titleLinks.single.currentBlockId, isNot(fixture.titleBlockId));
      expect(
        titleLinks.single.lastKnownBlockId,
        titleLinks.single.currentBlockId,
      );
      expect(titleLinks.single.relation, AnchorRelation.replacement);
      expect(titleLinks.single.linkState, AnchorLinkState.linked);
      expect(
        await _eventState(database, fixture.eventId),
        PastAnchorState.modified,
      );
    },
  );

  test(
    'Past typed checklist survives a parse-state-parse round trip',
    () async {
      const source = '☐ 未完成\n\n☒ 已完成\n\n• 项目符号\n\n7. 编号';
      await controller.replacePastDocumentText(source);

      final first = container.read(appStoreProvider).requireValue.pastBlocks;
      expect(first.map((block) => block.type), <DocumentBlockType>[
        DocumentBlockType.checklist,
        DocumentBlockType.checklist,
        DocumentBlockType.bullet,
        DocumentBlockType.numbered,
      ]);
      expect(first.map((block) => block.isChecked), <bool?>[
        false,
        true,
        null,
        null,
      ]);
      final originalIds = first
          .map((block) => block.id)
          .toList(growable: false);

      await controller.replacePastDocumentText(_serializePast(first));

      final second = container.read(appStoreProvider).requireValue.pastBlocks;
      expect(second.map((block) => block.id), originalIds);
      expect(second.map((block) => block.isChecked), <bool?>[
        false,
        true,
        null,
        null,
      ]);
      expect(_serializePast(second), '☐ 未完成\n\n☒ 已完成\n\n• 项目符号\n\n1. 编号');
    },
  );

  test(
    'Past projection is compact by event and preserves day spacing',
    () async {
      await _archiveTaskAt(
        controller,
        database,
        title: '改软件',
        completionDate: '2026-08-24',
        completionTime: '17:37',
        dueDate: DateTime(2026, 8, 24),
        body: '正文甲',
        plan: '计划甲',
      );
      await _archiveTaskAt(
        controller,
        database,
        title: '复习生理',
        completionDate: '2026-08-24',
        completionTime: '19:03',
        dueDate: DateTime(2026, 8, 24),
      );
      await _archiveTaskAt(
        controller,
        database,
        title: '次日事项',
        completionDate: '2026-08-25',
        completionTime: '08:06',
      );

      final document = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;
      expect(
        document.text,
        '2026-08-24\n'
        '改软件 17:37 📅 2026-08-24 · 正文甲 · 计划甲\n'
        '复习生理 19:03 📅 2026-08-24\n\n'
        '2026-08-25\n'
        '次日事项 08:06',
      );
      expect(
        document.segments.map((segment) => segment.kind),
        <PastEditorSegmentKind>[
          PastEditorSegmentKind.dateHeading,
          PastEditorSegmentKind.event,
          PastEditorSegmentKind.event,
          PastEditorSegmentKind.dateHeading,
          PastEditorSegmentKind.event,
        ],
      );
      expect(
        document.segments
            .where((segment) => segment.kind == PastEditorSegmentKind.event)
            .every((segment) => segment.sourceBlockIds.isNotEmpty),
        isTrue,
      );
    },
  );

  test('Past projection no-op save does not write or alter anchors', () async {
    final eventId = await _archiveTaskAt(
      controller,
      database,
      title: '无改动事项',
      completionDate: '2026-08-24',
      completionTime: '19:03',
      dueDate: DateTime(2026, 8, 24),
    );
    final beforeDocument = await (database.select(
      database.documents,
    )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
    final beforeBlocks =
        await (database.select(database.documentBlocks)
              ..where((row) => row.documentId.equals(beforeDocument.id))
              ..orderBy(<OrderingTerm Function(DocumentBlocks)>[
                (row) => OrderingTerm.asc(row.sortRank),
              ]))
            .get();
    final beforeLinks = await _eventLinks(database, eventId);
    final projection = container
        .read(appStoreProvider)
        .requireValue
        .pastDocument;

    final returned = await controller.replacePastEditorDocument(
      projection.createDraft(projection.text),
    );

    final afterDocument = await (database.select(
      database.documents,
    )..where((row) => row.singletonKey.equals('past.main'))).getSingle();
    final afterBlocks =
        await (database.select(database.documentBlocks)
              ..where((row) => row.documentId.equals(afterDocument.id))
              ..orderBy(<OrderingTerm Function(DocumentBlocks)>[
                (row) => OrderingTerm.asc(row.sortRank),
              ]))
            .get();
    final afterLinks = await _eventLinks(database, eventId);
    expect(returned.text, projection.text);
    expect(afterDocument.revision, beforeDocument.revision);
    expect(afterDocument.rowVersion, beforeDocument.rowVersion);
    expect(
      afterBlocks.map((block) => block.id),
      beforeBlocks.map((block) => block.id),
    );
    expect(
      afterBlocks.map((block) => block.semanticHash),
      beforeBlocks.map((block) => block.semanticHash),
    );
    expect(
      afterLinks.map(
        (link) => (link.currentBlockId, link.relation, link.linkState),
      ),
      beforeLinks.map(
        (link) => (link.currentBlockId, link.relation, link.linkState),
      ),
    );
    expect(await _eventState(database, eventId), PastAnchorState.attached);
  });

  test(
    'Past projection edit replaces only the changed event segment',
    () async {
      final firstEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第一项',
        completionDate: '2026-08-24',
        completionTime: '17:37',
      );
      final changedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '复习生理',
        completionDate: '2026-08-24',
        completionTime: '19:03',
        dueDate: DateTime(2026, 8, 24),
      );
      final lastEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第三项',
        completionDate: '2026-08-25',
        completionTime: '08:06',
      );
      final projection = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;
      final firstLinksBefore = await _eventLinks(database, firstEventId);
      final changedLinksBefore = await _eventLinks(database, changedEventId);
      final lastLinksBefore = await _eventLinks(database, lastEventId);

      final saved = await controller.replacePastEditorDocument(
        projection.createDraft(projection.text.replaceFirst('复习生理', '复习病理')),
      );

      expect(saved.text, contains('复习病理 19:03 📅 2026-08-24'));
      expect(saved.text, isNot(contains('复习生理')));
      expect(
        (await _eventLinks(
          database,
          firstEventId,
        )).map((link) => link.currentBlockId),
        firstLinksBefore.map((link) => link.currentBlockId),
      );
      expect(
        (await _eventLinks(
          database,
          lastEventId,
        )).map((link) => link.currentBlockId),
        lastLinksBefore.map((link) => link.currentBlockId),
      );
      final changedLinksAfter = await _eventLinks(database, changedEventId);
      expect(
        changedLinksAfter.map((link) => link.currentBlockId).toSet(),
        hasLength(1),
      );
      expect(
        changedLinksAfter.every(
          (link) => link.relation == AnchorRelation.merged,
        ),
        isTrue,
      );
      expect(
        changedLinksAfter.map((link) => link.currentBlockId).toSet(),
        isNot(changedLinksBefore.map((link) => link.currentBlockId).toSet()),
      );
      expect(
        await _eventState(database, firstEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, changedEventId),
        PastAnchorState.modified,
      );
      expect(
        await _eventState(database, lastEventId),
        PastAnchorState.attached,
      );
    },
  );

  test(
    'Past projection keeps the untouched duplicate event anchor stable',
    () async {
      final changedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '重复事项',
        completionDate: '2026-08-24',
        completionTime: '19:03',
      );
      final untouchedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '重复事项',
        completionDate: '2026-08-24',
        completionTime: '19:03',
      );
      final projection = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;
      final untouchedLinksBefore = await _eventLinks(
        database,
        untouchedEventId,
      );

      final saved = await controller.replacePastEditorDocument(
        projection.createDraft(
          projection.text.replaceFirst('重复事项 19:03', '已修改事项 19:03'),
        ),
      );

      expect(saved.text, contains('已修改事项 19:03'));
      expect(saved.text, contains('重复事项 19:03'));
      expect(
        (await _eventLinks(
          database,
          untouchedEventId,
        )).map((link) => link.currentBlockId),
        untouchedLinksBefore.map((link) => link.currentBlockId),
      );
      expect(
        await _eventState(database, changedEventId),
        PastAnchorState.modified,
      );
      expect(
        await _eventState(database, untouchedEventId),
        PastAnchorState.attached,
      );
    },
  );

  test(
    'Past projection reorders event rows without detaching anchors',
    () async {
      final firstEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第一项',
        completionDate: '2026-08-24',
        completionTime: '19:03',
      );
      final secondEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第二项',
        completionDate: '2026-08-24',
        completionTime: '19:04',
      );
      final projection = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;
      final lines = projection.text.split('\n');
      expect(lines, <String>['2026-08-24', '第一项 19:03', '第二项 19:04']);
      final firstLinksBefore = await _eventLinks(database, firstEventId);
      final secondLinksBefore = await _eventLinks(database, secondEventId);

      final saved = await controller.replacePastEditorDocument(
        projection.createDraft('${lines[0]}\n${lines[2]}\n${lines[1]}'),
      );

      expect(saved.text, '2026-08-24\n第二项 19:04\n第一项 19:03');
      expect(
        saved.segments
            .where((segment) => segment.kind == PastEditorSegmentKind.event)
            .map((segment) => segment.eventId),
        <String?>[secondEventId, firstEventId],
      );
      expect(
        (await _eventLinks(
          database,
          firstEventId,
        )).map((link) => link.currentBlockId),
        firstLinksBefore.map((link) => link.currentBlockId),
      );
      expect(
        (await _eventLinks(
          database,
          secondEventId,
        )).map((link) => link.currentBlockId),
        secondLinksBefore.map((link) => link.currentBlockId),
      );
      expect(
        await _eventState(database, firstEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, secondEventId),
        PastAnchorState.attached,
      );
    },
  );

  test(
    'Past projection does not give an inserted row another edit provenance',
    () async {
      final firstEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第一项',
        completionDate: '2026-08-24',
        completionTime: '19:01',
      );
      final secondEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第二项',
        completionDate: '2026-08-24',
        completionTime: '19:02',
      );
      final changedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第三项',
        completionDate: '2026-08-24',
        completionTime: '19:03',
      );
      final projection = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;

      final saved = await controller.replacePastEditorDocument(
        projection.createDraft(
          '2026-08-24\n插入文本\n第一项 19:01\n第二项 19:02\n第三项已改 19:03',
        ),
      );

      final inserted = saved.segments.singleWhere(
        (segment) => segment.text == '插入文本',
      );
      final changed = saved.segments.singleWhere(
        (segment) => segment.text == '第三项已改 19:03',
      );
      expect(inserted.kind, PastEditorSegmentKind.freeform);
      expect(inserted.eventId, null);
      expect(changed.kind, PastEditorSegmentKind.event);
      expect(changed.eventId, changedEventId);
      expect(
        await _eventState(database, firstEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, secondEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, changedEventId),
        PastAnchorState.modified,
      );
    },
  );

  test(
    'Past projection detaches a deleted row separately from another edit',
    () async {
      final deletedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '删除项',
        completionDate: '2026-08-24',
        completionTime: '19:00',
      );
      final firstEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第一项',
        completionDate: '2026-08-24',
        completionTime: '19:01',
      );
      final secondEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第二项',
        completionDate: '2026-08-24',
        completionTime: '19:02',
      );
      final changedEventId = await _archiveTaskAt(
        controller,
        database,
        title: '第三项',
        completionDate: '2026-08-24',
        completionTime: '19:03',
      );
      final projection = container
          .read(appStoreProvider)
          .requireValue
          .pastDocument;

      final saved = await controller.replacePastEditorDocument(
        projection.createDraft('2026-08-24\n第一项 19:01\n第二项 19:02\n第三项已改 19:03'),
      );

      expect(saved.text, isNot(contains('删除项')));
      expect(
        saved.segments
            .singleWhere((segment) => segment.text == '第三项已改 19:03')
            .eventId,
        changedEventId,
      );
      expect(
        (await _eventLinks(
          database,
          deletedEventId,
        )).every((link) => link.currentBlockId == null),
        isTrue,
      );
      expect(
        await _eventState(database, deletedEventId),
        PastAnchorState.detached,
      );
      expect(
        await _eventState(database, firstEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, secondEventId),
        PastAnchorState.attached,
      );
      expect(
        await _eventState(database, changedEventId),
        PastAnchorState.modified,
      );
    },
  );

  test('Past projection keeps an unrelated replacement unanchored', () async {
    final deletedEventId = await _archiveTaskAt(
      controller,
      database,
      title: '删除项',
      completionDate: '2026-08-24',
      completionTime: '19:00',
    );
    final keptEventId = await _archiveTaskAt(
      controller,
      database,
      title: '保留项',
      completionDate: '2026-08-24',
      completionTime: '19:01',
    );
    final projection = container
        .read(appStoreProvider)
        .requireValue
        .pastDocument;

    final saved = await controller.replacePastEditorDocument(
      projection.createDraft('2026-08-24\n新增项 20:00\n保留项 19:01'),
    );

    final inserted = saved.segments.singleWhere(
      (segment) => segment.text == '新增项 20:00',
    );
    expect(inserted.kind, PastEditorSegmentKind.freeform);
    expect(inserted.eventId, null);
    expect(
      await _eventState(database, deletedEventId),
      PastAnchorState.detached,
    );
    expect(await _eventState(database, keptEventId), PastAnchorState.attached);
    expect(
      (await _eventLinks(
        database,
        deletedEventId,
      )).every((link) => link.currentBlockId == null),
      isTrue,
    );
  });

  test(
    'Note body round-trips checklist, bullet, and numbered block types',
    () async {
      final noteId = await controller.createNote(title: '结构化笔记');
      final initial = container
          .read(appStoreProvider)
          .requireValue
          .notes
          .singleWhere((note) => note.id == noteId);
      await controller.updateNote(
        initial.copyWith(body: '☐ 待办\n☒ 完成\n• 要点\n3. 顺序\n正文'),
      );

      final roundTripped = container
          .read(appStoreProvider)
          .requireValue
          .notes
          .singleWhere((note) => note.id == noteId);
      expect(roundTripped.body, '☐ 待办\n☒ 完成\n• 要点\n1. 顺序\n正文');

      final noteRow = await (database.select(
        database.notes,
      )..where((row) => row.id.equals(noteId))).getSingle();
      final blocks =
          await (database.select(database.documentBlocks)
                ..where((row) => row.documentId.equals(noteRow.documentId))
                ..orderBy(<OrderingTerm Function(DocumentBlocks)>[
                  (row) => OrderingTerm.asc(row.sortRank),
                ]))
              .get();
      expect(blocks.map((block) => block.blockType), <DocumentBlockType>[
        DocumentBlockType.checklist,
        DocumentBlockType.checklist,
        DocumentBlockType.bullet,
        DocumentBlockType.numbered,
        DocumentBlockType.paragraph,
      ]);
      expect(blocks.map((block) => block.isChecked), <bool?>[
        false,
        true,
        null,
        null,
        null,
      ]);

      await controller.updateNote(roundTripped);
      expect(
        container
            .read(appStoreProvider)
            .requireValue
            .notes
            .singleWhere((note) => note.id == noteId)
            .body,
        roundTripped.body,
      );
    },
  );
}

Future<String> _archiveTaskAt(
  AppStoreController controller,
  DangguiDatabase database, {
  required String title,
  required String completionDate,
  required String completionTime,
  DateTime? dueDate,
  String body = '',
  String plan = '',
}) async {
  final taskId = await controller.createTask(
    title: title,
    dueDate: dueDate,
    body: body,
    plan: plan,
  );
  await controller.setTaskActive(taskId, false);
  final completion = DateTime.parse('$completionDate $completionTime:00Z');
  await database.customStatement(
    'UPDATE tasks SET closed_at_utc = ?, closed_local_date = ?, '
    'closed_local_time = ?, closed_zone_id = ? WHERE id = ?',
    <Object?>[
      completion.microsecondsSinceEpoch,
      completionDate,
      completionTime,
      'Asia/Shanghai',
      taskId,
    ],
  );
  await controller.addTaskToPast(taskId);
  final event = await (database.select(
    database.pastEvents,
  )..where((row) => row.sourceTaskId.equals(taskId))).getSingle();
  return event.id;
}

Future<_ArchivedFixture> _archiveSimpleTask(
  AppStoreController controller,
  DangguiDatabase database,
) async {
  final taskId = await controller.createTask(title: '跨块来源事项');
  await controller.setTaskActive(taskId, false);
  await controller.addTaskToPast(taskId);
  final event = await database.select(database.pastEvents).getSingle();
  final timeLink = await _partLinks(
    database,
    eventId: event.id,
    role: PastPartRole.time,
  );
  final titleLink = await _partLinks(
    database,
    eventId: event.id,
    role: PastPartRole.title,
  );
  return _ArchivedFixture(
    eventId: event.id,
    timeBlockId: timeLink.single.currentBlockId!,
    titleBlockId: titleLink.single.currentBlockId!,
  );
}

Future<List<PastAnchorLinkRow>> _eventLinks(
  DangguiDatabase database,
  String eventId,
) async {
  final parts = await (database.select(
    database.pastEventParts,
  )..where((row) => row.eventId.equals(eventId))).get();
  final partIds = parts.map((part) => part.id).toList(growable: false);
  return (database.select(database.pastAnchorLinks)
        ..where((row) => row.partId.isIn(partIds))
        ..orderBy(<OrderingTerm Function(PastAnchorLinks)>[
          (row) => OrderingTerm.asc(row.id),
        ]))
      .get();
}

Future<List<PastAnchorLinkRow>> _partLinks(
  DangguiDatabase database, {
  required String eventId,
  required PastPartRole role,
}) async {
  final parts =
      await (database.select(database.pastEventParts)..where(
            (row) => row.eventId.equals(eventId) & row.role.equalsValue(role),
          ))
          .get();
  final partIds = parts.map((part) => part.id).toList(growable: false);
  return (database.select(database.pastAnchorLinks)
        ..where((row) => row.partId.isIn(partIds))
        ..orderBy(<OrderingTerm Function(PastAnchorLinks)>[
          (row) => OrderingTerm.asc(row.id),
        ]))
      .get();
}

Future<PastAnchorState> _eventState(
  DangguiDatabase database,
  String eventId,
) async {
  final event = await (database.select(
    database.pastEvents,
  )..where((row) => row.id.equals(eventId))).getSingle();
  return event.anchorState;
}

String _serializePast(List<PastBlockViewModel> blocks) {
  var number = 0;
  return blocks
      .map(
        (block) => switch (block.type) {
          DocumentBlockType.bullet => '• ${block.text}',
          DocumentBlockType.numbered => '${++number}. ${block.text}',
          DocumentBlockType.checklist =>
            '${block.isChecked == true ? '☒' : '☐'} ${block.text}',
          _ => block.text,
        },
      )
      .join('\n\n');
}

final class _ArchivedFixture {
  const _ArchivedFixture({
    required this.eventId,
    required this.timeBlockId,
    required this.titleBlockId,
  });

  final String eventId;
  final String timeBlockId;
  final String titleBlockId;
}
