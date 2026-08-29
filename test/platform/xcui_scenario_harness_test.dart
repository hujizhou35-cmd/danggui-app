import 'dart:io';

import 'package:danggui/src/data/database_provider.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:danggui/src/testing/xcui_scenario_harness.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('XCUITest scenario launch contract', () {
    test('accepts one explicit process argument', () {
      expect(
        dangguiXcuiScenarioFromArguments(const <String>[
          '-AppleLanguages',
          '(en)',
          '--danggui-xcui-scenario=task-reminder-trash-restore',
          '-AppleLocale',
          'en_US',
        ]),
        'task-reminder-trash-restore',
      );
    });

    test('rejects missing, empty, and duplicate selectors', () {
      expect(dangguiXcuiScenarioFromArguments(const <String>[]), isNull);
      expect(
        dangguiXcuiScenarioFromArguments(const <String>[
          '--danggui-xcui-scenario=',
        ]),
        isNull,
      );
      expect(
        dangguiXcuiScenarioFromArguments(const <String>[
          '--danggui-xcui-scenario=task-reminder-trash-restore',
          '--danggui-xcui-scenario=backup-restore-reminder-rebuild',
        ]),
        isNull,
      );
    });
  });

  group('XCUITest scenario storage', () {
    late Directory testRoot;

    setUp(() async {
      testRoot = await Directory.systemTemp.createTemp(
        'danggui-xcui-storage-test-',
      );
    });

    tearDown(() async {
      if (await testRoot.exists()) {
        await testRoot.delete(recursive: true);
      }
    });

    test('maps supported scenarios to separate bounded directories', () {
      final taskWorkspace = XcuiScenarioWorkspace.forScenario(
        'task-reminder-trash-restore',
        temporaryRoot: testRoot,
      );
      final backupWorkspace = XcuiScenarioWorkspace.forScenario(
        'backup-restore-reminder-rebuild',
        temporaryRoot: testRoot,
      );

      expect(
        p.equals(
          taskWorkspace.rootDirectory.path,
          backupWorkspace.rootDirectory.path,
        ),
        isFalse,
      );
      expect(
        p.isWithin(
          taskWorkspace.suiteDirectory.path,
          taskWorkspace.databaseFile.path,
        ),
        isTrue,
      );
      expect(
        p.isWithin(
          backupWorkspace.suiteDirectory.path,
          backupWorkspace.databaseFile.path,
        ),
        isTrue,
      );
      expect(
        () => XcuiScenarioWorkspace.forScenario(
          '../outside',
          temporaryRoot: testRoot,
        ),
        throwsArgumentError,
      );
    });

    test(
      'provider startup removes only its database, sidecars and temp data',
      () async {
        final taskWorkspace = XcuiScenarioWorkspace.forScenario(
          'task-reminder-trash-restore',
          temporaryRoot: testRoot,
        );
        final backupWorkspace = XcuiScenarioWorkspace.forScenario(
          'backup-restore-reminder-rebuild',
          temporaryRoot: testRoot,
        );
        await taskWorkspace.databaseFile.parent.create(recursive: true);
        for (final artifact in taskWorkspace.databaseAndSidecars) {
          await artifact.writeAsString('stale');
        }
        await taskWorkspace.temporaryDirectory.create(recursive: true);
        final staleBackup = File(
          p.join(taskWorkspace.temporaryDirectory.path, 'stale.dgbak'),
        );
        await staleBackup.writeAsString('stale');

        await backupWorkspace.rootDirectory.create(recursive: true);
        final otherScenarioSentinel = File(
          p.join(backupWorkspace.rootDirectory.path, 'keep.txt'),
        );
        await otherScenarioSentinel.writeAsString('keep');
        final outsideSentinel = File(p.join(testRoot.path, 'keep.txt'));
        await outsideSentinel.writeAsString('keep');

        final container = ProviderContainer(
          overrides: dangguiXcuiScenarioStorageOverrides(taskWorkspace),
        );
        addTearDown(container.dispose);
        final selectedFile = await container.read(databaseFileProvider.future);

        expect(
          p.equals(selectedFile.path, taskWorkspace.databaseFile.path),
          isTrue,
        );
        for (final artifact in taskWorkspace.databaseAndSidecars) {
          expect(await artifact.exists(), isFalse, reason: artifact.path);
        }
        expect(await staleBackup.exists(), isFalse);
        expect(await taskWorkspace.databaseFile.parent.exists(), isTrue);
        expect(await taskWorkspace.temporaryDirectory.exists(), isTrue);
        expect(await otherScenarioSentinel.readAsString(), 'keep');
        expect(await outsideSentinel.readAsString(), 'keep');

        await selectedFile.writeAsString('live-database');
        container.invalidate(databaseFileProvider);
        final reopenedFile = await container.read(databaseFileProvider.future);
        expect(p.equals(reopenedFile.path, selectedFile.path), isTrue);
        expect(await reopenedFile.readAsString(), 'live-database');

        final backupService = container.read(backupServiceProvider);
        final backupTemporaryDirectory = await backupService
            .readTemporaryDirectory();
        expect(
          p.equals(
            backupTemporaryDirectory.path,
            taskWorkspace.temporaryDirectory.path,
          ),
          isTrue,
        );
      },
    );

    test('rejects a symlinked suite instead of deleting through it', () async {
      if (Platform.isWindows) {
        // Creating symlinks on Windows requires a policy-dependent privilege;
        // the provider cleanup contract is still covered above on Windows.
        return;
      }
      final workspace = XcuiScenarioWorkspace.forScenario(
        'task-reminder-trash-restore',
        temporaryRoot: testRoot,
      );
      final external = await Directory.systemTemp.createTemp(
        'danggui-xcui-external-',
      );
      addTearDown(() async {
        if (await external.exists()) await external.delete(recursive: true);
      });
      await workspace.suiteDirectory.parent.create(recursive: true);
      await Link(workspace.suiteDirectory.path).create(external.path);

      await expectLater(workspace.reset(), throwsStateError);
    });
  });
}
