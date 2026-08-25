import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/services/export/portable_export_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late DangguiDatabase database;
  late Directory temporaryDirectory;
  late PortableExportService service;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'danggui-portable-export-test-',
    );
    await _seed(database);
    service = PortableExportService(
      readDatabase: () async => database,
      readTemporaryDirectory: () async => temporaryDirectory,
      nowUtc: () => DateTime.utc(2026, 8, 22, 12, 34, 56),
      operationId: () => 'ABCDEF12-3456-7890-abcd-ef1234567890',
    );
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'full export is stable, complete, readable, and independently verified',
    () async {
      final result = await service.export(PortableExportRequest.full());

      expect(
        p.isWithin(temporaryDirectory.absolute.path, result.file.absolute.path),
        isTrue,
      );
      expect(
        p.basename(result.file.path),
        'danggui-full-20260822T123456Z-abcdef12.zip',
      );
      expect(
        await Directory(result.file.parent.path)
            .list()
            .where((entry) => entry.path.endsWith('.partial'))
            .isEmpty,
        isTrue,
      );

      final verified = await PortableExportVerifier.verify(result.file);
      expect(verified.archiveSha256, result.archiveSha256);
      expect(verified.entryNames, <String>[
        'manifest.json',
        'data.json',
        'markdown/folders.md',
        'markdown/notes.md',
        'markdown/past.md',
        'markdown/tasks.md',
      ]);
      final entries = await _entries(result.file);
      final data = _json(entries['data.json']!);
      final tasks = data['tasks']! as List<dynamic>;
      expect(tasks.map((bundle) => (bundle as Map)['record']['id']), <String>[
        'task-a',
        'task-z',
      ]);
      final notes = data['notes']! as List<dynamic>;
      expect(notes.map((bundle) => (bundle as Map)['record']['id']), <String>[
        'note-b',
        'note-a',
      ]);
      expect(
        (data['folders']! as List<dynamic>).map((folder) => folder['id']),
        <String>['folder-b', 'folder-a'],
      );
      final past = data['past']! as Map<String, dynamic>;
      final current = past['currentDocument']! as Map<String, dynamic>;
      expect(
        (current['blocks']! as List<dynamic>).map(
          (block) => block['plain_text'],
        ),
        contains('用户自由修改后的正文'),
      );
      final events = past['events']! as List<dynamic>;
      expect(events, hasLength(2));
      expect(
        events.first['record']['source_snapshot_json'],
        '{"marker":"raw-event-one","title":"早期事项"}',
      );
      expect(events.last['record']['anchor_state'], 'modified');
      expect(events.last['parts'][0]['anchors'][0]['link_state'], 'linked');

      final tasksMarkdown = utf8.decode(entries['markdown/tasks.md']!);
      expect(tasksMarkdown, contains('2026-08-24T19:50:00'));
      final pastMarkdown = utf8.decode(entries['markdown/past.md']!);
      expect(pastMarkdown, contains('用户自由修改后的正文'));
      expect(pastMarkdown, contains('raw-event-one'));
      expect(result.manifest['appId'], 'com.danggui.memo');
      expect(result.manifest['appVersion'], '1.1.3+4');
      expect(result.manifest['databaseSchemaVersion'], 1);
      final counts = result.manifest['recordCounts']! as Map<String, dynamic>;
      expect(counts['tasks'], 2);
      expect(counts['pastEvents'], 2);
      expect(counts['pastAnchorLinks'], 2);
      expect(result.manifest['contentSha256'], matches(r'^[0-9a-f]{64}$'));
    },
  );

  test(
    'past date range filters provenance but labels the complete free-form text',
    () async {
      final result = await service.export(
        PortableExportRequest.pastDateRange(
          startLocalDate: '2026-08-21',
          endLocalDate: '2026-08-22',
        ),
      );
      final entries = await _entries(result.file);
      final data = _json(entries['data.json']!);

      expect(data['tasks'], isEmpty);
      expect(data['notes'], isEmpty);
      expect(data['folders'], isEmpty);
      final past = data['past']! as Map<String, dynamic>;
      final events = past['events']! as List<dynamic>;
      expect(events, hasLength(1));
      expect(events.single['record']['id'], 'event-2');
      expect(
        events.single['record']['source_snapshot_json'],
        contains('raw-event-two'),
      );
      expect(
        past['currentDocument']['selectionPolicy'],
        contains('cannot be losslessly or honestly attributed'),
      );
      expect(
        (past['currentDocument']['blocks'] as List<dynamic>).map(
          (block) => block['plain_text'],
        ),
        contains('用户自由修改后的正文'),
      );
      final markdown = utf8.decode(entries['markdown/past.md']!);
      expect(markdown, contains('2026-08-21 至 2026-08-22'));
      expect(markdown, contains('raw-event-two'));
      expect(markdown, isNot(contains('raw-event-one')));
      final scope = result.manifest['scope']! as Map<String, dynamic>;
      expect(scope['kind'], 'pastDateRange');
      expect(scope['startLocalDate'], '2026-08-21');
      expect(scope['endLocalDate'], '2026-08-22');
    },
  );

  test(
    'pastAll contains only the complete Past document and provenance',
    () async {
      final result = await service.export(PortableExportRequest.pastAll());
      final entries = await _entries(result.file);
      final data = _json(entries['data.json']!);

      expect(data['tasks'], isEmpty);
      expect(data['notes'], isEmpty);
      expect(data['folders'], isEmpty);
      final past = data['past']! as Map<String, dynamic>;
      expect(past['included'], isTrue);
      expect(
        (past['currentDocument']['blocks'] as List<dynamic>).map(
          (block) => block['plain_text'],
        ),
        contains('用户自由修改后的正文'),
      );
      expect(past['events'], hasLength(2));
      expect(
        past['events'][0]['record']['source_snapshot_json'],
        contains('raw-event-one'),
      );
      expect(past['events'][1]['parts'][0]['anchors'], hasLength(1));
      expect(result.manifest['scope'], containsPair('kind', 'pastAll'));
      expect(
        utf8.decode(entries['markdown/tasks.md']!),
        contains('本次导出范围不包含事项'),
      );
      expect(
        utf8.decode(entries['markdown/notes.md']!),
        contains('本次导出范围不包含笔记'),
      );
      expect(
        utf8.decode(entries['markdown/past.md']!),
        contains('raw-event-two'),
      );
      expect(
        (await PortableExportVerifier.verify(result.file)).entryNames,
        hasLength(6),
      );
    },
  );

  test(
    'pastSelection exports exact free text without inventing provenance',
    () async {
      const selected = '  手动选中的第一行\n\n- 保留 Markdown\n末尾空格  ';
      final result = await service.export(
        PortableExportRequest.pastSelection(selected),
      );
      final entries = await _entries(result.file);
      final data = _json(entries['data.json']!);

      expect(data['tasks'], isEmpty);
      expect(data['notes'], isEmpty);
      expect(data['folders'], isEmpty);
      final past = data['past']! as Map<String, dynamic>;
      expect(past['included'], isTrue);
      expect(past, isNot(contains('currentDocument')));
      expect(past['events'], isEmpty);
      expect(past['selection']['type'], 'userSelectedFreeText');
      expect(past['selection']['text'], selected);
      expect(
        past['selection']['sourceAttribution'],
        contains('no source events'),
      );
      final markdown = utf8.decode(entries['markdown/past.md']!);
      expect(markdown, contains(selected));
      expect(markdown, contains('不伪造任何来源事件'));
      expect(markdown, isNot(contains('raw-event-one')));
      expect(
        utf8.decode(entries['data.json']!),
        isNot(contains('raw-event-two')),
      );
      final counts = result.manifest['recordCounts']! as Map<String, dynamic>;
      expect(counts['pastCurrentBlocks'], 0);
      expect(counts['pastEvents'], 0);
      expect(counts['pastEventParts'], 0);
      expect(counts['pastAnchorLinks'], 0);
      expect(result.manifest['scope'], <String, dynamic>{
        'kind': 'pastSelection',
        'selectionType': 'userSelectedFreeText',
      });
      expect(
        (await PortableExportVerifier.verify(result.file)).entryNames,
        hasLength(6),
      );
    },
  );

  test('note filters are exact and checksum tampering is rejected', () async {
    final byIds = await service.export(
      PortableExportRequest.notesByIds(<String>[
        'note-a',
        'missing-note',
        'note-a',
      ]),
    );
    final byIdsData = _json((await _entries(byIds.file))['data.json']!);
    expect(
      (byIdsData['notes']! as List<dynamic>).map(
        (bundle) => bundle['record']['id'],
      ),
      <String>['note-a'],
    );
    expect(
      (byIdsData['folders']! as List<dynamic>).map((folder) => folder['id']),
      <String>['folder-b'],
    );

    final byFolder = await service.export(
      PortableExportRequest.notesInFolder('folder-a'),
    );
    final byFolderEntries = await _entries(byFolder.file);
    final byFolderData = _json(byFolderEntries['data.json']!);
    expect(
      (byFolderData['notes']! as List<dynamic>).map(
        (bundle) => bundle['record']['id'],
      ),
      <String>['note-b'],
    );
    expect(byFolderData['past']['included'], isFalse);

    final decoded = ZipDecoder().decodeBytes(
      await byFolder.file.readAsBytes(),
      verify: true,
    );
    final changed = Archive();
    for (final entry in decoded.files) {
      final content = entry.name == 'markdown/notes.md'
          ? utf8.encode('被篡改')
          : entry.content;
      changed.addFile(ArchiveFile.bytes(entry.name, content));
    }
    final damaged = File(p.join(temporaryDirectory.path, 'damaged.zip'));
    await damaged.writeAsBytes(ZipEncoder().encodeBytes(changed));
    await expectLater(
      PortableExportVerifier.verify(damaged),
      throwsA(isA<FormatException>()),
    );
  });

  test('request validation rejects ambiguous or impossible filters', () {
    expect(
      () => PortableExportRequest.notesByIds(const <String>[]),
      throwsArgumentError,
    );
    expect(
      () => PortableExportRequest.pastSelection(' \n\t '),
      throwsArgumentError,
    );
    expect(
      () => PortableExportRequest.pastDateRange(
        startLocalDate: '2026-02-30',
        endLocalDate: '2026-03-01',
      ),
      throwsArgumentError,
    );
    expect(
      () => PortableExportRequest.pastDateRange(
        startLocalDate: '2026-08-23',
        endLocalDate: '2026-08-22',
      ),
      throwsArgumentError,
    );
  });
}

Future<void> _seed(DangguiDatabase database) async {
  await database.customSelect('SELECT 1').get();
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const now = 1787392800000000;
  await database.transaction(() async {
    await database.customStatement(
      'INSERT INTO folders '
      '(id, name, normalized_name, sort_rank, created_at_utc, updated_at_utc, '
      'row_version) VALUES (?, ?, ?, ?, ?, ?, 1), (?, ?, ?, ?, ?, ?, 1)',
      <Object?>[
        'folder-a',
        '实验',
        '实验',
        2048,
        now,
        now,
        'folder-b',
        '论文',
        '论文',
        1024,
        now,
        now,
      ],
    );
    for (final document in const <(String, String)>[
      ('task-doc-a', 'taskBody'),
      ('task-doc-z', 'taskBody'),
      ('note-doc-a', 'note'),
      ('note-doc-b', 'note'),
    ]) {
      await database.customStatement(
        'INSERT INTO documents '
        '(id, kind, singleton_key, format_version, revision, semantic_hash, '
        'created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
        <Object?>[document.$1, document.$2, hash, now, now],
      );
    }
    await database.customStatement(
      'INSERT INTO tasks '
      '(id, document_id, title, due_local_date, plan_text, status, manual_rank, '
      'closed_at_utc, closed_local_date, closed_local_time, closed_zone_id, '
      'archived_at_utc, deleted_at_utc, semantic_hash, created_at_utc, '
      'updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, 1), '
      '(?, ?, ?, NULL, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, 1)',
      <Object?>[
        'task-z',
        'task-doc-z',
        '后排事项',
        '2026-08-30',
        '稍后处理',
        'active',
        2048,
        hash,
        now,
        now,
        'task-a',
        'task-doc-a',
        '先排事项',
        '晚饭后开始',
        'active',
        1024,
        hash,
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO reminders '
      '(id, task_id, scheduled_local_date_time, scheduled_zone_id, '
      'scheduled_at_utc, snoozed_until_utc, sound_enabled, vibration_enabled, '
      'status, pause_reason, snooze_count, schedule_revision, last_fired_at_utc, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, ?, NULL, 1, 1, ?, NULL, 0, 1, NULL, ?, ?, 1)',
      <Object?>[
        'reminder-a',
        'task-a',
        '2026-08-24T19:50:00',
        'Asia/Shanghai',
        now,
        'scheduled',
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO notes '
      '(id, document_id, folder_id, title, pinned_at_utc, deleted_at_utc, '
      'semantic_hash, created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?, 1), '
      '(?, ?, ?, ?, ?, NULL, ?, ?, ?, 1)',
      <Object?>[
        'note-a',
        'note-doc-a',
        'folder-b',
        '论文摘要',
        hash,
        now,
        now + 20,
        'note-b',
        'note-doc-b',
        'folder-a',
        '实验数据',
        now + 10,
        hash,
        now,
        now + 10,
      ],
    );
    final pastDocument = await database
        .customSelect(
          "SELECT id FROM documents WHERE singleton_key = 'past.main'",
        )
        .getSingle();
    final pastDocumentId = pastDocument.read<String>('id');
    for (final block in <(String, String, String, int, int?)>[
      ('block-past-date', pastDocumentId, 'pastDate', 1024, null),
      ('block-past-free', pastDocumentId, 'paragraph', 2048, null),
      ('block-past-linked', pastDocumentId, 'pastEntry', 3072, null),
      ('block-task-a', 'task-doc-a', 'checklist', 1024, 1),
      ('block-task-z', 'task-doc-z', 'paragraph', 1024, null),
      ('block-note-a', 'note-doc-a', 'paragraph', 1024, null),
      ('block-note-b', 'note-doc-b', 'checklist', 1024, 0),
    ]) {
      final text = switch (block.$1) {
        'block-past-date' => '2026-08-22',
        'block-past-free' => '用户自由修改后的正文',
        'block-past-linked' => '修改后的锚点文字',
        'block-task-a' => '核对引用',
        'block-task-z' => '事项正文',
        'block-note-a' => '笔记 A 正文',
        _ => '完成数据清理',
      };
      await database.customStatement(
        'INSERT INTO document_blocks '
        '(id, document_id, parent_block_id, sort_rank, block_type, plain_text, '
        'payload_json, attributes_json, is_checked, semantic_hash, '
        'created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          block.$1,
          block.$2,
          block.$4,
          block.$3,
          text,
          '{}',
          '{}',
          block.$5,
          hash,
          now,
          now,
        ],
      );
    }
    for (final event in <(String, int, String, String, String)>[
      (
        'event-1',
        1,
        '2026-08-20',
        '{"marker":"raw-event-one","title":"早期事项"}',
        'attached',
      ),
      (
        'event-2',
        2,
        '2026-08-22',
        '{"marker":"raw-event-two","title":"当日事项"}',
        'modified',
      ),
    ]) {
      await database.customStatement(
        'INSERT INTO past_events '
        '(id, document_id, source_task_id, append_sequence, completed_at_utc, '
        'completion_local_date, completion_zone_id, source_snapshot_version, '
        'source_snapshot_json, source_sha256, anchor_state, created_at_utc, '
        'updated_at_utc, row_version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          event.$1,
          pastDocumentId,
          event.$1 == 'event-1' ? 'source-task-1' : 'source-task-2',
          event.$2,
          now + event.$2,
          event.$3,
          'Asia/Shanghai',
          event.$4,
          hash,
          event.$5,
          now,
          now,
        ],
      );
      final partId = 'part-${event.$2}';
      await database.customStatement(
        'INSERT INTO past_event_parts '
        '(id, event_id, role, source_order, original_payload_json, '
        'original_plain_text, original_sha256) VALUES (?, ?, ?, 0, ?, ?, ?)',
        <Object?>[
          partId,
          event.$1,
          'title',
          '{"preserved":true}',
          '原始标题 ${event.$2}',
          hash,
        ],
      );
      await database.customStatement(
        'INSERT INTO past_anchor_links '
        '(id, part_id, current_block_id, last_known_block_id, relation, '
        'link_state, current_sha256, updated_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'anchor-${event.$2}',
          partId,
          event.$1 == 'event-2' ? 'block-past-linked' : null,
          event.$1 == 'event-2' ? 'block-past-linked' : 'deleted-block',
          event.$1 == 'event-2' ? 'replacement' : 'original',
          event.$1 == 'event-2' ? 'linked' : 'deleted',
          event.$1 == 'event-2' ? hash : null,
          now,
        ],
      );
    }
  });
}

Future<Map<String, Uint8List>> _entries(File file) async {
  final archive = ZipDecoder().decodeBytes(
    await file.readAsBytes(),
    verify: true,
  );
  return <String, Uint8List>{
    for (final entry in archive.files)
      entry.name: Uint8List.fromList(entry.content),
  };
}

Map<String, dynamic> _json(Uint8List bytes) {
  return (jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}
