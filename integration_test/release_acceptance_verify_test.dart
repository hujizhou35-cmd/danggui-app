import 'dart:convert';

import 'package:danggui/main.dart' as app;
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:drift/drift.dart';
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

    // The host has now observed the real scheduled notification and captured
    // the shade. Exercise the exact action ids delivered by the native plugin
    // callback without using brittle coordinate-based SystemUI taps. This
    // still uses the production database, coordinator and native gateway, so a
    // successful return includes durable mutation and platform rescheduling.
    final snoozeActions = <Map<String, Object?>>[];
    var previous = await _readSnoozeState(database, taskId);
    for (final minutes in <int>[10, 30, 60]) {
      final callStarted = DateTime.now().toUtc();
      final handled = await coordinator.handleNotificationAction(
        'danggui.snooze.$minutes',
        'task:$taskId',
      );
      final callCompleted = DateTime.now().toUtc();
      final current = await _waitForSnoozeState(
        database,
        coordinator,
        taskId,
        expectedSnoozeCount: (previous['snoozeCount']! as int) + 1,
        expectedRevision: (previous['scheduleRevision']! as int) + 1,
      );
      final scheduledAt = DateTime.fromMicrosecondsSinceEpoch(
        current['scheduledAtUtcMicros']! as int,
        isUtc: true,
      );
      final earliest = callStarted
          .add(Duration(minutes: minutes))
          .subtract(const Duration(seconds: 2));
      final latest = callCompleted
          .add(Duration(minutes: minutes))
          .add(const Duration(seconds: 2));
      final assertions = <String, bool>{
        'handled': handled,
        'snoozeCountIncremented':
            current['snoozeCount'] == (previous['snoozeCount']! as int) + 1,
        'revisionIncremented':
            current['scheduleRevision'] ==
            (previous['scheduleRevision']! as int) + 1,
        'scheduledAtMatchesSnoozedUntil':
            current['scheduledAtUtcMicros'] == current['snoozedUntilUtcMicros'],
        'scheduledAtWithinCallbackWindow':
            !scheduledAt.isBefore(earliest) && !scheduledAt.isAfter(latest),
        'reminderScheduled': current['status'] == 'scheduled',
        'registrationRevisionMatches':
            current['registrationRevision'] == current['scheduleRevision'],
        'platformNotificationIdPresent':
            current['platformNotificationId'] != null,
        'platformNotificationIdStable':
            previous['platformNotificationId'] == null ||
            current['platformNotificationId'] ==
                previous['platformNotificationId'],
        'platformOutboxSucceeded': current['nonSucceededPlatformJobCount'] == 0,
      };
      expect(
        assertions.entries
            .where((entry) => !entry.value)
            .map((entry) => entry.key),
        isEmpty,
        reason: '$minutes-minute notification callback must reschedule once.',
      );
      snoozeActions.add(<String, Object?>{
        'minutes': minutes,
        'actionId': 'danggui.snooze.$minutes',
        'payload': 'task:$taskId',
        'callStartedAtUtc': callStarted.toIso8601String(),
        'callCompletedAtUtc': callCompleted.toIso8601String(),
        ...current,
        'assertions': assertions,
      });
      previous = current;
    }
    await writeReleaseAcceptanceEvidence(
      'snooze-callback.json',
      <String, Object?>{
        'contractVersion': releaseAcceptanceContractVersion,
        'phase': 'production-notification-action-callbacks',
        'apiLevel': apiLevel,
        'scope': <String, Object?>{
          'productionCoordinator': true,
          'productionDatabase': true,
          'nativeNotificationGateway': true,
          'systemNotificationPreviouslyObserved': true,
          'systemUiActionClickClaimed': false,
        },
        'actions': snoozeActions,
      },
    );
    await database.customStatement('PRAGMA wal_checkpoint(FULL)');

    // Keep the instrumented process alive until the host has observed the
    // native AlarmManager registration produced by the final callback. The
    // Flutter test runner force-stops the app during teardown, which removes
    // alarms and would otherwise turn a successful reschedule into a false
    // negative in the host-side acceptance script.
    await waitForReleaseAcceptanceHostSignal(
      signalName: 'snooze-alarm-observed.signal',
      phase: 'snooze alarm evidence',
    );
  });
}

Future<Map<String, Object?>> _waitForSnoozeState(
  DangguiDatabase database,
  NotificationCoordinator coordinator,
  String taskId, {
  required int expectedSnoozeCount,
  required int expectedRevision,
}) async {
  for (var attempt = 0; attempt < 150; attempt += 1) {
    await coordinator.reconcile();
    final state = await _readSnoozeState(database, taskId);
    if (state['snoozeCount'] == expectedSnoozeCount &&
        state['scheduleRevision'] == expectedRevision &&
        state['registrationRevision'] == expectedRevision &&
        state['platformNotificationId'] != null &&
        state['nonSucceededPlatformJobCount'] == 0) {
      return state;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'The production notification gateway did not settle snooze revision '
    '$expectedRevision.',
  );
}

Future<Map<String, Object?>> _readSnoozeState(
  DangguiDatabase database,
  String taskId,
) async {
  final reminder = await database
      .customSelect(
        'SELECT r.scheduled_at_utc, r.snoozed_until_utc, r.snooze_count, '
        'r.schedule_revision, r.status, nr.platform_notification_id, '
        'nr.schedule_revision AS registration_revision '
        'FROM reminders r LEFT JOIN notification_registrations nr '
        'ON nr.reminder_id = r.id AND nr.platform = ? '
        'WHERE r.task_id = ?',
        variables: <Variable<Object>>[
          Variable.withString('android'),
          Variable.withString(taskId),
        ],
      )
      .getSingle();
  final failedJobs = await database
      .customSelect(
        'SELECT COUNT(*) AS value FROM platform_jobs WHERE status <> ?',
        variables: <Variable<Object>>[Variable.withString('succeeded')],
      )
      .getSingle();
  return <String, Object?>{
    'scheduledAtUtcMicros': reminder.read<int>('scheduled_at_utc'),
    'snoozedUntilUtcMicros': reminder.readNullable<int>('snoozed_until_utc'),
    'snoozeCount': reminder.read<int>('snooze_count'),
    'scheduleRevision': reminder.read<int>('schedule_revision'),
    'status': reminder.read<String>('status'),
    'platformNotificationId': reminder.readNullable<int>(
      'platform_notification_id',
    ),
    'registrationRevision': reminder.readNullable<int>('registration_revision'),
    'nonSucceededPlatformJobCount': failedJobs.read<int>('value'),
  };
}

bool _isQuickCheckOk(Object? value) {
  return value is List<Object?> &&
      value.length == 1 &&
      value.single.toString().toLowerCase() == 'ok';
}
