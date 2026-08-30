import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/database_file_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/integrity_corruption_fixture.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'danggui-database-recovery-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'prepared restore leaves an existing valid live database intact',
    () async {
      final live = await _databaseWithTask(directory, 'live.sqlite', 'old');
      final candidate = await _databaseWithTask(
        directory,
        'live.sqlite.restore-candidate-operation-a',
        'new',
      );
      final safety = await live.copy('${live.path}.pre-restore-operation-a');
      await DatabaseFileRecovery.writePreparedJournal(
        liveFile: live,
        candidate: candidate,
        safetyCopy: safety,
      );

      await DatabaseFileRecovery.recoverIfNeeded(live);

      expect(await _taskTitle(live), 'old');
      expect(await candidate.exists(), isFalse);
      expect(await DatabaseFileRecovery.journalFile(live).exists(), isFalse);
      expect(await safety.exists(), isTrue);
    },
  );

  test(
    'missing live database promotes a validated prepared candidate',
    () async {
      final live = File(p.join(directory.path, 'live.sqlite'));
      final candidate = await _databaseWithTask(
        directory,
        'live.sqlite.restore-candidate-operation-b',
        'replacement',
      );
      final safety = await _databaseWithTask(
        directory,
        'live.sqlite.pre-restore-operation-b',
        'safety',
      );
      await DatabaseFileRecovery.writePreparedJournal(
        liveFile: live,
        candidate: candidate,
        safetyCopy: safety,
      );

      await DatabaseFileRecovery.recoverIfNeeded(live);

      expect(await _taskTitle(live), 'replacement');
      expect(await DatabaseFileRecovery.journalFile(live).exists(), isFalse);
    },
  );

  test(
    'damaged live and candidate recover from the verified safety copy',
    () async {
      final live = File(p.join(directory.path, 'live.sqlite'));
      await live.writeAsString('damaged-live', flush: true);
      final candidate = await _databaseWithTask(
        directory,
        'live.sqlite.restore-candidate-operation-c',
        'candidate',
      );
      final safety = await _databaseWithTask(
        directory,
        'live.sqlite.pre-restore-operation-c',
        'safety',
      );
      await DatabaseFileRecovery.writePreparedJournal(
        liveFile: live,
        candidate: candidate,
        safetyCopy: safety,
      );
      await corruptDatabaseSoQuickPassesButIntegrityFails(candidate);

      await DatabaseFileRecovery.recoverIfNeeded(live);

      expect(await _taskTitle(live), 'safety');
      expect(
        await directory
            .list()
            .where(
              (entity) => p
                  .basename(entity.path)
                  .startsWith('live.sqlite.failed-restore-'),
            )
            .length,
        1,
      );
    },
  );

  test('prepared journal rejects corruption hidden from quick_check', () async {
    final live = await _databaseWithTask(directory, 'live.sqlite', 'live');
    final candidate = await _databaseWithTask(
      directory,
      'live.sqlite.restore-candidate-operation-d',
      'candidate',
    );
    final safety = await _databaseWithTask(
      directory,
      'live.sqlite.pre-restore-operation-d',
      'safety',
    );
    await corruptDatabaseSoQuickPassesButIntegrityFails(candidate);

    final corrupted = DangguiDatabase.open(candidate);
    try {
      expect(await corrupted.quickCheck(), <String>['ok']);
      expect(await corrupted.integrityCheck(), isNot(<String>['ok']));
    } finally {
      await corrupted.close();
    }

    await expectLater(
      DatabaseFileRecovery.writePreparedJournal(
        liveFile: live,
        candidate: candidate,
        safetyCopy: safety,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await DatabaseFileRecovery.journalFile(live).exists(), isFalse);
    expect(await _taskTitle(live), 'live');
    expect(await _taskTitle(safety), 'safety');
  });

  test(
    'startup cleanup removes only known plaintext staging directories',
    () async {
      final backupWork = Directory(
        p.join(directory.path, 'danggui-backup-work'),
      );
      final restoreWork = Directory(
        p.join(directory.path, 'danggui-restore-validation'),
      );
      final portableExports = Directory(
        p.join(directory.path, 'danggui-portable-exports'),
      );
      final manualBackups = Directory(
        p.join(directory.path, 'danggui-backups'),
      );
      final unrelated = File(p.join(directory.path, 'keep-me.sqlite'));
      await backupWork.create();
      await restoreWork.create();
      await portableExports.create();
      await manualBackups.create();
      await File(p.join(backupWork.path, 'snapshot.sqlite')).writeAsString('x');
      await File(p.join(restoreWork.path, 'restore.sqlite')).writeAsString('x');
      await File(p.join(portableExports.path, 'danggui-full.zip'))
          .writeAsString('plaintext');
      await File(p.join(manualBackups.path, 'danggui-manual.dgbak'))
          .writeAsString('plaintext');
      await unrelated.writeAsString('safe');

      await DatabaseFileRecovery.purgeStalePlaintextArtifacts(directory);

      expect(await backupWork.exists(), isFalse);
      expect(await restoreWork.exists(), isFalse);
      expect(await portableExports.exists(), isFalse);
      expect(await manualBackups.exists(), isFalse);
      expect(await unrelated.readAsString(), 'safe');
    },
  );

  test(
    'startup removes exact orphan candidates only when journal is absent',
    () async {
      final live = await _databaseWithTask(directory, 'live.sqlite', 'live');
      final orphan = await _databaseWithTask(
        directory,
        'live.sqlite.restore-candidate-orphan_1',
        'orphan',
      );
      final orphanWal = File('${orphan.path}-wal');
      await orphanWal.writeAsString('stale sidecar');
      final unrelated = File('${live.path}.restore-candidate-keep.txt');
      await unrelated.writeAsString('keep');

      await DatabaseFileRecovery.recoverIfNeeded(live);

      expect(await _taskTitle(live), 'live');
      expect(await orphan.exists(), isFalse);
      expect(await orphanWal.exists(), isFalse);
      expect(await unrelated.readAsString(), 'keep');
    },
  );
}

Future<File> _databaseWithTask(
  Directory directory,
  String name,
  String title,
) async {
  final file = File(p.join(directory.path, name));
  final database = DangguiDatabase.open(file);
  final now = DateTime.utc(2026, 8, 28).microsecondsSinceEpoch;
  await database.customSelect('SELECT 1').get();
  await database.transaction(() async {
    await database.customStatement(
      'INSERT INTO documents '
      '(id, kind, singleton_key, format_version, revision, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
      <Object?>[
        'document-$title',
        'taskBody',
        title.padRight(64, title).substring(0, 64),
        now,
        now,
      ],
    );
    await database.customStatement(
      'INSERT INTO tasks '
      '(id, document_id, title, due_local_date, plan_text, status, '
      'manual_rank, closed_at_utc, closed_local_date, closed_local_time, '
      'closed_zone_id, archived_at_utc, deleted_at_utc, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, ?, NULL, ?, ?, 1, NULL, NULL, NULL, NULL, NULL, NULL, '
      '?, ?, ?, 1)',
      <Object?>[
        'task-$title',
        'document-$title',
        title,
        '',
        'active',
        title.padRight(64, title).substring(0, 64),
        now,
        now,
      ],
    );
  });
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await database.close();
  return file;
}

Future<String> _taskTitle(File file) async {
  final database = DangguiDatabase.open(file);
  try {
    return (await database.customSelect('SELECT title FROM tasks').getSingle())
        .read<String>('title');
  } finally {
    await database.close();
  }
}
