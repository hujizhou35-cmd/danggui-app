import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/services/backup/backup_codec.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('danggui-restore-test-');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'inspect validates contents without opening or modifying live DB',
    () async {
      final package = await _sourcePackage(directory);
      final before = await package.readAsBytes();
      var liveReads = 0;
      final service = BackupService(
        readDatabase: () async {
          liveReads++;
          throw StateError('inspect must not open live database');
        },
        readDatabaseFile: () async {
          liveReads++;
          throw StateError('inspect must not read live path');
        },
        invalidateDatabase: () => liveReads++,
      );

      final inspection = await service.inspect(package);

      expect(inspection.encrypted, isFalse);
      expect(inspection.manifest['datasetId'], isNotEmpty);
      expect(inspection.recordCounts['tasks'], 1);
      expect(inspection.recordCounts['notes'], 1);
      expect(inspection.recordCounts['past_events'], 1);
      expect(inspection.archiveSha256, hasLength(64));
      expect(liveReads, 0);
      expect(await package.readAsBytes(), orderedEquals(before));
    },
  );

  test(
    'merge imports visible entities but preserves current settings',
    () async {
      final package = await _sourcePackage(directory);
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);

      final result = await harness.service.restore(
        package,
        mode: RestoreMode.merge,
      );

      expect(result.mode, RestoreMode.merge);
      expect(await result.safetyCopy.exists(), isTrue);
      expect(await _count(harness.database, 'folders'), 1);
      expect(await _count(harness.database, 'tasks'), 1);
      expect(await _count(harness.database, 'notes'), 1);
      expect(await _count(harness.database, 'reminders'), 1);
      expect(await _count(harness.database, 'past_events'), 1);
      expect(await _count(harness.database, 'past_event_parts'), 1);
      expect(await _count(harness.database, 'past_anchor_links'), 1);
      expect(await _count(harness.database, 'trash_entries'), 1);
      expect(await _count(harness.database, 'platform_jobs'), 1);
      // One explicit separator plus the imported source block.
      expect(await _count(harness.database, 'document_blocks'), 4);
      final settings = await harness.database
          .customSelect('SELECT locale_mode FROM app_settings WHERE id = 1')
          .getSingle();
      expect(settings.read<String>('locale_mode'), 'system');
      final audit = await harness.database
          .customSelect('SELECT mode, status, summary_json FROM restore_runs')
          .getSingle();
      expect(audit.read<String>('mode'), 'merge');
      expect(audit.read<String>('status'), 'succeeded');
      expect(audit.read<String>('summary_json'), contains('kept-current'));
      final safety = DangguiDatabase.open(result.safetyCopy);
      try {
        expect(await safety.quickCheck(), <String>['ok']);
        expect(await _count(safety, 'tasks'), 0);
      } finally {
        await safety.close();
      }
      expect(harness.invalidations, 1);
    },
  );

  test('merge remaps conflicts, never overwrites, and is idempotent', () async {
    final package = await _sourcePackage(directory);
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);
    await _insertCurrentTaskCollision(harness.database);

    await harness.service.restore(package, mode: RestoreMode.merge);
    final current = await harness.database
        .customSelect(
          "SELECT title, semantic_hash FROM tasks WHERE id = 'task-1'",
        )
        .getSingle();
    expect(current.read<String>('title'), '当前内容，绝不覆盖');
    expect(current.read<String>('semantic_hash'), _hash('c'));
    expect(await _count(harness.database, 'tasks'), 2);
    expect(await _count(harness.database, 'folders'), 1);
    final importedNote = await harness.database
        .customSelect("SELECT folder_id FROM notes WHERE title = '来源笔记'")
        .getSingle();
    expect(importedNote.read<String>('folder_id'), 'current-folder');
    expect(await _count(harness.database, 'restore_conflicts'), greaterThan(0));
    final imported = await harness.database
        .customSelect("SELECT id FROM tasks WHERE title = '来源事项'")
        .getSingle();
    expect(imported.read<String>('id'), isNot('task-1'));

    final pastBlocksAfterFirst = await _count(
      harness.database,
      'document_blocks',
    );
    await harness.service.restore(package, mode: RestoreMode.merge);

    expect(await _count(harness.database, 'tasks'), 2);
    expect(await _count(harness.database, 'notes'), 1);
    expect(await _count(harness.database, 'past_events'), 1);
    expect(
      await _count(harness.database, 'document_blocks'),
      pastBlocksAfterFirst,
    );
    expect(await _count(harness.database, 'restore_runs'), 2);
  });

  test('merge expires an overdue reminder instead of scheduling it', () async {
    final package = await _sourcePackage(directory, reminderExpired: true);
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);

    await harness.service.restore(package, mode: RestoreMode.merge);

    final reminder = await harness.database
        .customSelect('SELECT status FROM reminders')
        .getSingle();
    expect(reminder.read<String>('status'), 'expired');
    expect(await _count(harness.database, 'platform_jobs'), 0);
  });

  test(
    'default replace keeps regression compatibility and writes audit',
    () async {
      final package = await _sourcePackage(directory);
      final harness = await _LiveHarness.create(directory);
      await _insertCurrentTaskCollision(harness.database);

      final result = await harness.service.restore(package);

      expect(result.mode, RestoreMode.replace);
      expect(await result.safetyCopy.exists(), isTrue);
      final replacement = DangguiDatabase.open(harness.file);
      addTearDown(replacement.close);
      final tasks = await replacement
          .customSelect('SELECT id, title FROM tasks ORDER BY id')
          .get();
      expect(tasks, hasLength(1));
      expect(tasks.single.read<String>('title'), '来源事项');
      final audit = await replacement
          .customSelect(
            "SELECT mode, status FROM restore_runs ORDER BY started_at_utc DESC LIMIT 1",
          )
          .getSingle();
      expect(audit.read<String>('mode'), 'replace');
      expect(audit.read<String>('status'), 'succeeded');
      expect(harness.invalidations, 1);
      harness.databaseClosedByRestore = true;
    },
  );

  test('unsupported package is rejected before any live mutation', () async {
    final sourceFile = File(p.join(directory.path, 'unsupported.sqlite'));
    final database = DangguiDatabase.open(sourceFile);
    final datasetId =
        (await database
                .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
                .getSingle())
            .read<String>('dataset_id');
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await database.close();
    final package = File(p.join(directory.path, 'unsupported.dgbak'));
    await package.writeAsBytes(
      await BackupCodec.encode(
        databaseBytes: await sourceFile.readAsBytes(),
        manifest: <String, Object?>{
          'appId': 'com.danggui.memo',
          'appVersion': '9.0.0',
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
          'datasetId': datasetId,
          'databaseSchemaVersion': 2,
          'recordCounts': const <String, int>{},
        },
      ),
    );
    var liveReads = 0;
    final service = BackupService(
      readDatabase: () async {
        liveReads++;
        throw StateError('must not open live DB');
      },
      readDatabaseFile: () async {
        liveReads++;
        throw StateError('must not read live file');
      },
      invalidateDatabase: () => liveReads++,
    );

    await expectLater(
      service.restore(package, mode: RestoreMode.merge),
      throwsA(isA<FormatException>()),
    );
    expect(liveReads, 0);
  });
}

final class _LiveHarness {
  _LiveHarness(this.file, this.database) {
    service = BackupService(
      readDatabase: () async => database,
      readDatabaseFile: () async => file,
      invalidateDatabase: () => invalidations++,
    );
  }

  static Future<_LiveHarness> create(Directory directory) async {
    final file = File(p.join(directory.path, 'live.sqlite'));
    final database = DangguiDatabase.open(file);
    await database.customSelect('SELECT 1').get();
    return _LiveHarness(file, database);
  }

  final File file;
  final DangguiDatabase database;
  late final BackupService service;
  int invalidations = 0;
  bool databaseClosedByRestore = false;

  Future<void> dispose() async {
    if (!databaseClosedByRestore) await database.close();
  }
}

Future<File> _sourcePackage(
  Directory directory, {
  bool reminderExpired = false,
}) async {
  final sourceFile = File(p.join(directory.path, 'source.sqlite'));
  final database = DangguiDatabase.open(sourceFile);
  await database.customSelect('SELECT 1').get();
  await _populateSource(database, reminderExpired: reminderExpired);
  final datasetId =
      (await database
              .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
              .getSingle())
          .read<String>('dataset_id');
  final counts = <String, int>{};
  for (final table in const <String>[
    'tasks',
    'notes',
    'folders',
    'document_blocks',
    'past_events',
    'reminders',
    'trash_entries',
  ]) {
    counts[table] = await _count(database, table);
  }
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await database.close();
  final package = File(p.join(directory.path, 'source.dgbak'));
  await package.writeAsBytes(
    await BackupCodec.encode(
      databaseBytes: await sourceFile.readAsBytes(),
      manifest: <String, Object?>{
        'appId': 'com.danggui.memo',
        'appVersion': '1.0.0+1',
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        'datasetId': datasetId,
        'databaseSchemaVersion': 1,
        'kind': 'manual',
        'recordCounts': counts,
      },
    ),
    flush: true,
  );
  return package;
}

Future<void> _populateSource(
  DangguiDatabase database, {
  required bool reminderExpired,
}) async {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final scheduledAt = DateTime.now()
      .toUtc()
      .add(Duration(days: reminderExpired ? -2 : 2))
      .microsecondsSinceEpoch;
  await database.transaction(() async {
    await database.customStatement(
      "UPDATE app_settings SET locale_mode = 'ru' WHERE id = 1",
    );
    await database.customStatement(
      'INSERT INTO folders '
      '(id, name, normalized_name, sort_rank, created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, 1000, ?, ?, 1)',
      <Object?>['folder-1', '研究', '研究', now, now],
    );
    await database.customStatement(
      'INSERT INTO documents '
      '(id, kind, singleton_key, format_version, revision, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, NULL, 1, 1, ?, ?, ?, 1)',
      <Object?>['doc-task-1', 'taskBody', _hash('d'), now, now],
    );
    await _insertBlock(
      database,
      id: 'block-task-1',
      documentId: 'doc-task-1',
      text: '核对新增引用，补充理论背景。',
      hash: _hash('b'),
      now: now,
    );
    await database.customStatement(
      'INSERT INTO tasks '
      '(id, document_id, title, due_local_date, plan_text, status, manual_rank, '
      'closed_at_utc, closed_local_date, closed_local_time, closed_zone_id, '
      'archived_at_utc, deleted_at_utc, semantic_hash, created_at_utc, '
      'updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, ?, ?, 1000, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, 1)',
      <Object?>[
        'task-1',
        'doc-task-1',
        '来源事项',
        '2099-08-25',
        '晚饭后开始，预计两个小时',
        'active',
        _hash('t'),
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
      'VALUES (?, ?, ?, ?, ?, NULL, 1, 1, ?, NULL, 0, 3, NULL, ?, ?, 1)',
      <Object?>[
        'reminder-1',
        'task-1',
        '2099-08-24T19:50:00',
        'Asia/Shanghai',
        scheduledAt,
        'scheduled',
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO documents '
      '(id, kind, singleton_key, format_version, revision, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, NULL, 1, 1, ?, ?, ?, 1)',
      <Object?>['doc-note-1', 'note', _hash('e'), now, now],
    );
    await _insertBlock(
      database,
      id: 'block-note-1',
      documentId: 'doc-note-1',
      text: '离线笔记正文',
      hash: _hash('n'),
      now: now,
    );
    await database.customStatement(
      'INSERT INTO notes '
      '(id, document_id, folder_id, title, pinned_at_utc, deleted_at_utc, '
      'semantic_hash, created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, 1)',
      <Object?>[
        'note-1',
        'doc-note-1',
        'folder-1',
        '来源笔记',
        now,
        _hash('q'),
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO trash_entries '
      '(id, entity_type, entity_id, deleted_at_utc, purge_after_utc, '
      'restore_context_json, snapshot_sha256) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'trash-1',
        'note',
        'note-1',
        now,
        now + const Duration(days: 30).inMicroseconds,
        '{"folderId":"folder-1"}',
        _hash('x'),
      ],
    );
    final pastId =
        (await database
                .customSelect(
                  "SELECT id FROM documents WHERE singleton_key = 'past.main'",
                )
                .getSingle())
            .read<String>('id');
    await _insertBlock(
      database,
      id: 'past-block-1',
      documentId: pastId,
      text: '19:30 来源事项',
      hash: _hash('p'),
      now: now,
      type: 'pastEntry',
    );
    await database.customStatement(
      'INSERT INTO past_events '
      '(id, document_id, source_task_id, append_sequence, completed_at_utc, '
      'completion_local_date, completion_zone_id, source_snapshot_version, '
      'source_snapshot_json, source_sha256, anchor_state, created_at_utc, '
      'updated_at_utc, row_version) '
      'VALUES (?, ?, ?, 1, ?, ?, ?, 1, ?, ?, ?, ?, ?, 1)',
      <Object?>[
        'past-event-1',
        pastId,
        'task-1',
        now,
        '2026-08-22',
        'Asia/Shanghai',
        '{"title":"来源事项"}',
        _hash('s'),
        'attached',
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO past_event_parts '
      '(id, event_id, role, source_order, original_payload_json, '
      'original_plain_text, original_sha256) VALUES (?, ?, ?, 0, ?, ?, ?)',
      <Object?>[
        'past-part-1',
        'past-event-1',
        'title',
        '{}',
        '来源事项',
        _hash('r'),
      ],
    );
    await database.customStatement(
      'INSERT INTO past_anchor_links '
      '(id, part_id, current_block_id, last_known_block_id, relation, '
      'link_state, current_sha256, updated_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'past-anchor-1',
        'past-part-1',
        'past-block-1',
        'past-block-1',
        'original',
        'linked',
        _hash('p'),
        now,
      ],
    );
    for (final record in const <List<String>>[
      <String>['task', 'task-1', 'doc-task-1', '来源事项', '正文', '2099-08-25'],
      <String>['note', 'note-1', 'doc-note-1', '来源笔记', '正文', ''],
      <String>['past', 'past.main', '', '', '来源事项', '2026-08-22'],
    ]) {
      await database.customStatement(
        'INSERT INTO search_records '
        '(scope, entity_id, document_id, title_norm, body_norm, date_key, updated_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          record[0],
          record[1],
          record[2].isEmpty ? null : record[2],
          record[3],
          record[4],
          record[5],
          now,
        ],
      );
    }
  });
}

Future<void> _insertCurrentTaskCollision(DangguiDatabase database) async {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  await database.customStatement(
    'INSERT INTO folders '
    '(id, name, normalized_name, sort_rank, created_at_utc, updated_at_utc, row_version) '
    'VALUES (?, ?, ?, 1, ?, ?, 1)',
    <Object?>['current-folder', '研究', '研究', now, now],
  );
  await database.customStatement(
    'INSERT INTO documents '
    '(id, kind, singleton_key, format_version, revision, semantic_hash, '
    'created_at_utc, updated_at_utc, row_version) '
    'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
    <Object?>['current-doc', 'taskBody', _hash('z'), now, now],
  );
  await database.customStatement(
    'INSERT INTO tasks '
    '(id, document_id, title, due_local_date, plan_text, status, manual_rank, '
    'closed_at_utc, closed_local_date, closed_local_time, closed_zone_id, '
    'archived_at_utc, deleted_at_utc, semantic_hash, created_at_utc, '
    'updated_at_utc, row_version) '
    'VALUES (?, ?, ?, NULL, ?, ?, 1, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, 1)',
    <Object?>[
      'task-1',
      'current-doc',
      '当前内容，绝不覆盖',
      '',
      'active',
      _hash('c'),
      now,
      now,
    ],
  );
}

Future<void> _insertBlock(
  DangguiDatabase database, {
  required String id,
  required String documentId,
  required String text,
  required String hash,
  required int now,
  String type = 'paragraph',
}) {
  return database.customStatement(
    'INSERT INTO document_blocks '
    '(id, document_id, parent_block_id, sort_rank, block_type, plain_text, '
    'payload_json, attributes_json, is_checked, semantic_hash, created_at_utc, '
    'updated_at_utc, row_version) '
    'VALUES (?, ?, NULL, 1000, ?, ?, ?, ?, NULL, ?, ?, ?, 1)',
    <Object?>[id, documentId, type, text, '{}', '{}', hash, now, now],
  );
}

Future<int> _count(DangguiDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS total FROM $table')
      .getSingle();
  return row.read<int>('total');
}

String _hash(String value) => value.padRight(64, value).substring(0, 64);
