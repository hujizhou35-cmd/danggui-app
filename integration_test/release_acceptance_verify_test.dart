import 'dart:convert';

import 'package:danggui/main.dart' as app;
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/release_acceptance_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify retained database and reminder card after overlay', (
    tester,
  ) async {
    final apiLevel = releaseAcceptanceApiLevel();
    app.main();
    final before = await readReleaseAcceptanceEvidence('before.json');
    expect(before['contractVersion'], releaseAcceptanceContractVersion);
    expect(before['phase'], 'before-overlay-install');
    expect(before['apiLevel'], apiLevel);
    final beforeTask = before['task']! as Map<String, Object?>;
    final taskId = beforeTask['id']! as String;
    final title = beforeTask['title']! as String;
    final beforeRegistration =
        before['notificationRegistration']! as Map<String, Object?>;
    final beforeNote = before['note']! as Map<String, Object?>;
    final beforePast = before['past']! as Map<String, Object?>;
    final noteId = beforeNote['id']! as String;
    final pastTaskId = beforePast['sourceTaskId']! as String;

    await waitForFinder(
      tester,
      find.byType(TasksPage),
      phase: 'post-overlay production cold start',
    );
    final container = providerContainerFor(tester, find.byType(TasksPage));
    final database = await container.read(databaseProvider.future);
    final coordinator = container.read(notificationCoordinatorProvider);
    await coordinator.initialize();
    final notificationsGranted = await coordinator.permissionsGranted();
    await coordinator.reconcile();
    await waitForNotificationRegistration(database, taskId);
    await tester.pump();
    await waitForFinder(
      tester,
      find.text(title),
      phase: 'retained task card',
      timeout: const Duration(seconds: 20),
    );
    final cardScheduleLabel = assertReleaseAcceptanceCard(tester, title: title);
    final snapshot = await databaseSnapshot(
      database,
      taskId: taskId,
      noteId: noteId,
      pastTaskId: pastTaskId,
      notificationsGranted: notificationsGranted == true,
    );
    final afterTask = snapshot['task']! as Map<String, Object?>;
    final afterRegistration =
        snapshot['notificationRegistration'] as Map<String, Object?>?;
    final beforeUi = before['ui']! as Map<String, Object?>;

    final assertions = <String, bool>{
      'datasetIdRetained': snapshot['datasetId'] == before['datasetId'],
      'schemaVersionRetained':
          snapshot['databaseSchemaVersion'] == before['databaseSchemaVersion'],
      'sqliteUserVersionRetained':
          snapshot['sqliteUserVersion'] == before['sqliteUserVersion'],
      'taskIdRetained': afterTask['id'] == beforeTask['id'],
      'documentIdRetained': afterTask['documentId'] == beforeTask['documentId'],
      'taskTitleRetained': afterTask['title'] == beforeTask['title'],
      'taskPlanRetained': afterTask['planText'] == beforeTask['planText'],
      'taskBodyRetained': afterTask['bodyText'] == beforeTask['bodyText'],
      'taskStatusRetained': afterTask['status'] == beforeTask['status'],
      'taskSemanticHashRetained':
          afterTask['semanticHash'] == beforeTask['semanticHash'],
      'taskCreatedAtRetained':
          afterTask['createdAtUtcMicros'] == beforeTask['createdAtUtcMicros'],
      'taskUpdatedAtRetained':
          afterTask['updatedAtUtcMicros'] == beforeTask['updatedAtUtcMicros'],
      'taskRowVersionRetained':
          afterTask['rowVersion'] == beforeTask['rowVersion'],
      'taskManualRankRetained':
          afterTask['manualRank'] == beforeTask['manualRank'],
      'taskDueDateRetained':
          afterTask['dueLocalDate'] == beforeTask['dueLocalDate'],
      'reminderIdRetained': afterTask['reminderId'] == beforeTask['reminderId'],
      'reminderInstantRetained':
          afterTask['reminderScheduledAtUtcMicros'] ==
          beforeTask['reminderScheduledAtUtcMicros'],
      'reminderLocalTimeRetained':
          afterTask['reminderScheduledLocalDateTime'] ==
          beforeTask['reminderScheduledLocalDateTime'],
      'reminderZoneRetained':
          afterTask['reminderScheduledZoneId'] ==
          beforeTask['reminderScheduledZoneId'],
      'reminderSoundRetained':
          afterTask['soundEnabled'] == beforeTask['soundEnabled'],
      'reminderVibrationRetained':
          afterTask['vibrationEnabled'] == beforeTask['vibrationEnabled'],
      'reminderRevisionRetained':
          afterTask['reminderScheduleRevision'] ==
          beforeTask['reminderScheduleRevision'],
      'reminderStatusScheduled': afterTask['reminderStatus'] == 'scheduled',
      'recordCountsRetained':
          jsonEncode(snapshot['counts']) == jsonEncode(before['counts']),
      'notificationPermissionGranted': notificationsGranted == true,
      'notificationRegistrationPresent': afterRegistration != null,
      'platformNotificationIdRetained':
          afterRegistration?['platformNotificationId'] ==
          beforeRegistration['platformNotificationId'],
      'notificationRegistrationRevisionRetained':
          afterRegistration?['scheduleRevision'] ==
          beforeRegistration['scheduleRevision'],
      'notificationRegistrationRetained':
          jsonEncode(afterRegistration) == jsonEncode(beforeRegistration),
      'noteRetained':
          jsonEncode(snapshot['note']) == jsonEncode(before['note']),
      'folderRetained':
          jsonEncode(snapshot['folder']) == jsonEncode(before['folder']),
      'pastRetained':
          jsonEncode(snapshot['past']) == jsonEncode(before['past']),
      'settingsRetained':
          jsonEncode(snapshot['settings']) == jsonEncode(before['settings']),
      'platformOutboxSucceeded': snapshot['nonSucceededPlatformJobCount'] == 0,
      'quickCheckOk': _isQuickCheckOk(snapshot['quickCheck']),
      'foreignKeysOk': (snapshot['foreignKeyCheck']! as List<Object?>).isEmpty,
      'taskCardReminderTextRetained':
          cardScheduleLabel == beforeUi['cardScheduleLabel'],
    };

    await writeReleaseAcceptanceEvidence('after.json', <String, Object?>{
      'contractVersion': releaseAcceptanceContractVersion,
      'phase': 'after-overlay-install',
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
      'retentionAssertions': assertions,
    });
    await database.customStatement('PRAGMA wal_checkpoint(FULL)');

    expect(
      assertions.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key),
      isEmpty,
      reason: 'Every same-version overlay retention assertion must pass.',
    );
    await waitForReleaseAcceptanceHostSignal();
  });
}

bool _isQuickCheckOk(Object? value) {
  return value is List<Object?> &&
      value.length == 1 &&
      value.single.toString().toLowerCase() == 'ok';
}
