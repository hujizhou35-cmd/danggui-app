import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/services/backup/backup_merge.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '1000-source merge stays fast and preserves 500 local records',
    () async {
      final source = DangguiDatabase(NativeDatabase.memory());
      final target = DangguiDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      await source.customSelect('SELECT 1').get();
      await target.customSelect('SELECT 1').get();
      await _seed(
        source,
        prefix: 'source',
        taskCount: 1000,
        pastBlockCount: 1000,
        locale: 'ru',
      );
      await _seed(
        target,
        prefix: 'local',
        taskCount: 500,
        pastBlockCount: 500,
        locale: 'ja',
      );
      const restoreRunId = 'nonempty-performance-restore';
      final now = DateTime.utc(2026, 8, 22).microsecondsSinceEpoch;
      await target.customStatement(
        'INSERT INTO restore_runs '
        '(id, source_name, source_sha256, mode, source_schema_version, '
        'pre_restore_backup_run_id, status, summary_json, started_at_utc, '
        'completed_at_utc, error_code) '
        "VALUES (?, 'stress.dgbak', NULL, 'merge', 1, NULL, 'running', NULL, ?, NULL, NULL)",
        <Object?>[restoreRunId, now],
      );
      final dataset = await source
          .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
          .getSingle();

      final watch = Stopwatch()..start();
      final result = await BackupMergeEngine(
        source: source,
        target: target,
        restoreRunId: restoreRunId,
        originDatasetId: dataset.read<String>('dataset_id'),
        nowUtc: () => DateTime.utc(2026, 8, 22, 12),
      ).run();
      watch.stop();

      expect(
        watch.elapsed,
        lessThan(const Duration(seconds: 30)),
        reason: 'A disjoint non-empty merge must use bounded bulk I/O.',
      );
      expect(await _count(target, 'tasks'), 1500);
      expect(await _count(target, 'document_blocks'), 3001);
      expect(await _count(target, 'folders'), 2);
      expect(await _count(target, 'import_provenance'), 4001);
      expect(await _count(target, 'restore_conflicts'), 0);
      final imported = result.summary['imported']! as Map;
      expect(imported['folders'], 1);
      expect(imported['tasks'], 1000);
      expect(imported['pastBlocks'], 1000);
      expect(result.summary['pastBlocksAppended'], 1000);
      final local = await target
          .customSelect("SELECT title FROM tasks WHERE id = 'local-task-0000'")
          .getSingle();
      final incoming = await target
          .customSelect("SELECT title FROM tasks WHERE id = 'source-task-0999'")
          .getSingle();
      expect(local.read<String>('title'), 'local task 0000');
      expect(incoming.read<String>('title'), 'source task 0999');
      final settings = await target
          .customSelect('SELECT locale_mode FROM app_settings WHERE id = 1')
          .getSingle();
      expect(settings.read<String>('locale_mode'), 'ja');
      final past = await target
          .customSelect(
            "SELECT plain_text FROM document_blocks b JOIN documents d "
            "ON d.id = b.document_id WHERE d.singleton_key = 'past.main' "
            'ORDER BY b.sort_rank, b.id',
          )
          .get();
      expect(past, hasLength(1501));
      expect(past.first.read<String>('plain_text'), 'local past 0000');
      expect(
        past.any((row) => row.read<String>('plain_text') == 'source past 0999'),
        isTrue,
      );
      expect(
        past.where(
          (row) => row.read<String>('plain_text').startsWith('── 导入于'),
        ),
        hasLength(1),
      );
      expect(await target.quickCheck(), const <String>['ok']);
      expect(await target.foreignKeyCheck(), isEmpty);
      // ignore: avoid_print
      print(
        'DANGGUI_NONEMPTY_MERGE_METRICS '
        '{"localTasks":500,"sourceTasks":1000,'
        '"localPastBlocks":500,"sourcePastBlocks":1000,'
        '"elapsedMilliseconds":${watch.elapsedMilliseconds},'
        '"rssBytes":${ProcessInfo.currentRss}}',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

Future<void> _seed(
  DangguiDatabase database, {
  required String prefix,
  required int taskCount,
  required int pastBlockCount,
  required String locale,
}) async {
  final past = await database
      .customSelect(
        "SELECT id FROM documents WHERE singleton_key = 'past.main'",
      )
      .getSingle();
  final pastId = past.read<String>('id');
  final base = DateTime.utc(2020, 1, 1).microsecondsSinceEpoch;
  await database.customStatement(
    'UPDATE app_settings SET locale_mode = ? WHERE id = 1',
    <Object?>[locale],
  );
  await database.customStatement(
    'INSERT INTO folders '
    '(id, name, normalized_name, sort_rank, created_at_utc, updated_at_utc, '
    'row_version) VALUES (?, ?, ?, 1024, ?, ?, 1)',
    <Object?>['$prefix-folder', '$prefix folder', '$prefix-folder', base, base],
  );
  for (var start = 0; start < taskCount; start += 250) {
    final end = (start + 250).clamp(0, taskCount);
    await database.batch((batch) {
      for (var index = start; index < end; index++) {
        final suffix = index.toString().padLeft(4, '0');
        final taskId = '$prefix-task-$suffix';
        final documentId = '$prefix-document-$suffix';
        final blockId = '$prefix-block-$suffix';
        final title = '$prefix task $suffix';
        final body = '$prefix body $suffix';
        final hash = (index + 1).toRadixString(16).padLeft(64, '0');
        final timestamp = base + index;
        batch.customStatement(
          'INSERT INTO documents '
          '(id, kind, singleton_key, format_version, revision, semantic_hash, '
          'created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, 'taskBody', NULL, 1, 1, ?, ?, ?, 1)",
          <Object?>[documentId, hash, timestamp, timestamp],
        );
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, 1024, 'paragraph', ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[blockId, documentId, body, hash, timestamp, timestamp],
        );
        batch.customStatement(
          'INSERT INTO tasks '
          '(id, document_id, title, due_local_date, plan_text, status, '
          'manual_rank, closed_at_utc, closed_local_date, closed_local_time, '
          'closed_zone_id, archived_at_utc, deleted_at_utc, semantic_hash, '
          'created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, ?, NULL, '', 'active', ?, NULL, NULL, NULL, NULL, "
          'NULL, NULL, ?, ?, ?, 1)',
          <Object?>[
            taskId,
            documentId,
            title,
            index * 1024,
            hash,
            timestamp,
            timestamp,
          ],
        );
        batch.customStatement(
          'INSERT INTO search_records '
          '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
          "updated_at_utc) VALUES ('task', ?, ?, ?, ?, '', ?)",
          <Object?>[taskId, documentId, title, body, timestamp],
        );
      }
    });
  }
  for (var start = 0; start < pastBlockCount; start += 250) {
    final end = (start + 250).clamp(0, pastBlockCount);
    await database.batch((batch) {
      for (var index = start; index < end; index++) {
        final suffix = index.toString().padLeft(4, '0');
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, ?, 'pastEntry', ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[
            '$prefix-past-$suffix',
            pastId,
            index * 1024,
            '$prefix past $suffix',
            (100000 + index).toRadixString(16).padLeft(64, '0'),
            base + taskCount + index,
            base + taskCount + index,
          ],
        );
      }
    });
  }
  await database.customStatement(
    'UPDATE documents SET revision = 1, semantic_hash = ?, '
    'updated_at_utc = ? WHERE id = ?',
    <Object?>['f'.padLeft(64, '0'), base + taskCount + pastBlockCount, pastId],
  );
  await database.customStatement(
    'INSERT INTO search_records '
    '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
    "updated_at_utc) VALUES ('past', 'past.main', ?, '', ?, '', ?)",
    <Object?>[pastId, '$prefix past', base + taskCount + pastBlockCount],
  );
}

Future<int> _count(DangguiDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS total FROM $table')
      .getSingle();
  return row.read<int>('total');
}
