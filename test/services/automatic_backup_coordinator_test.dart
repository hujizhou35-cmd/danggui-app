import 'dart:async';
import 'dart:io';

import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/services/backup/automatic_backup_coordinator.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dailyDirectory;
  late _Harness harness;

  setUp(() async {
    dailyDirectory = await Directory.systemTemp.createTemp(
      'danggui-auto-backup-test-',
    );
    harness = _Harness(
      directory: dailyDirectory,
      now: DateTime(2026, 8, 22, 1),
    );
  });

  tearDown(() async {
    if (await dailyDirectory.exists()) {
      await dailyDirectory.delete(recursive: true);
    }
  });

  test(
    'first observation before local schedule does not invent yesterday',
    () async {
      final coordinator = harness.coordinator();

      final before = await coordinator.onStartup();

      expect(before.status, AutomaticBackupStatus.notDue);
      expect(before.coveredLocalDate, isNull);
      expect(harness.createCalls, 0);

      harness.now = DateTime(2026, 8, 22, 2, 1);
      final after = await coordinator.onForeground();
      expect(after.status, AutomaticBackupStatus.created);
      expect(after.coveredLocalDate, '2026-08-22');
      expect(harness.createCalls, 1);

      final repeated = await coordinator.onForeground();
      expect(repeated.status, AutomaticBackupStatus.alreadyCompleted);
      expect(harness.createCalls, 1);
    },
  );

  test('startup catches up a missed date then permits the new date', () async {
    final coordinator = harness.coordinator();
    expect(
      (await coordinator.onStartup()).status,
      AutomaticBackupStatus.notDue,
    );

    harness.now = DateTime(2026, 8, 23, 1);
    final catchUp = await coordinator.onStartup();
    expect(catchUp.status, AutomaticBackupStatus.created);
    expect(catchUp.coveredLocalDate, '2026-08-22');

    final restarted = harness.coordinator();
    final duplicate = await restarted.onForeground();
    expect(duplicate.status, AutomaticBackupStatus.alreadyCompleted);
    expect(harness.createCalls, 1);

    harness.now = DateTime(2026, 8, 23, 2, 1);
    final today = await restarted.onForeground();
    expect(today.status, AutomaticBackupStatus.created);
    expect(today.coveredLocalDate, '2026-08-23');
    expect(harness.createCalls, 2);
  });

  test(
    'concurrent startup and foreground checks share one operation',
    () async {
      harness.now = DateTime(2026, 8, 22, 3);
      harness.pauseCreation = Completer<void>();
      final coordinator = harness.coordinator();

      final startup = coordinator.onStartup();
      await harness.creationStarted.future;
      final foreground = coordinator.onForeground();
      expect(harness.createCalls, 1);

      harness.pauseCreation!.complete();
      final results = await Future.wait(<Future<AutomaticBackupResult>>[
        startup,
        foreground,
      ]);
      expect(
        results.map((result) => result.status),
        everyElement(AutomaticBackupStatus.created),
      );
      expect(results.first.trigger, AutomaticBackupTrigger.startup);
      expect(results.last.trigger, AutomaticBackupTrigger.startup);
      expect(harness.createCalls, 1);
    },
  );

  test('missing secure passphrase explicitly skips encrypted backup', () async {
    harness
      ..now = DateTime(2026, 8, 22, 3)
      ..settings = const AppSettingsModel(
        autoBackupEnabled: true,
        autoBackupHourLocal: 2,
        autoBackupMinuteLocal: 0,
        backupEncryptionEnabled: true,
      );
    final coordinator = harness.coordinator();

    final skipped = await coordinator.onStartup();

    expect(
      skipped.status,
      AutomaticBackupStatus.skippedMissingEncryptionPassphrase,
    );
    expect(harness.createCalls, 0);
    expect(await _dailyBackups(dailyDirectory), isEmpty);

    harness.passphrase = 'stored-password';
    final created = await coordinator.onForeground();
    expect(created.status, AutomaticBackupStatus.created);
    expect(harness.lastPassphrase, 'stored-password');
    expect(created.backup!.encrypted, isTrue);
  });

  test(
    're-enabling before schedule does not catch up disabled dates',
    () async {
      harness
        ..now = DateTime(2026, 8, 25, 10)
        ..settings = const AppSettingsModel(autoBackupEnabled: false);
      final coordinator = harness.coordinator();
      expect(
        (await coordinator.onStartup()).status,
        AutomaticBackupStatus.disabled,
      );

      harness
        ..now = DateTime(2026, 8, 26, 1)
        ..settings = const AppSettingsModel(
          autoBackupEnabled: true,
          autoBackupHourLocal: 2,
        );
      final enabled = await coordinator.onForeground();
      expect(enabled.status, AutomaticBackupStatus.notDue);
      expect(harness.createCalls, 0);
    },
  );

  test(
    'daily directory retains only newest 30 matching backup files',
    () async {
      final parentBackup = File(
        p.join(dailyDirectory.parent.path, 'danggui-parent.dgbak'),
      );
      await parentBackup.writeAsBytes(<int>[1]);
      final nested = Directory(p.join(dailyDirectory.path, 'nested'));
      await nested.create();
      final nestedBackup = File(p.join(nested.path, 'danggui-nested.dgbak'));
      await nestedBackup.writeAsBytes(<int>[1]);
      final unrelated = File(
        p.join(dailyDirectory.path, 'manual-export.dgbak'),
      );
      await unrelated.writeAsBytes(<int>[1]);
      for (var index = 0; index < 35; index++) {
        final file = File(
          p.join(
            dailyDirectory.path,
            'danggui-old-${index.toString().padLeft(2, '0')}.dgbak',
          ),
        );
        await file.writeAsBytes(<int>[index]);
        await file.setLastModified(
          DateTime(2020, 1, 1).add(Duration(days: index)),
        );
      }
      harness.now = DateTime(2026, 8, 22, 3);

      final result = await harness.coordinator().onStartup();

      expect(result.status, AutomaticBackupStatus.created);
      expect(result.retentionCompleted, isTrue);
      expect(result.removedOldBackups, 6);
      expect(await _dailyBackups(dailyDirectory), hasLength(30));
      expect(await parentBackup.exists(), isTrue);
      expect(await nestedBackup.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test('failed creation does not advance the covered date', () async {
    harness
      ..now = DateTime(2026, 8, 22, 3)
      ..failNextCreation = true;
    final coordinator = harness.coordinator();

    await expectLater(
      coordinator.onStartup(),
      throwsA(isA<FileSystemException>()),
    );
    expect(harness.createCalls, 1);

    final retried = await coordinator.onForeground();
    expect(retried.status, AutomaticBackupStatus.created);
    expect(retried.coveredLocalDate, '2026-08-22');
    expect(harness.createCalls, 2);
  });
}

final class _Harness {
  _Harness({required this.directory, required this.now});

  final Directory directory;
  DateTime now;
  AppSettingsModel settings = const AppSettingsModel(
    autoBackupEnabled: true,
    autoBackupHourLocal: 2,
    autoBackupMinuteLocal: 0,
  );
  String? passphrase;
  String? lastPassphrase;
  String? lastKind;
  Directory? lastOutputDirectory;
  int createCalls = 0;
  bool failNextCreation = false;
  Completer<void>? pauseCreation;
  Completer<void> creationStarted = Completer<void>();

  AutomaticBackupCoordinator coordinator() => AutomaticBackupCoordinator(
    clock: () => now,
    readSettings: () async => settings,
    readPassphrase: () async => passphrase,
    readDirectory: () async => directory,
    createBackup: _create,
  );

  Future<BackupExport> _create({
    required String? passphrase,
    required String kind,
    required Directory outputDirectory,
  }) async {
    createCalls++;
    lastPassphrase = passphrase;
    lastKind = kind;
    lastOutputDirectory = outputDirectory;
    if (!creationStarted.isCompleted) creationStarted.complete();
    final pause = pauseCreation;
    if (pause != null) await pause.future;
    if (failNextCreation) {
      failNextCreation = false;
      throw const FileSystemException('simulated failure');
    }
    expect(kind, 'daily');
    expect(outputDirectory.path, directory.path);
    final file = File(
      p.join(outputDirectory.path, 'danggui-test-$createCalls.dgbak'),
    );
    await file.writeAsBytes(<int>[createCalls], flush: true);
    return BackupExport(
      file: file,
      manifest: <String, Object?>{'kind': kind},
      encrypted: passphrase != null,
    );
  }
}

Future<List<File>> _dailyBackups(Directory directory) async {
  final result = <File>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name.startsWith('danggui-') && name.endsWith('.dgbak')) {
      result.add(entity);
    }
  }
  return result;
}
