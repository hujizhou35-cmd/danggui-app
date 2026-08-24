import 'package:danggui/main.dart' as app;
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/release_acceptance_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed production services for same-version overlay acceptance', (
    tester,
  ) async {
    final apiLevel = releaseAcceptanceApiLevel();
    final title = releaseAcceptanceTitle(apiLevel);

    app.main();
    await waitForFinder(
      tester,
      find.byType(TasksPage),
      phase: 'production seed cold start',
    );
    final container = providerContainerFor(tester, find.byType(TasksPage));
    final database = await container.read(databaseProvider.future);
    final controller = container.read(appStoreProvider.notifier);
    await controller.saveSettings(
      const AppSettingsModel(
        localeMode: LocaleMode.en,
        fontMode: FontMode.serif,
        textScalePercent: 110,
        density: DisplayDensity.compact,
        defaultSoundEnabled: false,
        defaultVibrationEnabled: false,
        defaultSnoozeMinutes: 30,
        autoBackupEnabled: false,
        autoBackupHourLocal: 3,
        autoBackupMinuteLocal: 17,
        backupEncryptionEnabled: false,
        helpSeenVersion: 7,
      ),
    );
    final coordinator = container.read(notificationCoordinatorProvider);
    await coordinator.initialize();
    final initialPermission = await coordinator.permissionsGranted();
    final authorization = await coordinator
        .ensurePermissionsForFutureReminder();
    final notificationsGranted = authorization.notificationsGranted;
    if (apiLevel >= 33) {
      expect(
        initialPermission,
        isFalse,
        reason: 'API $apiLevel must begin from a denied fresh-install state.',
      );
    }
    expect(
      notificationsGranted,
      isTrue,
      reason: apiLevel >= 33
          ? 'API $apiLevel must complete the app-initiated POST_NOTIFICATIONS permission flow.'
          : 'API $apiLevel must support ordinary notifications without a runtime prompt.',
    );
    expect(
      authorization.exactSchedulingAvailable,
      isTrue,
      reason:
          'API $apiLevel acceptance must run with exact reminder scheduling available.',
    );

    final folderId = await controller.createFolder(
      releaseAcceptanceFolderName(apiLevel),
    );
    final noteId = await controller.createNote(
      title: releaseAcceptanceNoteTitle(apiLevel),
      body: releaseAcceptanceNoteBody(apiLevel),
      folderId: folderId,
    );
    final pastTaskId = await controller.createTask(
      title: releaseAcceptancePastTitle(apiLevel),
      dueDate: DateTime.now(),
      plan: 'Past plan sentinel API $apiLevel',
      body: releaseAcceptancePastBody(apiLevel),
    );
    await controller.setTaskActive(pastTaskId, false);
    await controller.addTaskToPast(pastTaskId);

    final reminderAt = DateTime.now().add(releaseAcceptanceReminderLead);
    final taskId = await controller.createTask(
      title: title,
      dueDate: DateTime(reminderAt.year, reminderAt.month, reminderAt.day),
      plan: releaseAcceptancePlan(apiLevel),
      body: releaseAcceptanceBody(apiLevel),
      reminderAt: reminderAt,
      soundEnabled: true,
      vibrationEnabled: true,
    );
    await coordinator.reconcile();
    await waitForNotificationRegistration(database, taskId);
    await tester.pump();
    await waitForFinder(
      tester,
      find.text(title),
      phase: 'seeded task card',
      timeout: const Duration(seconds: 20),
    );
    final cardScheduleLabel = assertReleaseAcceptanceCard(tester, title: title);

    final snapshot = await databaseSnapshot(
      database,
      taskId: taskId,
      noteId: noteId,
      pastTaskId: pastTaskId,
      notificationsGranted: notificationsGranted,
    );
    expect(snapshot['quickCheck'], <String>['ok']);
    expect(snapshot['foreignKeyCheck'], isEmpty);
    expect(snapshot['nonSucceededPlatformJobCount'], 0);
    final task = snapshot['task']! as Map<String, Object?>;
    expect(task['reminderStatus'], 'scheduled');
    expect(snapshot['notificationRegistration'], isNotNull);
    final note = snapshot['note']! as Map<String, Object?>;
    final folder = snapshot['folder']! as Map<String, Object?>;
    final past = snapshot['past']! as Map<String, Object?>;
    final settings = snapshot['settings']! as Map<String, Object?>;
    expect(note['title'], releaseAcceptanceNoteTitle(apiLevel));
    expect(note['folderId'], folderId);
    expect(folder['name'], releaseAcceptanceFolderName(apiLevel));
    expect(
      (note['blocks']! as List<Object?>).toString(),
      contains(releaseAcceptanceNoteBody(apiLevel)),
    );
    expect(past['sourceTaskId'], pastTaskId);
    expect(
      (past['documentBlocks']! as List<Object?>).toString(),
      contains(releaseAcceptancePastTitle(apiLevel)),
    );
    expect(settings['localeMode'], LocaleMode.en.name);
    expect(settings['defaultSnoozeMinutes'], 30);

    await writeReleaseAcceptanceEvidence('before.json', <String, Object?>{
      'contractVersion': releaseAcceptanceContractVersion,
      'phase': 'before-overlay-install',
      'apiLevel': apiLevel,
      'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'scope': <String, Object?>{
        'productionEntrypoint': true,
        'runtimeNotificationPermissionRequestedByApp': apiLevel >= 33,
        'sameVersionSignedOverlayOnly': true,
        'schemaMigrationClaimed': false,
        'physicalDeviceHapticsOrOemClaimed': false,
        'crossDomainSentinels': <String>[
          'task',
          'reminder',
          'note',
          'folder',
          'past',
          'settings',
        ],
      },
      ...snapshot,
      'ui': <String, Object?>{
        'taskCardFound': true,
        'cardScheduleLabel': cardScheduleLabel,
        'reminderTextVisible': true,
      },
      'expectedSystemNotification': <String, Object?>{
        'title': title,
        'body': releaseAcceptancePlan(apiLevel),
      },
    });
    await database.customStatement('PRAGMA wal_checkpoint(FULL)');
  });
}
