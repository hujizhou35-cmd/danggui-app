import 'dart:async';
import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/database_file_recovery.dart';
import 'package:danggui/src/data/device_alarm_generation_store.dart';
import 'package:danggui/src/services/backup/backup_codec.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/integrity_corruption_fixture.dart';

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

  test('partial restore staging write is removed after failure', () async {
    final package = await _sourcePackage(directory);
    final service = BackupService(
      readDatabase: () async => throw StateError('must not open live DB'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
      writeRestoreStaging: (file, bytes) async {
        await file.writeAsBytes(bytes.take(128).toList(), flush: true);
        throw const FileSystemException('simulated staging write failure');
      },
    );

    await expectLater(
      service.inspect(package),
      throwsA(isA<FileSystemException>()),
    );

    expect(await _restoreValidationArtifacts(directory), isEmpty);
  });

  test('restore staging is removed even when database close fails', () async {
    final package = await _sourcePackage(directory);
    final service = BackupService(
      readDatabase: () async => throw StateError('must not open live DB'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
      closeRestoreDatabase: (database) async {
        await database.close();
        throw StateError('simulated close failure');
      },
    );

    await expectLater(
      service.inspect(package),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'simulated close failure',
        ),
      ),
    );

    expect(await _restoreValidationArtifacts(directory), isEmpty);
  });

  test('body failure is not masked by restore staging close failure', () async {
    final package = await _sourcePackage(directory);
    final service = BackupService(
      readDatabase: () async => throw StateError('primary live failure'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
      closeRestoreDatabase: (database) async {
        await database.close();
        throw StateError('secondary close failure');
      },
    );

    await expectLater(
      service.restore(package, mode: RestoreMode.merge),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'primary live failure',
        ),
      ),
    );

    expect(await _restoreValidationArtifacts(directory), isEmpty);
  });

  test(
    'inspect and replace reject quick-only corruption before touching live',
    () async {
      final package = await _sourcePackage(
        directory,
        integrityOnlyCorruption: true,
      );
      final corruptSource = DangguiDatabase.open(
        File(p.join(directory.path, 'source.sqlite')),
      );
      expect(await corruptSource.quickCheck(), <String>['ok']);
      expect(await corruptSource.integrityCheck(), isNot(<String>['ok']));
      await corruptSource.close();

      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);
      await _insertSimpleTask(
        harness.database,
        id: 'live-must-remain',
        title: '不能被损坏备份覆盖',
      );
      await harness.database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final beforeHash = await sha256OfBytes(await harness.file.readAsBytes());
      var liveReads = 0;
      var invalidations = 0;
      final service = BackupService(
        readDatabase: () async {
          liveReads++;
          return harness.database;
        },
        readDatabaseFile: () async {
          liveReads++;
          return harness.file;
        },
        invalidateDatabase: () => invalidations++,
        readTemporaryDirectory: () async => directory,
      );

      await expectLater(
        service.inspect(package),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.restore(package),
        throwsA(isA<FormatException>()),
      );

      expect(liveReads, 0);
      expect(invalidations, 0);
      expect(await sha256OfBytes(await harness.file.readAsBytes()), beforeHash);
      expect(
        await harness.database
            .customSelect(
              "SELECT title FROM tasks WHERE id = 'live-must-remain'",
            )
            .getSingle()
            .then((row) => row.read<String>('title')),
        '不能被损坏备份覆盖',
      );
      expect(await _restoreValidationArtifacts(directory), isEmpty);
      final liveArtifacts = await directory
          .list()
          .map((entity) => p.basename(entity.path))
          .where(
            (name) =>
                name.startsWith('live.sqlite.restore-candidate-') ||
                name.startsWith('live.sqlite.pre-restore-') ||
                name == 'live.sqlite.restore-journal-v1.json',
          )
          .toList();
      expect(liveArtifacts, isEmpty);
    },
  );

  test('unexpected delete trigger is rejected before live access', () async {
    final package = await _sourcePackage(
      directory,
      mutateSchema: (database) => database.customStatement(
        'CREATE TRIGGER malicious_platform_delete '
        'AFTER DELETE ON platform_jobs BEGIN DELETE FROM tasks; END',
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
        throw StateError('must not read live DB');
      },
      invalidateDatabase: () => liveReads++,
      readTemporaryDirectory: () async => directory,
    );

    await expectLater(
      service.restore(package),
      throwsA(isA<FormatException>()),
    );

    expect(liveReads, 0);
    expect(await _restoreValidationArtifacts(directory), isEmpty);
  });

  test('database missing an expected column is rejected by schema', () async {
    final package = await _sourcePackage(
      directory,
      mutateSchema: (database) =>
          database.customStatement('ALTER TABLE notes DROP COLUMN title'),
    );
    final service = BackupService(
      readDatabase: () async => throw StateError('must not open live DB'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
    );

    await expectLater(
      service.inspect(package),
      throwsA(isA<FormatException>()),
    );

    expect(await _restoreValidationArtifacts(directory), isEmpty);
  });

  test('source size is checked before package bytes are allocated', () async {
    final source = File(p.join(directory.path, 'oversized.dgbak'));
    await source.writeAsBytes(const <int>[1], flush: true);
    var byteReads = 0;
    final service = BackupService(
      readDatabase: () async => throw StateError('must not read live DB'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readSourceLength: (_) async => BackupCodec.maximumPackageBytes + 1,
      readSourceBytes: (_) async {
        byteReads++;
        throw StateError('oversized source must not be read');
      },
    );

    await expectLater(service.inspect(source), throwsA(isA<FormatException>()));

    expect(byteReads, 0);
  });

  test(
    'stream growth after stat is rejected at the allocation bound',
    () async {
      final source = File(p.join(directory.path, 'growing.dgbak'));
      await source.writeAsBytes(const <int>[1], flush: true);
      var liveReads = 0;
      final service = BackupService(
        readDatabase: () async {
          liveReads++;
          throw StateError('must not read live DB');
        },
        readDatabaseFile: () async {
          liveReads++;
          throw StateError('must not read live DB');
        },
        invalidateDatabase: () => liveReads++,
        readSourceLength: (_) async => 3,
        openSourceBytes: (_) =>
            Stream<List<int>>.fromIterable(const <List<int>>[
              <int>[1, 2],
              <int>[3, 4, 5],
            ]),
        maximumSourceBytes: 4,
      );

      await expectLater(
        service.inspect(source),
        throwsA(isA<FormatException>()),
      );

      expect(liveReads, 0);
    },
  );

  test('stream length must still equal the pre-read stat', () async {
    final source = File(p.join(directory.path, 'replaced.dgbak'));
    await source.writeAsBytes(const <int>[1], flush: true);
    final service = BackupService(
      readDatabase: () async => throw StateError('must not read live DB'),
      readDatabaseFile: () async => throw StateError('must not read live DB'),
      invalidateDatabase: () {},
      readSourceLength: (_) async => 3,
      openSourceBytes: (_) => Stream<List<int>>.value(const <int>[1, 2]),
      maximumSourceBytes: 4,
    );

    await expectLater(
      service.inspect(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('changed'),
        ),
      ),
    );
  });

  test(
    'create snapshots one committed SQLite view before later writes',
    () async {
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);
      await _insertSimpleTask(
        harness.database,
        id: 'before-snapshot',
        title: '快照前',
      );
      final output = Directory(p.join(directory.path, 'backups'));
      final service = BackupService(
        readDatabase: () async => harness.database,
        readDatabaseFile: () async => harness.file,
        invalidateDatabase: () {},
        readTemporaryDirectory: () async => directory,
        faultInjector: (point) async {
          if (point == BackupFaultPoint.snapshotCreated) {
            await _insertSimpleTask(
              harness.database,
              id: 'after-snapshot',
              title: '快照后',
            );
          }
        },
      );

      final result = await service.create(outputDirectory: output);
      final inspection = await service.inspect(result.file);

      expect(inspection.recordCounts['tasks'], 1);
      expect(await _count(harness.database, 'tasks'), 2);
      expect(await result.file.exists(), isTrue);
      expect(
        await output
            .list()
            .where((entry) => entry.path.endsWith('.partial'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test('create persists removal of device-only platform jobs', () async {
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);
    const generation = '77777777-7777-4777-8777-777777777777';
    await _createDeviceAlarmGeneration(harness.database, generation);
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    await harness.database.customStatement(
      'INSERT INTO platform_jobs '
      '(id, kind, aggregate_id, aggregate_revision, dedupe_key, payload_json, '
      'status, attempts, next_attempt_at_utc, last_error_code, '
      'created_at_utc, updated_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, NULL, ?, ?)',
      <Object?>[
        'device-job',
        'scheduleReminder',
        'reminder-on-source-device',
        7,
        'device-job:7',
        '{}',
        'pending',
        now,
        now,
        now,
      ],
    );
    final result = await harness.service.create(
      outputDirectory: Directory(p.join(directory.path, 'backups')),
    );
    final decoded = await BackupCodec.decode(await result.file.readAsBytes());
    final portableDatabaseFile = File(
      p.join(directory.path, 'portable-snapshot.sqlite'),
    );
    await portableDatabaseFile.writeAsBytes(decoded.databaseBytes, flush: true);
    final portableDatabase = DangguiDatabase.open(portableDatabaseFile);
    addTearDown(portableDatabase.close);

    expect(await _count(portableDatabase, 'platform_jobs'), 0);
    expect(await _count(harness.database, 'platform_jobs'), 1);
    final portableAudits = await portableDatabase
        .customSelect('SELECT summary_json FROM restore_runs')
        .get();
    expect(
      portableAudits.map((row) => row.read<String>('summary_json')),
      everyElement(isNot(contains(DeviceAlarmGenerationStore.markerKey))),
    );
    expect(
      await DeviceAlarmGenerationStore(harness.database).readCurrent(),
      generation,
    );
  });

  test(
    'create fails closed instead of exporting an opaque generation marker',
    () async {
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);
      const generation = '79797979-7979-4979-8979-797979797979';
      await _createDeviceAlarmGeneration(harness.database, generation);
      await harness.database.customStatement(
        'UPDATE restore_runs SET summary_json = ? WHERE id = ?',
        <Object?>['{"alarmGeneration":"$generation"', generation],
      );
      final output = Directory(p.join(directory.path, 'opaque-output'));

      await expectLater(
        harness.service.create(outputDirectory: output),
        throwsA(isA<FormatException>()),
      );

      expect(await output.exists(), isTrue);
      expect(await output.list().isEmpty, isTrue);
    },
  );

  test('create fault after partial write removes incomplete output', () async {
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);
    final output = Directory(p.join(directory.path, 'backups'));
    final service = BackupService(
      readDatabase: () async => harness.database,
      readDatabaseFile: () async => harness.file,
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
      faultInjector: (point) async {
        if (point == BackupFaultPoint.partialArchiveWritten) {
          throw const FileSystemException('simulated disk interruption');
        }
      },
    );

    await expectLater(
      service.create(outputDirectory: output),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      await output
          .list()
          .where(
            (entry) =>
                entry.path.endsWith('.partial') ||
                entry.path.endsWith('.dgbak'),
          )
          .isEmpty,
      isTrue,
    );
    final audit = await harness.database
        .customSelect('SELECT status, error_code FROM backup_runs')
        .getSingle();
    expect(audit.read<String>('status'), 'failed');
    expect(audit.read<String>('error_code'), 'FileSystemException');
  });

  test(
    'create cleanup is exhaustive and preserves the operation error',
    () async {
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);
      final deleteAttempts = <String>[];
      final service = BackupService(
        readDatabase: () async => harness.database,
        readDatabaseFile: () async => harness.file,
        invalidateDatabase: () {},
        readTemporaryDirectory: () async => directory,
        faultInjector: (point) async {
          if (point != BackupFaultPoint.snapshotCreated) return;
          final work = Directory(p.join(directory.path, 'danggui-backup-work'));
          final snapshot = await work
              .list()
              .where((entry) => entry.path.endsWith('.sqlite'))
              .cast<File>()
              .single;
          await File('${snapshot.path}-wal').writeAsString('sensitive-wal');
          await File('${snapshot.path}-shm').writeAsString('sensitive-shm');
          throw StateError('primary snapshot failure');
        },
        deleteCreateArtifact: (file) async {
          deleteAttempts.add(p.basename(file.path));
          if (deleteAttempts.length == 1) {
            throw const FileSystemException('first cleanup failed');
          }
          if (await file.exists()) await file.delete();
        },
      );

      await expectLater(
        service.create(
          outputDirectory: Directory(p.join(directory.path, 'backups')),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'primary snapshot failure',
          ),
        ),
      );

      expect(deleteAttempts, hasLength(4));
      expect(
        deleteAttempts.any((name) => name.endsWith('.sqlite-wal')),
        isTrue,
      );
      expect(
        deleteAttempts.any((name) => name.endsWith('.sqlite-shm')),
        isTrue,
      );
      final work = Directory(p.join(directory.path, 'danggui-backup-work'));
      expect(
        await work
            .list()
            .where(
              (entry) =>
                  entry.path.endsWith('.sqlite-wal') ||
                  entry.path.endsWith('.sqlite-shm'),
            )
            .isEmpty,
        isTrue,
      );
      final audit = await harness.database
          .customSelect('SELECT status, error_code FROM backup_runs')
          .getSingle();
      expect(audit.read<String>('status'), 'failed');
      expect(audit.read<String>('error_code'), 'StateError');
    },
  );

  test('one service serializes create and merge restore', () async {
    final package = await _sourcePackage(directory);
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);
    final snapshotReached = Completer<void>();
    final releaseSnapshot = Completer<void>();
    var blockFirstSnapshot = true;
    var sourceReads = 0;
    final service = BackupService(
      readDatabase: () async => harness.database,
      readDatabaseFile: () async => harness.file,
      invalidateDatabase: () {},
      readTemporaryDirectory: () async => directory,
      readSourceBytes: (file) async {
        sourceReads++;
        return file.readAsBytes();
      },
      faultInjector: (point) async {
        if (point == BackupFaultPoint.snapshotCreated && blockFirstSnapshot) {
          blockFirstSnapshot = false;
          snapshotReached.complete();
          await releaseSnapshot.future;
        }
      },
    );

    final create = service.create(
      outputDirectory: Directory(p.join(directory.path, 'backups')),
    );
    await snapshotReached.future;
    final restore = service.restore(package, mode: RestoreMode.merge);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(sourceReads, 0);
    releaseSnapshot.complete();
    await create;
    final restored = await restore;

    expect(sourceReads, 1);
    expect(restored.mode, RestoreMode.merge);
  });

  test(
    'candidate write failure keeps its error and startup clears leftovers',
    () async {
      final package = await _sourcePackage(directory);
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);
      File? candidate;
      var deleteCalls = 0;
      final service = BackupService(
        readDatabase: () async => harness.database,
        readDatabaseFile: () async => harness.file,
        invalidateDatabase: () => harness.invalidations++,
        readTemporaryDirectory: () async => directory,
        writeRestoreCandidate: (source, destination) async {
          candidate = destination;
          await destination.writeAsString('partial candidate', flush: true);
          await File('${destination.path}-wal').writeAsString('sensitive wal');
          await File('${destination.path}-shm').writeAsString('sensitive shm');
          throw StateError('primary candidate copy failure');
        },
        deleteRestoreArtifact: (file) async {
          deleteCalls++;
          // The first four calls clear any pre-existing candidate. During
          // failure cleanup, simulate one WAL deletion failure and verify the
          // remaining artifacts are still attempted.
          if (deleteCalls == 6) {
            throw const FileSystemException('secondary cleanup failure');
          }
          if (await file.exists()) await file.delete();
        },
      );

      await expectLater(
        service.restore(package),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'primary candidate copy failure',
          ),
        ),
      );

      expect(deleteCalls, 8);
      expect(candidate, isNotNull);
      expect(await candidate!.exists(), isFalse);
      expect(await File('${candidate!.path}-shm').exists(), isFalse);
      expect(await File('${candidate!.path}-wal').exists(), isTrue);
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isFalse,
      );
      expect(harness.invalidations, 0);

      await DatabaseFileRecovery.recoverIfNeeded(harness.file);

      expect(await File('${candidate!.path}-wal').exists(), isFalse);
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

  test('merge preserves the current device alarm generation', () async {
    final package = await _sourcePackage(directory);
    final harness = await _LiveHarness.create(directory);
    addTearDown(harness.dispose);
    const generation = '88888888-8888-4888-8888-888888888888';
    await _createDeviceAlarmGeneration(harness.database, generation);

    await harness.service.restore(package, mode: RestoreMode.merge);

    expect(
      await DeviceAlarmGenerationStore(harness.database).readCurrent(),
      generation,
    );
  });

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

  test(
    'replace creates a fresh device alarm generation in the candidate',
    () async {
      final package = await _sourcePackage(directory);
      final harness = await _LiveHarness.create(directory);
      const previous = '99999999-9999-4999-8999-999999999999';
      await _createDeviceAlarmGeneration(harness.database, previous);

      await harness.service.restore(package);
      harness.databaseClosedByRestore = true;

      final replacement = DangguiDatabase.open(harness.file);
      addTearDown(replacement.close);
      final current = await DeviceAlarmGenerationStore(replacement)
          .readCurrent();
      expect(current, isNot(previous));
      expect(
        current,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );

  test('replace rebuilds search from authoritative entities', () async {
    final package = await _sourcePackage(
      directory,
      corruptSearchProjection: true,
    );
    final harness = await _LiveHarness.create(directory);

    await harness.service.restore(package);
    harness.databaseClosedByRestore = true;

    final replacement = DangguiDatabase.open(harness.file);
    addTearDown(replacement.close);
    final projection = await _searchProjection(replacement);
    expect(projection, hasLength(3));
    expect(projection.join('\n'), isNot(contains('ghost-search-record')));
    expect(
      projection,
      contains(
        'task|task-1|doc-task-1|来源事项|晚饭后开始，预计两个小时\n'
        '核对新增引用，补充理论背景。|2099-08-25',
      ),
    );
    expect(projection, contains('note|note-1|doc-note-1|来源笔记|离线笔记正文|'));
    final pastProjection = projection.singleWhere(
      (value) => value.startsWith('past|past.main|'),
    );
    expect(pastProjection, endsWith('||19:30 来源事项|2026-08-22'));
  });

  test(
    'merge rebuilds stale or missing search and remains idempotent',
    () async {
      final package = await _sourcePackage(
        directory,
        corruptSearchProjection: true,
      );
      final harness = await _LiveHarness.create(directory);
      addTearDown(harness.dispose);

      await harness.service.restore(package, mode: RestoreMode.merge);
      final first = await _searchProjection(harness.database);
      expect(first, hasLength(3));
      expect(first.join('\n'), isNot(contains('stale-source-projection')));
      expect(first.join('\n'), isNot(contains('ghost-search-record')));
      expect(
        first,
        contains(
          'task|task-1|doc-task-1|来源事项|晚饭后开始，预计两个小时\n'
          '核对新增引用，补充理论背景。|2099-08-25',
        ),
      );

      await harness.service.restore(package, mode: RestoreMode.merge);
      final second = await _searchProjection(harness.database);
      expect(second, first);
    },
  );

  test(
    'replace safety snapshot contains the final committed WAL write',
    () async {
      final package = await _sourcePackage(directory);
      late final _LiveHarness harness;
      DangguiDatabase? connectionHoldingWalOpen;
      harness = await _LiveHarness.create(
        directory,
        faultInjector: (point) async {
          if (point == BackupFaultPoint.restoreCandidatePrepared) {
            connectionHoldingWalOpen = DangguiDatabase.open(harness.file);
            await connectionHoldingWalOpen!
                .customSelect('SELECT COUNT(*) FROM tasks')
                .getSingle();
            await harness.database.customStatement(
              'PRAGMA wal_autocheckpoint = 0',
            );
            await _insertSimpleTask(
              harness.database,
              id: 'last-committed-before-close',
              title: '关闭前最后提交',
            );
            expect(await File('${harness.file.path}-wal').exists(), isTrue);
          } else if (point == BackupFaultPoint.restoreSafetySnapshotCreated) {
            await connectionHoldingWalOpen?.close();
            connectionHoldingWalOpen = null;
          }
        },
      );
      addTearDown(() async {
        await connectionHoldingWalOpen?.close();
        await harness.dispose();
      });

      final result = await harness.service.restore(package);
      harness.databaseClosedByRestore = true;

      final safety = DangguiDatabase.open(result.safetyCopy);
      addTearDown(safety.close);
      final preserved = await safety
          .customSelect(
            "SELECT title FROM tasks WHERE id = 'last-committed-before-close'",
          )
          .getSingleOrNull();
      expect(preserved?.read<String>('title'), '关闭前最后提交');
    },
  );

  test(
    'replace aborts before journal and swap while live WAL remains busy',
    () async {
      final package = await _sourcePackage(directory);
      late final _LiveHarness harness;
      DangguiDatabase? connectionHoldingWalOpen;
      Future<void>? readerTransaction;
      final readerReady = Completer<void>();
      final releaseReader = Completer<void>();
      var checkpointWasBusy = false;
      harness = await _LiveHarness.create(
        directory,
        faultInjector: (point) async {
          if (point != BackupFaultPoint.restoreCandidatePrepared) return;
          connectionHoldingWalOpen = DangguiDatabase.open(harness.file);
          readerTransaction = () async {
            await connectionHoldingWalOpen!.customStatement('BEGIN DEFERRED');
            try {
              await connectionHoldingWalOpen!
                  .customSelect('SELECT COUNT(*) FROM tasks')
                  .getSingle();
              readerReady.complete();
              await releaseReader.future;
            } finally {
              await connectionHoldingWalOpen!.customStatement('ROLLBACK');
            }
          }();
          await readerReady.future;
          await harness.database.customStatement('PRAGMA wal_autocheckpoint=0');
          await _insertSimpleTask(
            harness.database,
            id: 'must-survive-busy-checkpoint',
            title: '忙碌检查点前提交',
          );
          final checkpoint = await harness.database
              .customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
              .getSingle();
          checkpointWasBusy = checkpoint.read<int>('busy') > 0;
        },
      );
      addTearDown(() async {
        if (!releaseReader.isCompleted) releaseReader.complete();
        await readerTransaction;
        await connectionHoldingWalOpen?.close();
        await harness.dispose();
      });

      await expectLater(
        harness.service.restore(package),
        throwsA(isA<FileSystemException>()),
      );
      harness.databaseClosedByRestore = true;
      expect(checkpointWasBusy, isTrue);
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isFalse,
      );
      releaseReader.complete();
      await readerTransaction;
      await connectionHoldingWalOpen?.close();
      connectionHoldingWalOpen = null;

      final unchanged = DangguiDatabase.open(harness.file);
      addTearDown(unchanged.close);
      expect(
        await unchanged
            .customSelect(
              "SELECT COUNT(*) AS count FROM tasks "
              "WHERE id = 'must-survive-busy-checkpoint'",
            )
            .getSingle()
            .then((row) => row.read<int>('count')),
        1,
      );
      expect(
        await unchanged
            .customSelect(
              "SELECT COUNT(*) AS count FROM tasks WHERE title = '来源事项'",
            )
            .getSingle()
            .then((row) => row.read<int>('count')),
        0,
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'replace interruption before commit keeps the old live database',
    () async {
      final package = await _sourcePackage(directory);
      final activations = <String?>[];
      final harness = await _LiveHarness.create(
        directory,
        faultInjector: (point) async {
          if (point == BackupFaultPoint.restoreJournalWritten) {
            throw const FileSystemException('simulated process interruption');
          }
        },
        activateDeviceAlarmGeneration: (generation) async {
          activations.add(generation);
        },
      );
      const previous = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      await _createDeviceAlarmGeneration(harness.database, previous);

      await expectLater(
        harness.service.restore(package),
        throwsA(isA<FileSystemException>()),
      );
      harness.databaseClosedByRestore = true;
      expect(harness.invalidations, 1);
      expect(activations, hasLength(2));
      expect(activations.first, isNot(previous));
      expect(activations.last, previous);
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isTrue,
      );

      await DatabaseFileRecovery.recoverIfNeeded(harness.file);

      final recovered = DangguiDatabase.open(harness.file);
      addTearDown(recovered.close);
      expect(await _count(recovered, 'tasks'), 0);
      expect(
        await DeviceAlarmGenerationStore(recovered).readCurrent(),
        previous,
      );
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isFalse,
      );
    },
  );

  test(
    'native activation error still rolls the pre-swap generation back',
    () async {
      final package = await _sourcePackage(directory);
      final activations = <String?>[];
      final harness = await _LiveHarness.create(
        directory,
        activateDeviceAlarmGeneration: (generation) async {
          activations.add(generation);
          if (activations.length == 1) {
            throw StateError('native fence committed before cleanup failed');
          }
        },
      );
      const previous = 'abababab-abab-4aba-8aba-abababababab';
      await _createDeviceAlarmGeneration(harness.database, previous);

      await expectLater(
        harness.service.restore(package),
        throwsA(isA<StateError>()),
      );
      harness.databaseClosedByRestore = true;

      expect(activations, hasLength(2));
      expect(activations.first, isNot(previous));
      expect(activations.last, previous);
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isFalse,
      );
      final recovered = DangguiDatabase.open(harness.file);
      addTearDown(recovered.close);
      expect(await _count(recovered, 'tasks'), 0);
      expect(
        await DeviceAlarmGenerationStore(recovered).readCurrent(),
        previous,
      );
    },
  );

  test(
    'replace interruption after commit keeps the replacement database',
    () async {
      final package = await _sourcePackage(directory);
      final activations = <String?>[];
      final harness = await _LiveHarness.create(
        directory,
        faultInjector: (point) async {
          if (point == BackupFaultPoint.restoreSwapCommitted) {
            throw const FileSystemException('simulated process interruption');
          }
        },
        activateDeviceAlarmGeneration: (generation) async {
          activations.add(generation);
        },
      );
      const previous = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      await _createDeviceAlarmGeneration(harness.database, previous);

      await expectLater(
        harness.service.restore(package),
        throwsA(isA<FileSystemException>()),
      );
      harness.databaseClosedByRestore = true;
      expect(harness.invalidations, 1);
      expect(activations, hasLength(1));
      expect(activations.single, isNot(previous));
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isTrue,
      );

      await DatabaseFileRecovery.recoverIfNeeded(harness.file);

      final recovered = DangguiDatabase.open(harness.file);
      addTearDown(recovered.close);
      expect(await _count(recovered, 'tasks'), 1);
      final task = await recovered
          .customSelect('SELECT title FROM tasks')
          .getSingle();
      expect(task.read<String>('title'), '来源事项');
      expect(
        await DeviceAlarmGenerationStore(recovered).readCurrent(),
        activations.single,
      );
      expect(
        await DatabaseFileRecovery.journalFile(harness.file).exists(),
        isFalse,
      );
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

Future<String> _createDeviceAlarmGeneration(
  DangguiDatabase database,
  String generation,
) {
  return DeviceAlarmGenerationStore(database).createForReplacement(
    operationId: generation,
    sourceName: 'local-generation.dgbak',
    sourceSha256: List<String>.filled(64, 'd').join(),
    sourceSchemaVersion: 1,
    encrypted: false,
    safetyCopyName: 'local-generation.sqlite',
    completedAtUtc: 1,
  );
}

final class _LiveHarness {
  _LiveHarness(
    this.file,
    this.database, {
    Future<void> Function(BackupFaultPoint point)? faultInjector,
    Future<void> Function(String? generation)? activateDeviceAlarmGeneration,
  }) {
    service = BackupService(
      readDatabase: () async => database,
      readDatabaseFile: () async => file,
      invalidateDatabase: () => invalidations++,
      faultInjector: faultInjector,
      activateDeviceAlarmGeneration: activateDeviceAlarmGeneration,
      readTemporaryDirectory: () async => file.parent,
    );
  }

  static Future<_LiveHarness> create(
    Directory directory, {
    Future<void> Function(BackupFaultPoint point)? faultInjector,
    Future<void> Function(String? generation)? activateDeviceAlarmGeneration,
  }) async {
    final file = File(p.join(directory.path, 'live.sqlite'));
    final database = DangguiDatabase.open(file);
    await database.customSelect('SELECT 1').get();
    return _LiveHarness(
      file,
      database,
      faultInjector: faultInjector,
      activateDeviceAlarmGeneration: activateDeviceAlarmGeneration,
    );
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
  bool corruptSearchProjection = false,
  bool integrityOnlyCorruption = false,
  Future<void> Function(DangguiDatabase database)? mutateSchema,
}) async {
  final sourceFile = File(p.join(directory.path, 'source.sqlite'));
  final database = DangguiDatabase.open(sourceFile);
  await database.customSelect('SELECT 1').get();
  await _populateSource(database, reminderExpired: reminderExpired);
  if (corruptSearchProjection) {
    await database.transaction(() async {
      // Keep the note authoritative and live so the test covers rebuilding a
      // projection that is entirely absent, not just removal of a ghost row.
      await database.customStatement(
        "UPDATE notes SET deleted_at_utc = NULL WHERE id = 'note-1'",
      );
      await database.customStatement(
        "DELETE FROM trash_entries WHERE entity_type = 'note' "
        "AND entity_id = 'note-1'",
      );
      await database.customStatement('DELETE FROM search_records');
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      await database.customStatement(
        'INSERT INTO search_records '
        '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
        'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'task',
          'task-1',
          'doc-task-1',
          'stale-source-projection',
          'stale-source-projection',
          '1900-01-01',
          now,
        ],
      );
      await database.customStatement(
        'INSERT INTO search_records '
        '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
        'updated_at_utc) VALUES (?, ?, NULL, ?, ?, ?, ?)',
        <Object?>[
          'note',
          'ghost-search-record',
          'ghost-search-record',
          'ghost-search-record',
          '',
          now,
        ],
      );
    });
  }
  await mutateSchema?.call(database);
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
  if (integrityOnlyCorruption) {
    await corruptDatabaseSoQuickPassesButIntegrityFails(sourceFile);
  }
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

Future<List<FileSystemEntity>> _restoreValidationArtifacts(
  Directory temporaryRoot,
) async {
  final validationDirectory = Directory(
    p.join(temporaryRoot.path, 'danggui-restore-validation'),
  );
  if (!await validationDirectory.exists()) return const <FileSystemEntity>[];
  return validationDirectory.list().toList();
}

Future<List<String>> _searchProjection(DangguiDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT scope, entity_id, document_id, title_norm, body_norm, date_key '
        'FROM search_records ORDER BY scope, entity_id',
      )
      .get();
  return rows
      .map(
        (row) => <Object?>[
          row.read<String>('scope'),
          row.read<String>('entity_id'),
          row.readNullable<String>('document_id') ?? '',
          row.read<String>('title_norm'),
          row.read<String>('body_norm'),
          row.read<String>('date_key'),
        ].join('|'),
      )
      .toList(growable: false);
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

Future<void> _insertSimpleTask(
  DangguiDatabase database, {
  required String id,
  required String title,
}) async {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  await database.transaction(() async {
    await database.customStatement(
      'INSERT INTO documents '
      '(id, kind, singleton_key, format_version, revision, semantic_hash, '
      'created_at_utc, updated_at_utc, row_version) '
      'VALUES (?, ?, NULL, 1, 0, ?, ?, ?, 1)',
      <Object?>['doc-$id', 'taskBody', _hash('d$id'), now, now],
    );
    await database.customStatement(
      'INSERT INTO tasks '
      '(id, document_id, title, due_local_date, plan_text, status, manual_rank, '
      'closed_at_utc, closed_local_date, closed_local_time, closed_zone_id, '
      'archived_at_utc, deleted_at_utc, semantic_hash, created_at_utc, '
      'updated_at_utc, row_version) '
      'VALUES (?, ?, ?, NULL, ?, ?, 1, NULL, NULL, NULL, NULL, NULL, NULL, '
      '?, ?, ?, 1)',
      <Object?>[id, 'doc-$id', title, '', 'active', _hash('t$id'), now, now],
    );
  });
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
