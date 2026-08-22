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
