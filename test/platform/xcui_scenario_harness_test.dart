import 'dart:io';

import 'package:danggui/src/data/database_provider.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:danggui/src/testing/xcui_scenario_harness.dart';
import 'package:danggui/xcui_main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('dedicated entrypoint exposes only fixed scenario selectors', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await tester.pumpWidget(
      DangguiXcuiScenarioSelectorApp(
        onSelected: (scenario) => selected = scenario,
      ),
    );

    const taskSelector = ValueKey<String>(
      'xcui-scenario-task-reminder-trash-restore',
    );
    const backupSelector = ValueKey<String>(
      'xcui-scenario-backup-restore-reminder-rebuild',
    );
    expect(find.byType(FilledButton), findsNWidgets(2));
    expect(find.byKey(taskSelector), findsOneWidget);
    expect(find.byKey(backupSelector), findsOneWidget);
    expect(find.textContaining('not-allow-listed'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(taskSelector)),
      matchesSemantics(
        identifier: 'xcui-scenario-task-reminder-trash-restore',
        label: 'Run task-reminder-trash-restore',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.bySemanticsIdentifier(
        'xcui-scenario-backup-restore-reminder-rebuild',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(taskSelector));
    expect(selected, 'task-reminder-trash-restore');
    final backupSemantics = find.semantics.byPredicate(
      (node) =>
          node.identifier == 'xcui-scenario-backup-restore-reminder-rebuild',
    );
    expect(backupSemantics, findsOne);
    tester.semantics.tap(backupSemantics);
    await tester.pump();
    expect(selected, 'backup-restore-reminder-rebuild');
    semantics.dispose();
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
