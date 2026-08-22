import 'package:danggui/main.dart' as app;
import 'package:danggui/src/application/app_store.dart';
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
    final coordinator = container.read(notificationCoordinatorProvider);
    await coordinator.initialize();
    final initialPermission = await coordinator.permissionsGranted();
    final notificationsGranted = apiLevel >= 33
        ? await coordinator.ensurePermissionsForFutureReminder()
        : initialPermission;
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

    final reminderAt = DateTime.now().add(releaseAcceptanceReminderLead);
    final taskId = await container
        .read(appStoreProvider.notifier)
        .createTask(
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
      notificationsGranted: notificationsGranted!,
    );
    expect(snapshot['quickCheck'], <String>['ok']);
    expect(snapshot['foreignKeyCheck'], isEmpty);
    expect(snapshot['nonSucceededPlatformJobCount'], 0);
    final task = snapshot['task']! as Map<String, Object?>;
    expect(task['reminderStatus'], 'scheduled');
    expect(snapshot['notificationRegistration'], isNotNull);

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
