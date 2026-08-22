import 'dart:convert';
import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:danggui/src/services/export/portable_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _taskCount = 2000;
const _noteCount = 1000;
const _pastBlockCount = 3600;
const _stepBudget = Duration(seconds: 30);
const _totalBudget = Duration(seconds: 90);
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large local dataset remains searchable, editable, exportable, and restorable', () async {
    final root = await Directory.systemTemp.createTemp(
      'danggui-large-dataset-',
    );
    final metrics = _StressMetrics();
    final totalWatch = Stopwatch()..start();
    DangguiDatabase? source;
    DangguiDatabase? mergeTarget;
    DangguiDatabase? replaceTarget;
    DangguiDatabase? replaced;
    try {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (call) async {
            if (call.method == 'getTemporaryDirectory') return root.path;
            throw PlatformException(
              code: 'unsupported-path-provider-method',
              message: call.method,
            );
          });

      final sourceFile = File(p.join(root.path, 'source.sqlite'));
      source = DangguiDatabase.open(sourceFile);
      await source.customSelect('SELECT 1').get();

      await metrics.measure('seed', () => _seedLargeDataset(source!));
      expect(await source.quickCheck(), const <String>['ok']);
      expect(await source.foreignKeyCheck(), isEmpty);

      await metrics.measure('search', () async {
        final search = DriftSearchRepository(source!);
        final taskHits = await search.search(
          'needle-task-1729',
          scope: SearchScope.task,
        );
        final noteHits = await search.search(
          'needle-note-0999',
          scope: SearchScope.note,
        );
        final pastHits = await search.search(
          'needle-past-3456',
          scope: SearchScope.past,
        );
        expect(taskHits, hasLength(1));
        expect(taskHits.single.entityId, 'task-1729');
        expect(noteHits, hasLength(1));
        expect(noteHits.single.entityId, 'note-0999');
        expect(pastHits, hasLength(1));
        expect(pastHits.single.entityId, 'past.main');
      });

      late String pastDocumentId;
      late List<DocumentBlockModel> pastBlocks;
      await metrics.measure('past-read', () async {
        final row = await source!
            .customSelect(
              "SELECT id FROM documents WHERE singleton_key = 'past.main'",
            )
            .getSingle();
        pastDocumentId = row.read<String>('id');
        pastBlocks = await DriftDocumentRepository(source!)
            .getBlocks(DocumentId(pastDocumentId));
        expect(pastBlocks, hasLength(_pastBlockCount));
        expect(pastBlocks.first.plainText, contains('2017-01-01'));
        expect(pastBlocks.last.plainText, contains('2026-11'));
      });

      await metrics.measure('past-full-document-edit', () async {
        final document = await (source!.select(
          source.documents,
        )..where((row) => row.id.equals(pastDocumentId))).getSingle();
        const editedIndex = 1777;
        final edited = <DocumentBlockModel>[
          for (var index = 0; index < pastBlocks.length; index++)
            if (index == editedIndex)
              DocumentBlockModel(
                id: pastBlocks[index].id,
                documentId: pastBlocks[index].documentId,
                parentBlockId: pastBlocks[index].parentBlockId,
                sortRank: pastBlocks[index].sortRank,
                blockType: pastBlocks[index].blockType,
                plainText: '${pastBlocks[index].plainText} edited-past-marker',
                payloadJson: pastBlocks[index].payloadJson,
                attributesJson: pastBlocks[index].attributesJson,
                isChecked: pastBlocks[index].isChecked,
              )
            else
              pastBlocks[index],
        ];
        final revision = await DriftDocumentRepository(source!).replaceBlocks(
          DocumentId(pastDocumentId),
          edited,
          expectedRevision: document.revision,
        );
        expect(revision, document.revision + 1);
        final hits = await DriftSearchRepository(source!)
            .search('edited-past-marker', scope: SearchScope.past);
        expect(hits, hasLength(1));
      });

      late PortableExportResult portable;
      await metrics.measure('portable-export-and-verify', () async {
        portable = await PortableExportService(
          readDatabase: () async => source!,
          readTemporaryDirectory: () async => root,
          nowUtc: () => DateTime.utc(2026, 8, 22, 12),
          operationId: () => 'stress-export-operation',
        ).export(PortableExportRequest.full());
        final verified = await PortableExportVerifier.verify(portable.file);
        expect(verified.archiveSha256, portable.archiveSha256);
        expect(verified.entryNames, hasLength(6));
        final counts = portable.manifest['recordCounts']! as Map;
        expect(counts['tasks'], _taskCount);
        expect(counts['notes'], _noteCount);
        expect(counts['pastCurrentBlocks'], _pastBlockCount);
        metrics.fileBytes['portableExport'] = await portable.file.length();
      });

      final sourceBackupService = BackupService(
        readDatabase: () async => source!,
        readDatabaseFile: () async => sourceFile,
        invalidateDatabase: () {},
      );
      late BackupExport backup;
      await metrics.measure('backup-create', () async {
        backup = await sourceBackupService.create(
          outputDirectory: Directory(p.join(root.path, 'backups')),
        );
        expect(backup.encrypted, isFalse);
        expect(await backup.file.exists(), isTrue);
        metrics.fileBytes['backup'] = await backup.file.length();
      });

      await metrics.measure('backup-inspect', () async {
        final inspection = await sourceBackupService.inspect(backup.file);
        expect(inspection.archiveSha256, hasLength(64));
        expect(inspection.recordCounts['tasks'], _taskCount);
        expect(inspection.recordCounts['notes'], _noteCount);
        expect(
          inspection.recordCounts['document_blocks'],
          _taskCount + _noteCount + _pastBlockCount,
        );
      });

      final mergeFile = File(p.join(root.path, 'merge-target.sqlite'));
      mergeTarget = DangguiDatabase.open(mergeFile);
      await mergeTarget.customSelect('SELECT 1').get();
      final mergeService = BackupService(
        readDatabase: () async => mergeTarget!,
        readDatabaseFile: () async => mergeFile,
        invalidateDatabase: () {},
      );
      await metrics.measure('backup-merge', () async {
        final result = await mergeService.restore(
          backup.file,
          mode: RestoreMode.merge,
        );
        expect(result.mode, RestoreMode.merge);
        expect(await result.safetyCopy.exists(), isTrue);
        expect(await _count(mergeTarget!, 'tasks'), _taskCount);
        expect(await _count(mergeTarget!, 'notes'), _noteCount);
        expect(
          await _count(mergeTarget!, 'document_blocks'),
          _taskCount + _noteCount + _pastBlockCount + 1,
        );
        expect(await mergeTarget!.quickCheck(), const <String>['ok']);
        expect(await mergeTarget!.foreignKeyCheck(), isEmpty);
        final imported = result.summary['imported']! as Map;
        expect(imported['tasks'], _taskCount);
        expect(imported['notes'], _noteCount);
        expect(imported['pastBlocks'], _pastBlockCount);
      });

      final replaceFile = File(p.join(root.path, 'replace-target.sqlite'));
      replaceTarget = DangguiDatabase.open(replaceFile);
      await replaceTarget.customSelect('SELECT 1').get();
      var replaceInvalidations = 0;
      final replaceService = BackupService(
        readDatabase: () async => replaceTarget!,
        readDatabaseFile: () async => replaceFile,
        invalidateDatabase: () => replaceInvalidations++,
      );
      await metrics.measure('backup-replace', () async {
        final result = await replaceService.restore(backup.file);
        replaceTarget = null;
        expect(result.mode, RestoreMode.replace);
        expect(replaceInvalidations, 1);
        expect(await result.safetyCopy.exists(), isTrue);
        replaced = DangguiDatabase.open(replaceFile);
        await replaced!.customSelect('SELECT 1').get();
        expect(await _count(replaced!, 'tasks'), _taskCount);
        expect(await _count(replaced!, 'notes'), _noteCount);
        expect(
          await _count(replaced!, 'document_blocks'),
          _taskCount + _noteCount + _pastBlockCount,
        );
        expect(await replaced!.quickCheck(), const <String>['ok']);
        expect(await replaced!.foreignKeyCheck(), isEmpty);
      });

      totalWatch.stop();
      metrics.total = totalWatch.elapsed;
      metrics.finalRssBytes = ProcessInfo.currentRss;
      expect(
        totalWatch.elapsed,
        lessThan(_totalBudget),
        reason: 'The complete stress path must stay below $_totalBudget.',
      );
      // This line is intentionally machine-readable for CI logs. Memory is
      // observational only; time and integrity checks are the hard gates.
      // ignore: avoid_print
      print('DANGGUI_STRESS_METRICS ${jsonEncode(metrics.toJson())}');
    } finally {
      totalWatch.stop();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      await replaced?.close();
      await replaceTarget?.close();
      await mergeTarget?.close();
      await source?.close();
      if (await root.exists()) await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> _seedLargeDataset(DangguiDatabase database) async {
  final pastDocument = await database
      .customSelect(
        "SELECT id FROM documents WHERE singleton_key = 'past.main'",
      )
      .getSingle();
  final pastDocumentId = pastDocument.read<String>('id');
  final baseMicros = DateTime.utc(2017, 1, 1).microsecondsSinceEpoch;

  await database.batch((batch) {
    for (var index = 0; index < 32; index++) {
      batch.customStatement(
        'INSERT INTO folders '
        '(id, name, normalized_name, sort_rank, created_at_utc, '
        'updated_at_utc, row_version) VALUES (?, ?, ?, ?, ?, ?, 1)',
        <Object?>[
          'folder-$index',
          '资料夹 ${index.toString().padLeft(2, '0')}',
          'folder-${index.toString().padLeft(2, '0')}',
          index * 1024,
          baseMicros + index,
          baseMicros + index,
        ],
      );
    }
  });

  for (var start = 0; start < _taskCount; start += 200) {
    final end = (start + 200).clamp(0, _taskCount);
    await database.batch((batch) {
      for (var index = start; index < end; index++) {
        final suffix = index.toString().padLeft(4, '0');
        final id = 'task-$suffix';
        final documentId = 'doc-task-$suffix';
        final blockId = 'block-task-$suffix';
        final title = index == 1729
            ? '事项 $suffix needle-task-1729'
            : '事项 $suffix 离线工作';
        final body = '事项 $suffix 的详细执行记录与备注。';
        final now = baseMicros + index;
        batch.customStatement(
          'INSERT INTO documents '
          '(id, kind, singleton_key, format_version, revision, semantic_hash, '
          'created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, 'taskBody', NULL, 1, 1, ?, ?, ?, 1)",
          <Object?>[documentId, _fakeHash(index + 1), now, now],
        );
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, 1024, 'paragraph', ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[
            blockId,
            documentId,
            body,
            _fakeHash(10000 + index),
            now,
            now,
          ],
        );
        batch.customStatement(
          'INSERT INTO tasks '
          '(id, document_id, title, due_local_date, plan_text, status, '
          'manual_rank, closed_at_utc, closed_local_date, closed_local_time, '
          'closed_zone_id, archived_at_utc, deleted_at_utc, semantic_hash, '
          'created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, ?, ?, ?, 'active', ?, NULL, NULL, NULL, NULL, NULL, "
          'NULL, ?, ?, ?, 1)',
          <Object?>[
            id,
            documentId,
            title,
            _isoDate(DateTime.utc(2020).add(Duration(days: index % 3650))),
            '计划 $suffix',
            index * 1024,
            _fakeHash(20000 + index),
            now,
            now,
          ],
        );
        batch.customStatement(
          'INSERT INTO search_records '
          '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
          'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'task',
            id,
            documentId,
            title.toLowerCase(),
            body,
            _isoDate(DateTime.utc(2020).add(Duration(days: index % 3650))),
            now,
          ],
        );
      }
    });
  }

  for (var start = 0; start < _noteCount; start += 200) {
    final end = (start + 200).clamp(0, _noteCount);
    await database.batch((batch) {
      for (var index = start; index < end; index++) {
        final suffix = index.toString().padLeft(4, '0');
        final id = 'note-$suffix';
        final documentId = 'doc-note-$suffix';
        final blockId = 'block-note-$suffix';
        final title = '笔记 $suffix 研究资料';
        final body = index == 999
            ? '笔记 $suffix needle-note-0999 的离线正文。'
            : '笔记 $suffix 的离线正文与检查清单。';
        final now = baseMicros + _taskCount + index;
        batch.customStatement(
          'INSERT INTO documents '
          '(id, kind, singleton_key, format_version, revision, semantic_hash, '
          'created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, 'note', NULL, 1, 1, ?, ?, ?, 1)",
          <Object?>[documentId, _fakeHash(30000 + index), now, now],
        );
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, 1024, 'paragraph', ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[
            blockId,
            documentId,
            body,
            _fakeHash(40000 + index),
            now,
            now,
          ],
        );
        batch.customStatement(
          'INSERT INTO notes '
          '(id, document_id, folder_id, title, pinned_at_utc, deleted_at_utc, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          'VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?, 1)',
          <Object?>[
            id,
            documentId,
            'folder-${index % 32}',
            title,
            _fakeHash(50000 + index),
            now,
            now,
          ],
        );
        batch.customStatement(
          'INSERT INTO search_records '
          '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
          'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>['note', id, documentId, title, body, '', now],
        );
      }
    });
  }

  final pastText = StringBuffer();
  for (var start = 0; start < _pastBlockCount; start += 300) {
    final end = (start + 300).clamp(0, _pastBlockCount);
    await database.batch((batch) {
      for (var index = start; index < end; index++) {
        final date = DateTime.utc(2017, 1, 1).add(Duration(days: index));
        final suffix = index.toString().padLeft(4, '0');
        final heading = index % 12 == 0 && index != 3456;
        final text = heading
            ? _isoDate(date)
            : index == 3456
            ? '${_isoDate(date)} 19:50 needle-past-3456 已完成事项'
            : '${_isoDate(date)} 19:50 已完成事项 $suffix';
        pastText.writeln(text);
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, ?, ?, ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[
            'past-block-$suffix',
            pastDocumentId,
            index * 1024,
            heading ? 'pastDate' : 'pastEntry',
            text,
            _fakeHash(60000 + index),
            baseMicros + _taskCount + _noteCount + index,
            baseMicros + _taskCount + _noteCount + index,
          ],
        );
      }
    });
  }
  await database.customStatement(
    'UPDATE documents SET revision = 1, semantic_hash = ?, updated_at_utc = ? '
    'WHERE id = ?',
    <Object?>[
      _fakeHash(70000),
      baseMicros + _taskCount + _noteCount + _pastBlockCount,
      pastDocumentId,
    ],
  );
  await database.customStatement(
    'INSERT INTO search_records '
    '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
    'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'past',
      'past.main',
      pastDocumentId,
      '',
      pastText.toString().toLowerCase(),
      '2017-01-01..2026-11-09',
      baseMicros + _taskCount + _noteCount + _pastBlockCount,
    ],
  );
}

Future<int> _count(DangguiDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS total FROM $table')
      .getSingle();
  return row.read<int>('total');
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _fakeHash(int value) => value.toRadixString(16).padLeft(64, '0');

final class _StressMetrics {
  final Map<String, int> elapsedMilliseconds = <String, int>{};
  final Map<String, int> rssBytesAfterStep = <String, int>{};
  final Map<String, int> fileBytes = <String, int>{};
  Duration total = Duration.zero;
  int finalRssBytes = 0;

  Future<T> measure<T>(String name, Future<T> Function() operation) async {
    final watch = Stopwatch()..start();
    final result = await operation();
    watch.stop();
    elapsedMilliseconds[name] = watch.elapsedMilliseconds;
    rssBytesAfterStep[name] = ProcessInfo.currentRss;
    expect(
      watch.elapsed,
      lessThan(_stepBudget),
      reason: '$name exceeded the generous $_stepBudget step budget.',
    );
    return result;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dataset': <String, int>{
      'tasks': _taskCount,
      'notes': _noteCount,
      'pastBlocks': _pastBlockCount,
    },
    'elapsedMilliseconds': elapsedMilliseconds,
    'totalMilliseconds': total.inMilliseconds,
    'rssBytesAfterStep': rssBytesAfterStep,
    'finalRssBytes': finalRssBytes,
    'fileBytes': fileBytes,
  };
}
