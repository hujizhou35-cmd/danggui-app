import 'dart:async';
import 'dart:convert';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/device_alarm_generation_store.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:danggui/src/services/notifications/native_alarm_platform.dart';
import 'package:danggui/src/services/platform_mutation_gate.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;

void main() {
  late DangguiDatabase database;
  late DateTime nowUtc;
  late DriftTaskRepository tasks;
  late FakeNotificationGateway gateway;
  late NotificationCoordinator coordinator;

  setUp(() {
    database = DangguiDatabase(NativeDatabase.memory());
    nowUtc = DateTime.utc(2026, 8, 22, 10);
    tasks = DriftTaskRepository(
      database,
      clock: FixedClock(() => nowUtc),
      ids: SequenceIds(),
    );
    gateway = FakeNotificationGateway();
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await database.close();
  });

  test(
    'Android alarm grade requires permission, channel, and exact access',
    () {
      final ready = resolveAndroidAlarmDeliveryLevel(
        soundEnabled: true,
        nativeSupported: true,
        exactSchedulingAvailable: true,
        notificationsGranted: true,
        selectedDeliveryChannelReady: true,
        nativeReportedLevel: ReminderDeliveryLevel.alarmGrade,
      );
      expect(ready.deliveryLevel, ReminderDeliveryLevel.alarmGrade);
      expect(ready.strongAlarmAuthorized, isTrue);

      for (final restricted
          in <({bool? notifications, bool channel, bool exact})>[
            (notifications: false, channel: true, exact: true),
            (notifications: true, channel: false, exact: true),
            (notifications: true, channel: true, exact: false),
          ]) {
        final value = resolveAndroidAlarmDeliveryLevel(
          soundEnabled: true,
          nativeSupported: true,
          exactSchedulingAvailable: restricted.exact,
          notificationsGranted: restricted.notifications,
          selectedDeliveryChannelReady: restricted.channel,
          nativeReportedLevel: restricted.exact
              ? ReminderDeliveryLevel.alarmGrade
              : ReminderDeliveryLevel.timeSensitiveBestEffort,
        );
        expect(value.strongAlarmAuthorized, isFalse);
        expect(
          value.deliveryLevel,
          restricted.notifications == false || !restricted.channel
              ? ReminderDeliveryLevel.unavailable
              : ReminderDeliveryLevel.timeSensitiveBestEffort,
        );
      }
    },
  );

  test('native alarm route uses the same strict platform predicates', () {
    for (final combination
        in <({bool sound, bool supported, bool? exact, bool expected})>[
          (sound: true, supported: true, exact: true, expected: true),
          (sound: false, supported: true, exact: true, expected: false),
          (sound: true, supported: false, exact: true, expected: false),
          (sound: true, supported: true, exact: false, expected: false),
          (sound: true, supported: true, exact: null, expected: false),
        ]) {
      expect(
        shouldUseNativeAlarmRoute(
          soundEnabled: combination.sound,
          nativeSupported: combination.supported,
          isAndroid: true,
          exactAlarmAllowed: combination.exact,
          alarmAuthorization: NativeAlarmAuthorization.unavailable,
        ),
        combination.expected,
      );
    }

    expect(
      shouldUseNativeAlarmRoute(
        soundEnabled: true,
        nativeSupported: true,
        isAndroid: false,
        exactAlarmAllowed: null,
        alarmAuthorization: NativeAlarmAuthorization.authorized,
      ),
      isTrue,
    );
    expect(
      shouldUseNativeAlarmRoute(
        soundEnabled: true,
        nativeSupported: true,
        isAndroid: false,
        exactAlarmAllowed: true,
        alarmAuthorization: NativeAlarmAuthorization.denied,
      ),
      isFalse,
    );
  });

  test('Android exact denial inspects the ordinary delivery channel', () {
    final useNativeAlarm = shouldUseNativeAlarmRoute(
      soundEnabled: true,
      nativeSupported: true,
      isAndroid: true,
      exactAlarmAllowed: false,
      alarmAuthorization: NativeAlarmAuthorization.unavailable,
    );
    expect(useNativeAlarm, isFalse);
    expect(
      selectedAndroidDeliveryChannelReady(
        usesNativeAlarmRoute: useNativeAlarm,
        nativeAlarmChannelEnabled: false,
        ordinaryChannelEnabled: true,
      ),
      isTrue,
    );
    expect(
      selectedAndroidDeliveryChannelReady(
        usesNativeAlarmRoute: useNativeAlarm,
        nativeAlarmChannelEnabled: true,
        ordinaryChannelEnabled: false,
      ),
      isFalse,
    );
  });

  test('silent Android reminder never reports strong alarm authorization', () {
    final value = resolveAndroidAlarmDeliveryLevel(
      soundEnabled: false,
      nativeSupported: true,
      exactSchedulingAvailable: true,
      notificationsGranted: true,
      selectedDeliveryChannelReady: true,
      nativeReportedLevel: ReminderDeliveryLevel.alarmGrade,
    );
    expect(value.deliveryLevel, ReminderDeliveryLevel.ordinary);
    expect(value.strongAlarmAuthorized, isFalse);
  });

  test('reconcile schedules exact request with persisted defaults', () async {
    await database.customStatement(
      'UPDATE app_settings SET default_snooze_minutes = 30 WHERE id = 1',
    );
    final task = await _createFutureReminder(tasks, nowUtc);

    await coordinator.reconcile();

    expect(gateway.initialized, isTrue);
    expect(gateway.scheduled, hasLength(1));
    final request = gateway.scheduled.single;
    expect(request.title, '核对引用');
    final actionIdentity = ReminderNotificationActionIdentity.tryDecode(
      request.payload,
    );
    expect(actionIdentity, isNotNull);
    expect(actionIdentity!.taskId, task.id.value);
    expect(actionIdentity.reminderId, request.reminderId);
    expect(actionIdentity.scheduleRevision, request.scheduleRevision);
    expect(actionIdentity.sessionId, isNotEmpty);
    expect(request.defaultSnoozeMinutes, 30);
    expect(request.soundEnabled, isTrue);
    expect(request.vibrationEnabled, isTrue);
    expect(request.exactScheduling, isTrue);
    expect(request.body, '当归事项提醒');
    final registration = await database
        .select(database.notificationRegistrations)
        .getSingle();
    expect(registration.scheduleRevision, 1);
    expect(registration.platform, 'test');
  });

  test(
    'v3 action payload canonicalizes an uppercase UUID generation',
    () async {
      const canonical = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
      const uppercase = 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF';
      await _installDeviceAlarmGeneration(database, canonical);
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final payload = jsonDecode(gateway.scheduled.single.payload) as Map;
      payload['generation'] = uppercase;

      final identity = ReminderNotificationActionIdentity.tryDecode(
        jsonEncode(payload),
      );

      expect(identity, isNotNull);
      expect(identity!.deviceGeneration, canonical);
    },
  );

  test(
    'new coordinator reschedules a succeeded future reminder exactly once',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final originalRegistration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      await database.customStatement(
        'UPDATE notification_registrations SET platform_notification_id = ?',
        <Object?>[424242],
      );
      final originalJobs = await database.select(database.platformJobs).get();
      expect(originalJobs, hasLength(1));
      expect(originalJobs.single.status, PlatformJobStatus.succeeded);

      nowUtc = nowUtc.add(const Duration(minutes: 1));
      gateway = FakeNotificationGateway();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );

      await coordinator.reconcile();
      await coordinator.reconcile();

      expect(gateway.scheduleCalls, 1);
      expect(gateway.scheduled.single.notificationId, 424242);
      final repairedRegistration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(repairedRegistration.platformNotificationId, 424242);
      expect(
        repairedRegistration.scheduleRevision,
        originalRegistration.scheduleRevision,
      );
      final repairedJobs = await database.select(database.platformJobs).get();
      expect(repairedJobs, hasLength(originalJobs.length));
      expect(repairedJobs.single.status, PlatformJobStatus.succeeded);
    },
  );

  test('startup diff preserves a matching native snapshot', () async {
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();

    gateway = FakeNotificationGateway()
      ..nativeSnapshots.add(
        NativeAlarmSnapshot(
          reminderId: reminder.id,
          platformId: 'native-${reminder.id}',
          scheduleRevision: reminder.scheduleRevision,
          triggerAtEpochMs:
              reminder.scheduledAtUtc ~/ Duration.microsecondsPerMillisecond,
          state: NativeAlarmSnapshotState.registered,
        ),
      );
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 0);
    expect(
      await database.select(database.notificationRegistrations).get(),
      hasLength(1),
    );
  });

  test('replace generation rejects old events and ordinary actions before reschedule', () async {
    gateway.platformNameValue = 'ios';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    final task = await _createFutureReminder(
      tasks,
      nowUtc,
      soundEnabled: false,
    );
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();
    final oldPayload = gateway.scheduled.single.payload;
    const generation = '99999999-9999-4999-8999-999999999999';
    await _installDeviceAlarmGeneration(database, generation);
    gateway.nativeEvents.add(
      NativeAlarmEvent(
        eventId: 'pre-restore-stop',
        reminderId: reminder.id,
        taskId: task.id.value,
        scheduleRevision: reminder.scheduleRevision,
        type: NativeAlarmEventType.stopped,
        occurredAtUtc: nowUtc.add(const Duration(minutes: 1)),
        sessionId: deterministicNativeAlarmSessionId(
          reminder.id,
          reminder.scheduleRevision,
        ),
      ),
    );

    await coordinator.reconcile();

    final unchanged = await database.select(database.reminders).getSingle();
    expect(unchanged.status, ReminderStatus.scheduled);
    expect(unchanged.scheduleRevision, reminder.scheduleRevision);
    expect(gateway.nativeEvents, isEmpty);
    expect(gateway.scheduleCalls, 2);
    final replacement = gateway.scheduled.last;
    expect(replacement.deviceGeneration, generation);
    final replacementIdentity = ReminderNotificationActionIdentity.tryDecode(
      replacement.payload,
    );
    expect(replacementIdentity?.deviceGeneration, generation);

    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        oldPayload,
      ),
      isFalse,
    );
    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        replacement.payload,
      ),
      isTrue,
    );
    final snoozed = await database.select(database.reminders).getSingle();
    expect(snoozed.scheduleRevision, reminder.scheduleRevision + 1);
    expect(snoozed.snoozeCount, 1);
  });

  test(
    'replace generation invalidates a same-revision native snapshot',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      gateway
        ..pendingNotificationIdsValue.clear()
        ..pendingNotificationPayloads.clear()
        ..nativeSnapshots.add(
          NativeAlarmSnapshot(
            reminderId: reminder.id,
            platformId: deterministicNativeAlarmSessionId(
              reminder.id,
              reminder.scheduleRevision,
            ),
            scheduleRevision: reminder.scheduleRevision,
            triggerAtEpochMs:
                reminder.scheduledAtUtc ~/ Duration.microsecondsPerMillisecond,
            state: NativeAlarmSnapshotState.registered,
          ),
        );
      const generation = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      await _installDeviceAlarmGeneration(database, generation);

      await coordinator.reconcile();

      expect(gateway.scheduleCalls, 2);
      expect(gateway.scheduled.last.deviceGeneration, generation);
    },
  );

  test(
    'restore waits for reconcile and the queued pass uses the winning database',
    () async {
      final gate = PlatformMutationGate();
      final firstScheduleStarted = Completer<void>();
      final allowFirstSchedule = Completer<void>();
      var firstSchedule = true;
      gateway.onSchedule = (request) async {
        if (!firstSchedule) return;
        firstSchedule = false;
        firstScheduleStarted.complete();
        await allowFirstSchedule.future;
      };
      coordinator.dispose();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
        mutationGate: gate,
      );
      await _createFutureReminder(tasks, nowUtc, soundEnabled: false);

      final firstPass = coordinator.reconcile();
      await firstScheduleStarted.future;

      final replacement = DangguiDatabase(NativeDatabase.memory());
      final replacementTasks = DriftTaskRepository(
        replacement,
        clock: FixedClock(() => nowUtc),
        ids: SequenceIds(),
      );
      await _createFutureReminder(
        replacementTasks,
        nowUtc,
        soundEnabled: false,
      );
      const generation = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
      await _installDeviceAlarmGeneration(replacement, generation);
      final losingDatabase = database;
      final restore = gate.protect(() async {
        database = replacement;
        tasks = replacementTasks;
        await losingDatabase.close();
      });
      final queuedPass = coordinator.reconcile();

      allowFirstSchedule.complete();
      await firstPass;
      await restore;
      await queuedPass;

      expect(gateway.scheduleCalls, 2);
      expect(gateway.scheduled.last.deviceGeneration, generation);
      expect(gateway.activeDeviceGeneration, generation);
    },
  );

  test('iOS startup preserves only an exact pending v2 identity', () async {
    gateway.platformNameValue = 'ios';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    await _createFutureReminder(tasks, nowUtc, soundEnabled: false);
    await coordinator.reconcile();
    final registration = await database
        .select(database.notificationRegistrations)
        .getSingle();
    final currentPayload = gateway.scheduled.single.payload;

    gateway = FakeNotificationGateway()
      ..platformNameValue = 'ios'
      ..pendingNotificationIdsValue.add(registration.platformNotificationId)
      ..pendingNotificationPayloads[registration.platformNotificationId] =
          currentPayload;
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 0);
  });

  test(
    'iOS startup replaces a legacy pending payload using the same id',
    () async {
      gateway.platformNameValue = 'ios';
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );
      final task = await _createFutureReminder(
        tasks,
        nowUtc,
        soundEnabled: false,
      );
      await coordinator.reconcile();
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();

      gateway = FakeNotificationGateway()
        ..platformNameValue = 'ios'
        ..pendingNotificationIdsValue.add(registration.platformNotificationId)
        ..pendingNotificationPayloads[registration.platformNotificationId] =
            'task:${task.id.value}';
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );

      await coordinator.reconcile();

      expect(gateway.scheduleCalls, 1);
      expect(
        gateway.scheduled.single.notificationId,
        registration.platformNotificationId,
      );
      expect(
        ReminderNotificationActionIdentity.tryDecode(
          gateway.scheduled.single.payload,
        ),
        isNotNull,
      );
    },
  );

  test('iOS startup replaces a stale but valid v2 pending identity', () async {
    gateway.platformNameValue = 'ios';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    await _createFutureReminder(tasks, nowUtc, soundEnabled: false);
    await coordinator.reconcile();
    final registration = await database
        .select(database.notificationRegistrations)
        .getSingle();
    final stalePayload = gateway.scheduled.single.payload;
    await database.customStatement(
      'UPDATE reminders SET schedule_revision = 2',
    );
    await database.customStatement(
      'UPDATE notification_registrations SET schedule_revision = 2',
    );

    gateway = FakeNotificationGateway()
      ..platformNameValue = 'ios'
      ..pendingNotificationIdsValue.add(registration.platformNotificationId)
      ..pendingNotificationPayloads[registration.platformNotificationId] =
          stalePayload;
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 1);
    expect(gateway.scheduled.single.scheduleRevision, 2);
    expect(
      gateway.scheduled.single.notificationId,
      registration.platformNotificationId,
    );
  });

  test('iOS startup expires an old legacy request without catch-up', () async {
    gateway.platformNameValue = 'ios';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    final task = await _createFutureReminder(
      tasks,
      nowUtc,
      soundEnabled: false,
    );
    await coordinator.reconcile();
    final registration = await database
        .select(database.notificationRegistrations)
        .getSingle();
    nowUtc = nowUtc.add(const Duration(hours: 3));

    gateway = FakeNotificationGateway()
      ..platformNameValue = 'ios'
      ..pendingNotificationIdsValue.add(registration.platformNotificationId)
      ..pendingNotificationPayloads[registration.platformNotificationId] =
          'task:${task.id.value}';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.expired);
    expect(gateway.scheduleCalls, 0);
    expect(gateway.cancelled, contains(registration.platformNotificationId));
  });

  test('replace restore removes managed ordinary orphans and rebuilds the new reminder', () async {
    gateway.platformNameValue = 'ios';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    final oldTask = await _createFutureReminder(
      tasks,
      nowUtc,
      soundEnabled: false,
    );
    await coordinator.reconcile();
    final oldRequest = gateway.scheduled.single;
    const legacyNotificationId = 987001;
    const unknownNotificationId = 987002;
    gateway
      ..pendingNotificationIdsValue.addAll(<int>{
        legacyNotificationId,
        unknownNotificationId,
      })
      ..pendingNotificationPayloads[legacyNotificationId] =
          'task:${oldTask.id.value}'
      ..pendingNotificationPayloads[unknownNotificationId] =
          'another-feature:keep';

    await _replaceLogicalDatabase(database);
    final newTask = await _createFutureReminder(
      tasks,
      nowUtc,
      soundEnabled: false,
    );
    await database.customStatement('DELETE FROM platform_jobs');

    await coordinator.reconcile();

    expect(
      gateway.cancelled,
      containsAll(<int>[oldRequest.notificationId, legacyNotificationId]),
    );
    expect(gateway.cancelled, isNot(contains(unknownNotificationId)));
    expect(
      gateway.pendingNotificationIdsValue,
      contains(unknownNotificationId),
    );
    expect(gateway.scheduled.last.taskId, newTask.id.value);
    final cancelCount = gateway.cancelled.length;
    final scheduleCount = gateway.scheduleCalls;

    await coordinator.reconcile();

    expect(gateway.cancelled, hasLength(cancelCount));
    expect(gateway.scheduleCalls, scheduleCount);
  });

  test(
    'replace restore removes native orphan and rebuilds the new reminder',
    () async {
      final oldTask = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final oldReminder = await database.select(database.reminders).getSingle();
      final oldRequest = gateway.scheduled.single;
      gateway
        ..pendingNotificationIdsValue.remove(oldRequest.notificationId)
        ..pendingNotificationPayloads.remove(oldRequest.notificationId)
        ..nativeSnapshots.add(
          NativeAlarmSnapshot(
            reminderId: oldReminder.id,
            platformId: deterministicNativeAlarmSessionId(
              oldReminder.id,
              oldReminder.scheduleRevision,
            ),
            scheduleRevision: oldReminder.scheduleRevision,
            triggerAtEpochMs:
                oldReminder.scheduledAtUtc ~/
                Duration.microsecondsPerMillisecond,
            state: NativeAlarmSnapshotState.registered,
          ),
        );

      await _replaceLogicalDatabase(database);
      final newTask = await _createFutureReminder(tasks, nowUtc);
      await database.customStatement('DELETE FROM platform_jobs');

      await coordinator.reconcile();

      expect(
        gateway.retiredNativeRoutes.map((route) => route.reminderId),
        contains(oldReminder.id),
      );
      expect(gateway.nativeSnapshots, isEmpty);
      expect(gateway.scheduled.last.taskId, newTask.id.value);
      final cancelCount = gateway.retiredNativeRoutes.length;
      final scheduleCount = gateway.scheduleCalls;

      await coordinator.reconcile();

      expect(gateway.retiredNativeRoutes, hasLength(cancelCount));
      expect(gateway.scheduleCalls, scheduleCount);
      expect(oldTask.id.value, isNot(newTask.id.value));
    },
  );

  test('Android startup reinstalls a future alarm despite a matching durable snapshot', () async {
    gateway.platformNameValue = 'android';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();

    gateway = FakeNotificationGateway()
      ..platformNameValue = 'android'
      ..nativeSnapshots.add(
        NativeAlarmSnapshot(
          reminderId: reminder.id,
          platformId: 'native-${reminder.id}',
          scheduleRevision: reminder.scheduleRevision,
          triggerAtEpochMs:
              reminder.scheduledAtUtc ~/ Duration.microsecondsPerMillisecond,
          state: NativeAlarmSnapshotState.registered,
        ),
      );
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();
    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 1);
    expect(
      gateway.scheduled.single.scheduleRevision,
      reminder.scheduleRevision,
    );
  });

  test('Android startup never reinstalls an already-due alarm', () async {
    gateway.platformNameValue = 'android';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();

    nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 5));
    gateway = FakeNotificationGateway()..platformNameValue = 'android';
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 0);
    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.scheduled);
  });

  test('startup diff replaces a stale native revision', () async {
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();

    gateway = FakeNotificationGateway()
      ..nativeSnapshots.add(
        NativeAlarmSnapshot(
          reminderId: reminder.id,
          platformId: 'native-${reminder.id}',
          scheduleRevision: reminder.scheduleRevision - 1,
          triggerAtEpochMs:
              reminder.scheduledAtUtc ~/ Duration.microsecondsPerMillisecond,
          state: NativeAlarmSnapshotState.registered,
        ),
      );
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
    );

    await coordinator.reconcile();

    expect(gateway.scheduleCalls, 1);
    expect(
      gateway.scheduled.single.scheduleRevision,
      reminder.scheduleRevision,
    );
  });

  test(
    'reconcile preserves an already-delivered notification when it expires',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(gateway.scheduled, hasLength(1));

      gateway.markDelivered(registration.platformNotificationId);
      nowUtc = nowUtc.add(const Duration(hours: 3));
      await coordinator.reconcile();

      final reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.expired);
      expect(reminder.pauseReason, isNull);
      expect(gateway.scheduled, hasLength(1));
      expect(
        gateway.cancelled,
        isNot(contains(registration.platformNotificationId)),
        reason: 'the fired notification must remain available for snooze',
      );
      expect(
        await database.select(database.notificationRegistrations).get(),
        isEmpty,
      );
      final jobs = await database.select(database.platformJobs).get();
      expect(jobs, hasLength(1));
      expect(jobs.single.status, PlatformJobStatus.succeeded);
    },
  );

  test('reconcile cancels a pending alarm after the fallback grace', () async {
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final registration = await database
        .select(database.notificationRegistrations)
        .getSingle();
    expect(
      gateway.pendingNotificationIdsValue,
      contains(registration.platformNotificationId),
    );

    nowUtc = nowUtc.add(const Duration(hours: 3, minutes: 16));
    await coordinator.reconcile();

    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.expired);
    expect(gateway.cancelled, contains(registration.platformNotificationId));
    expect(
      gateway.pendingNotificationIdsValue,
      isNot(contains(registration.platformNotificationId)),
    );
    expect(
      await database.select(database.notificationRegistrations).get(),
      isEmpty,
    );
  });

  test(
    'a native alarm is bounded by the shared fifteen-minute window',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      gateway.activeNativeReminderIds.add(reminder.id);

      nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 16));
      await coordinator.reconcile();

      final expired = await database.select(database.reminders).getSingle();
      expect(expired.status, ReminderStatus.expired);
      expect(gateway.cancelled, isNotEmpty);
    },
  );

  test(
    'failed startup reschedule retries without creating another outbox job',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();

      gateway = FakeNotificationGateway()..scheduleFailuresRemaining = 1;
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );

      await coordinator.reconcile();
      expect(gateway.scheduleCalls, 1);
      expect(gateway.scheduled, isEmpty);
      var jobs = await database.select(database.platformJobs).get();
      expect(jobs, hasLength(1));
      expect(jobs.single.status, PlatformJobStatus.succeeded);

      await coordinator.reconcile();
      await coordinator.reconcile();

      expect(gateway.scheduleCalls, 2);
      expect(gateway.scheduled, hasLength(1));
      expect(
        gateway.scheduled.single.notificationId,
        registration.platformNotificationId,
      );
      jobs = await database.select(database.platformJobs).get();
      expect(jobs, hasLength(1));
      expect(jobs.single.status, PlatformJobStatus.succeeded);
    },
  );

  test('failed outbox jobs wake and retry while the app stays alive', () async {
    gateway.scheduleFailuresRemaining = 1;
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
      retryBaseDelay: const Duration(milliseconds: 30),
    );
    await _createFutureReminder(tasks, nowUtc);

    await coordinator.reconcile();
    expect(gateway.scheduleCalls, 1);
    var job = await database.select(database.platformJobs).getSingle();
    expect(job.status, PlatformJobStatus.failed);

    gateway.permissionFailuresRemaining = 1;
    nowUtc = nowUtc.add(const Duration(milliseconds: 30));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (gateway.scheduled.isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Automatic notification retry did not wake.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(gateway.scheduleCalls, 2);
    job = await database.select(database.platformJobs).getSingle();
    expect(job.status, PlatformJobStatus.succeeded);
  });

  test(
    'new coordinator recovers an interrupted running job exactly once',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      final jobBefore = await database
          .select(database.platformJobs)
          .getSingle();
      await database.customStatement(
        'UPDATE platform_jobs SET status = ?, last_error_code = NULL',
        <Object?>[PlatformJobStatus.running.name],
      );

      gateway = FakeNotificationGateway();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );

      await coordinator.reconcile();
      await coordinator.reconcile();

      expect(gateway.scheduleCalls, 1);
      expect(
        gateway.scheduled.single.notificationId,
        registration.platformNotificationId,
      );
      final jobAfter = await database.select(database.platformJobs).getSingle();
      expect(jobAfter.id, jobBefore.id);
      expect(jobAfter.status, PlatformJobStatus.succeeded);
      expect(jobAfter.attempts, jobBefore.attempts + 1);
      expect(jobAfter.lastErrorCode, isNull);
      expect(await database.select(database.platformJobs).get(), hasLength(1));
    },
  );

  test(
    'startup reschedule preserves snooze options and localized presentation',
    () async {
      await database.customStatement(
        'UPDATE app_settings SET locale_mode = ?, '
        'default_snooze_minutes = 60 WHERE id = 1',
        <Object?>[LocaleMode.en.name],
      );
      final task = await _createFutureReminder(
        tasks,
        nowUtc,
        soundEnabled: false,
        vibrationEnabled: true,
      );
      await coordinator.reconcile();
      expect(
        await coordinator.snoozeReminderForTask(task.id.value, minutes: 30),
        isTrue,
      );
      final reminderBefore = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(task.id.value))).getSingle();
      final registrationBefore = await database
          .select(database.notificationRegistrations)
          .getSingle();
      final jobsBefore = await database.select(database.platformJobs).get();

      gateway = FakeNotificationGateway();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
      );

      await coordinator.reconcile();

      expect(gateway.presentations.single.localeTag, 'en');
      final request = gateway.scheduled.single;
      expect(request.notificationId, registrationBefore.platformNotificationId);
      expect(
        request.scheduledAtUtc.microsecondsSinceEpoch,
        reminderBefore.scheduledAtUtc,
      );
      expect(request.soundEnabled, isFalse);
      expect(request.vibrationEnabled, isTrue);
      expect(request.defaultSnoozeMinutes, 60);
      expect(request.body, 'Danggui task reminder');
      final reminderAfter = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(task.id.value))).getSingle();
      expect(reminderAfter.scheduleRevision, reminderBefore.scheduleRevision);
      expect(reminderAfter.snoozeCount, reminderBefore.snoozeCount);
      expect(reminderAfter.snoozedUntilUtc, reminderBefore.snoozedUntilUtc);
      final registrationAfter = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(registrationAfter.scheduledLocale, 'en');
      expect(
        await database.select(database.platformJobs).get(),
        hasLength(jobsBefore.length),
      );
    },
  );

  const localizedPresentationCases =
      <(LocaleMode, String, String, String, String)>[
        (LocaleMode.zhHans, 'zh', '当归事项提醒', '当归本地事项到期提醒', '10 分钟'),
        (
          LocaleMode.en,
          'en',
          'Danggui task reminders',
          'Local reminders when Danggui tasks are due',
          '10 minutes',
        ),
        (LocaleMode.ja, 'ja', '当帰の事項リマインダー', '当帰の事項の期日を知らせるローカル通知', '10分'),
        (
          LocaleMode.ru,
          'ru',
          'Напоминания Danggui',
          'Локальные напоминания о сроках дел Danggui',
          '10 минут',
        ),
      ];
  for (final testCase in localizedPresentationCases) {
    test(
      '${testCase.$2} localizes all operating-system reminder copy',
      () async {
        await database.customStatement(
          'UPDATE app_settings SET locale_mode = ? WHERE id = 1',
          <Object?>[testCase.$1.name],
        );
        await _createFutureReminder(tasks, nowUtc);

        await coordinator.reconcile();

        final presentation = gateway.presentations.single;
        expect(presentation.localeTag, testCase.$2);
        expect(presentation.channelName, testCase.$3);
        expect(presentation.channelDescription, testCase.$4);
        expect(presentation.snoozeLabel(10), testCase.$5);
        expect(
          presentation.snoozeActionLabels.keys,
          containsAll(<int>[10, 30, 60]),
        );
        expect(gateway.scheduled.single.body, switch (testCase.$1) {
          LocaleMode.zhHans => '当归事项提醒',
          LocaleMode.en => 'Danggui task reminder',
          LocaleMode.ja => '当帰の事項リマインダー',
          LocaleMode.ru => 'Напоминание о деле Danggui',
          LocaleMode.system => throw StateError('not used'),
        });
      },
    );
  }

  test(
    'system locale and later locale changes reinitialize categories',
    () async {
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'ru_RU',
      );

      await coordinator.reconcile();
      expect(gateway.presentations.single.localeTag, 'ru');

      await database.customStatement(
        'UPDATE app_settings SET locale_mode = ? WHERE id = 1',
        <Object?>[LocaleMode.en.name],
      );
      await coordinator.reconcile();

      expect(gateway.presentations.map((copy) => copy.localeTag), <String>[
        'ru',
        'en',
      ]);
    },
  );

  test('reminder wheel semantics are localized in all four languages', () {
    const expected = <String, (String, String)>{
      'zh': ('小时', '分钟'),
      'en': ('Hour', 'Minute'),
      'ja': ('時', '分'),
      'ru': ('Час', 'Минута'),
    };
    for (final entry in expected.entries) {
      final l10n = lookupAppLocalizations(Locale(entry.key));
      expect((l10n.reminderHour, l10n.reminderMinute), entry.value);
    }
  });

  for (final minutes in <int>[10, 30, 60]) {
    test(
      '$minutes minute action atomically updates reminder and replacement outbox',
      () async {
        final task = await _createFutureReminder(tasks, nowUtc);
        await coordinator.reconcile();
        final payload = gateway.scheduled.single.payload;

        final handled = await coordinator.handleNotificationAction(
          'danggui.snooze.$minutes',
          payload,
        );

        expect(handled, isTrue);
        final reminder = await (database.select(
          database.reminders,
        )..where((row) => row.taskId.equals(task.id.value))).getSingle();
        expect(reminder.scheduleRevision, 2);
        expect(reminder.snoozeCount, 1);
        expect(
          reminder.scheduledAtUtc,
          nowUtc.add(Duration(minutes: minutes)).microsecondsSinceEpoch,
        );
        expect(reminder.snoozedUntilUtc, reminder.scheduledAtUtc);
        final replacement = await (database.select(
          database.platformJobs,
        )..where((row) => row.aggregateRevision.equals(2))).getSingle();
        expect(replacement.kind, PlatformJobKind.scheduleReminder);
        expect(replacement.status, PlatformJobStatus.succeeded);
        expect(gateway.scheduled, hasLength(2));
      },
    );
  }

  test(
    'legacy task-only snooze payload cannot mutate a current reminder',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();

      expect(
        await coordinator.handleNotificationAction(
          'danggui.snooze.10',
          'task:${task.id.value}',
        ),
        isFalse,
      );
      final reminder = await database.select(database.reminders).getSingle();
      expect(reminder.scheduleRevision, 1);
      expect(reminder.snoozeCount, 0);
    },
  );

  test(
    'cold-start body tap opens a current task and deleted target falls back',
    () async {
      final openedTargets = <String?>[];
      coordinator.dispose();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
        onOpenRequested: openedTargets.add,
      );
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final payload = gateway.scheduled.single.payload;

      gateway.onAction!(null, payload);
      for (var attempt = 0; attempt < 20 && openedTargets.isEmpty; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(openedTargets, <String?>[task.id.value]);

      await tasks.moveTaskToTrash(task.id);
      expect(await coordinator.handleNotificationAction('', payload), isTrue);
      expect(openedTargets, <String?>[task.id.value, null]);
    },
  );

  test('legacy body tap may open but cannot mutate reminder state', () async {
    final openedTargets = <String?>[];
    coordinator.dispose();
    coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
      nowUtc: () => nowUtc,
      systemLocaleName: () => 'zh_CN',
      onOpenRequested: openedTargets.add,
    );
    final task = await _createFutureReminder(tasks, nowUtc);
    final reminderBefore = await database
        .select(database.reminders)
        .getSingle();

    expect(
      await coordinator.handleNotificationAction(null, 'task:${task.id.value}'),
      isTrue,
    );
    expect(openedTargets, <String?>[task.id.value]);
    final reminderAfter = await database.select(database.reminders).getSingle();
    expect(reminderAfter.scheduleRevision, reminderBefore.scheduleRevision);
    expect(reminderAfter.snoozeCount, reminderBefore.snoozeCount);
  });

  test(
    'replace generation makes old body taps fall back to the task list',
    () async {
      final openedTargets = <String?>[];
      coordinator.dispose();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
        onOpenRequested: openedTargets.add,
      );
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final oldPayload = gateway.scheduled.single.payload;

      const generation = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
      await _installDeviceAlarmGeneration(database, generation);
      await coordinator.reconcile();
      final currentPayload = gateway.scheduled.last.payload;

      expect(
        await coordinator.handleNotificationAction(null, oldPayload),
        isTrue,
      );
      expect(
        await coordinator.handleNotificationAction(
          null,
          'task:${task.id.value}',
        ),
        isTrue,
      );
      expect(
        await coordinator.handleNotificationAction(null, currentPayload),
        isTrue,
      );
      expect(openedTargets, <String?>[null, null, task.id.value]);
    },
  );

  test('old and repeated snooze action identities are idempotent', () async {
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final oldPayload = gateway.scheduled.single.payload;

    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        oldPayload,
      ),
      isTrue,
    );
    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        oldPayload,
      ),
      isFalse,
    );

    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.scheduleRevision, 2);
    expect(reminder.snoozeCount, 1);
  });

  test('snooze preserves IANA zone and applies its DST transition', () async {
    nowUtc = DateTime.utc(2026, 3, 8, 6, 55);
    final task = await _createFutureReminder(tasks, nowUtc);
    await database.customStatement(
      'UPDATE reminders SET scheduled_zone_id = ? WHERE task_id = ?',
      <Object?>['America/New_York', task.id.value],
    );

    expect(
      await coordinator.snoozeReminderForTask(task.id.value, minutes: 10),
      isTrue,
    );

    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.scheduledZoneId, 'America/New_York');
    expect(reminder.scheduledLocalDateTime, startsWith('2026-03-08T03:05'));
  });

  test('snooze preserves the repeated local hour at fall DST', () async {
    nowUtc = DateTime.utc(2026, 11, 1, 5, 55);
    final task = await _createFutureReminder(tasks, nowUtc);
    await database.customStatement(
      'UPDATE reminders SET scheduled_zone_id = ? WHERE task_id = ?',
      <Object?>['America/New_York', task.id.value],
    );

    expect(
      await coordinator.snoozeReminderForTask(task.id.value, minutes: 10),
      isTrue,
    );

    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.scheduledZoneId, 'America/New_York');
    expect(reminder.scheduledLocalDateTime, startsWith('2026-11-01T01:05'));
    expect(
      reminder.scheduledAtUtc,
      DateTime.utc(2026, 11, 1, 6, 5).microsecondsSinceEpoch,
    );
  });

  test(
    'invalid persisted zone normalizes both local time and zone to UTC',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      await database.customStatement(
        'UPDATE reminders SET scheduled_zone_id = ? WHERE task_id = ?',
        <Object?>['Mars/Olympus', task.id.value],
      );

      expect(
        await coordinator.snoozeReminderForTask(task.id.value, minutes: 10),
        isTrue,
      );

      final reminder = await database.select(database.reminders).getSingle();
      final expected = nowUtc.add(const Duration(minutes: 10)).toUtc();
      expect(reminder.scheduledZoneId, 'UTC');
      expect(reminder.scheduledLocalDateTime, expected.toIso8601String());
      expect(reminder.scheduledAtUtc, expected.microsecondsSinceEpoch);
    },
  );

  test('null snooze duration uses persisted default', () async {
    await database.customStatement(
      'UPDATE app_settings SET default_snooze_minutes = 60 WHERE id = 1',
    );
    final task = await _createFutureReminder(tasks, nowUtc);

    expect(await coordinator.snoozeReminderForTask(task.id.value), isTrue);

    final reminder = await (database.select(
      database.reminders,
    )..where((row) => row.taskId.equals(task.id.value))).getSingle();
    expect(
      reminder.scheduledAtUtc,
      nowUtc.add(const Duration(minutes: 60)).microsecondsSinceEpoch,
    );
  });

  test(
    'permission denial preserves time and queues a matching cancel revision',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      gateway.permissionGranted = false;

      await coordinator.applyPermissionResultForTask(
        task.id.value,
        granted: false,
      );

      final reminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(task.id.value))).getSingle();
      expect(reminder.status, ReminderStatus.permissionDenied);
      expect(reminder.pauseReason, ReminderPauseReason.permissionDenied);
      expect(
        reminder.scheduledAtUtc,
        nowUtc.add(const Duration(hours: 2)).microsecondsSinceEpoch,
      );
      final cancel =
          await (database.select(database.platformJobs)..where(
                (row) =>
                    row.aggregateRevision.equals(reminder.scheduleRevision),
              ))
              .getSingle();
      expect(cancel.kind, PlatformJobKind.cancelReminder);
      expect(cancel.status, PlatformJobStatus.succeeded);
      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelled, isNotEmpty);
    },
  );

  test(
    'granting permission revives all future permission-denied reminders',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      gateway.permissionGranted = false;
      await coordinator.applyPermissionResultForTask(
        task.id.value,
        granted: false,
      );
      gateway
        ..permissionGranted = true
        ..permissionRequestResult = true;

      expect(await coordinator.requestPermissions(), isTrue);

      final reminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(task.id.value))).getSingle();
      expect(reminder.status, ReminderStatus.scheduled);
      expect(reminder.pauseReason, isNull);
      expect(gateway.scheduled, hasLength(1));
    },
  );

  test(
    'permission database mutations wait behind the replacement gate',
    () async {
      final gate = PlatformMutationGate();
      coordinator.dispose();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
        mutationGate: gate,
      );
      final task = await _createFutureReminder(tasks, nowUtc);
      gateway.permissionGranted = false;

      Future<Completer<void>> holdGate() async {
        final entered = Completer<void>();
        final release = Completer<void>();
        unawaited(
          gate.protect(() async {
            entered.complete();
            await release.future;
          }),
        );
        await entered.future;
        return release;
      }

      final releaseDenial = await holdGate();
      var denialCompleted = false;
      final denial = coordinator
          .applyPermissionResultForTask(task.id.value, granted: false)
          .whenComplete(() => denialCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(denialCompleted, isFalse);
      expect(
        (await database.select(database.reminders).getSingle()).status,
        ReminderStatus.scheduled,
      );
      releaseDenial.complete();
      await denial;
      expect(
        (await database.select(database.reminders).getSingle()).status,
        ReminderStatus.permissionDenied,
      );

      gateway
        ..permissionGranted = true
        ..permissionRequestResult = true;
      final releaseGrant = await holdGate();
      var grantCompleted = false;
      final grant = coordinator.requestPermissions().whenComplete(
        () => grantCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(grantCompleted, isFalse);
      expect(
        (await database.select(database.reminders).getSingle()).status,
        ReminderStatus.permissionDenied,
      );
      releaseGrant.complete();
      expect(await grant, isTrue);
      expect(
        (await database.select(database.reminders).getSingle()).status,
        ReminderStatus.scheduled,
      );
    },
  );

  test('future-reminder permission check prompts only when needed', () async {
    gateway.permissionGranted = true;
    var result = await coordinator.ensurePermissionsForFutureReminder();
    expect(result.notificationsGranted, isTrue);
    expect(result.exactSchedulingAvailable, isTrue);
    expect(gateway.permissionRequests, 0);

    gateway
      ..permissionGranted = false
      ..permissionRequestResult = false;
    result = await coordinator.ensurePermissionsForFutureReminder();
    expect(result.notificationsGranted, isFalse);
    expect(result.exactSchedulingAvailable, isFalse);
    expect(gateway.permissionRequests, 1);
  });

  test(
    'native snooze event advances the durable revision and reschedules',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      final firedAt = nowUtc.add(const Duration(hours: 2));
      final successorAt = firedAt.add(
        const Duration(minutes: 30, milliseconds: 123),
      );
      gateway.nativeEvents.addAll(<NativeAlarmEvent>[
        NativeAlarmEvent(
          eventId: 'fired-1',
          reminderId: reminder.id,
          taskId: task.id.value,
          scheduleRevision: reminder.scheduleRevision,
          type: NativeAlarmEventType.delivered,
          occurredAtUtc: firedAt,
          sessionId: deterministicNativeAlarmSessionId(
            reminder.id,
            reminder.scheduleRevision,
          ),
        ),
        NativeAlarmEvent(
          eventId: 'snoozed-1',
          reminderId: reminder.id,
          taskId: task.id.value,
          scheduleRevision: reminder.scheduleRevision,
          type: NativeAlarmEventType.snoozed,
          occurredAtUtc: firedAt.add(const Duration(seconds: 1)),
          snoozeMinutes: 30,
          successorTriggerAtEpochMs: successorAt.millisecondsSinceEpoch,
          sessionId: deterministicNativeAlarmSessionId(
            reminder.id,
            reminder.scheduleRevision,
          ),
        ),
      ]);

      await coordinator.reconcile();

      final updated = await database.select(database.reminders).getSingle();
      expect(updated.status, ReminderStatus.scheduled);
      expect(updated.scheduleRevision, reminder.scheduleRevision + 1);
      expect(updated.snoozeCount, 1);
      expect(updated.scheduledAtUtc, successorAt.microsecondsSinceEpoch);
      expect(gateway.scheduled.last.scheduleRevision, updated.scheduleRevision);
      expect(gateway.nativeEvents, isEmpty);
    },
  );

  test(
    'native event acknowledgement failure does not block repair and retries',
    () async {
      var stateChanges = 0;
      coordinator.dispose();
      coordinator = NotificationCoordinator(
        () async => database,
        gateway: gateway,
        nowUtc: () => nowUtc,
        systemLocaleName: () => 'zh_CN',
        onStateChanged: () => stateChanges += 1,
        retryBaseDelay: Duration.zero,
      );
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      final firedAt = nowUtc.add(const Duration(hours: 2));
      final successorAt = firedAt.add(const Duration(minutes: 30));
      gateway
        ..acknowledgementFailuresRemaining = 1
        ..nativeEvents.add(
          NativeAlarmEvent(
            eventId: 'snooze-ack-retry',
            reminderId: reminder.id,
            taskId: task.id.value,
            scheduleRevision: reminder.scheduleRevision,
            type: NativeAlarmEventType.snoozed,
            occurredAtUtc: firedAt,
            snoozeMinutes: 30,
            successorTriggerAtEpochMs: successorAt.millisecondsSinceEpoch,
            sessionId: deterministicNativeAlarmSessionId(
              reminder.id,
              reminder.scheduleRevision,
            ),
          ),
        );

      await coordinator.reconcile();

      final repaired = await database.select(database.reminders).getSingle();
      expect(repaired.scheduleRevision, reminder.scheduleRevision + 1);
      expect(repaired.snoozeCount, 1);
      expect(repaired.scheduledAtUtc, successorAt.microsecondsSinceEpoch);
      expect(
        gateway.scheduled.last.scheduleRevision,
        repaired.scheduleRevision,
      );
      expect(stateChanges, 1);

      for (
        var attempt = 0;
        attempt < 20 && gateway.acknowledgementAttempts < 2;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(gateway.acknowledgementAttempts, 2);
      expect(gateway.nativeEvents, isEmpty);
      final replayed = await database.select(database.reminders).getSingle();
      expect(replayed.scheduleRevision, repaired.scheduleRevision);
      expect(replayed.snoozeCount, 1);
      expect(stateChanges, 1);
    },
  );

  test('native stop event expires and cancels the matching reminder', () async {
    final task = await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();
    gateway.nativeEvents.add(
      NativeAlarmEvent(
        eventId: 'stopped-1',
        reminderId: reminder.id,
        taskId: task.id.value,
        scheduleRevision: reminder.scheduleRevision,
        type: NativeAlarmEventType.stopped,
        occurredAtUtc: nowUtc.add(const Duration(hours: 2)),
        sessionId: deterministicNativeAlarmSessionId(
          reminder.id,
          reminder.scheduleRevision,
        ),
      ),
    );

    await coordinator.reconcile();

    final updated = await database.select(database.reminders).getSingle();
    expect(updated.status, ReminderStatus.expired);
    expect(updated.scheduleRevision, reminder.scheduleRevision + 1);
    expect(
      gateway.cancelled,
      contains(gateway.scheduled.single.notificationId),
    );
    expect(gateway.nativeEvents, isEmpty);
  });

  test(
    'revisionless native state event is acknowledged without mutation',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      gateway.nativeEvents.add(
        NativeAlarmEvent(
          eventId: 'legacy-stopped',
          reminderId: reminder.id,
          taskId: task.id.value,
          scheduleRevision: 0,
          type: NativeAlarmEventType.stopped,
          occurredAtUtc: nowUtc.add(const Duration(minutes: 1)),
        ),
      );

      await coordinator.reconcile();

      final unchanged = await database.select(database.reminders).getSingle();
      expect(unchanged.status, ReminderStatus.scheduled);
      expect(unchanged.scheduleRevision, reminder.scheduleRevision);
      expect(gateway.nativeEvents, isEmpty);
    },
  );

  test('native missed event expires exactly one matching revision', () async {
    final task = await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final reminder = await database.select(database.reminders).getSingle();
    final missed = NativeAlarmEvent(
      eventId: 'missed-1',
      reminderId: reminder.id,
      taskId: task.id.value,
      scheduleRevision: reminder.scheduleRevision,
      type: NativeAlarmEventType.missed,
      occurredAtUtc: nowUtc.add(const Duration(hours: 2, minutes: 16)),
      sessionId: deterministicNativeAlarmSessionId(
        reminder.id,
        reminder.scheduleRevision,
      ),
    );
    gateway.nativeEvents.addAll(<NativeAlarmEvent>[missed, missed]);

    await coordinator.reconcile();

    final updated = await database.select(database.reminders).getSingle();
    expect(updated.status, ReminderStatus.expired);
    expect(updated.scheduleRevision, reminder.scheduleRevision + 1);
    expect(gateway.nativeEvents, isEmpty);
    final cancelJobs = (await database.select(database.platformJobs).get())
        .where((job) => job.kind == PlatformJobKind.cancelReminder)
        .toList();
    expect(cancelJobs, hasLength(1));
  });

  test(
    'wrong native session is acknowledged without business mutation',
    () async {
      final task = await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final reminder = await database.select(database.reminders).getSingle();
      gateway.nativeEvents.add(
        NativeAlarmEvent(
          eventId: 'forged-stopped',
          reminderId: reminder.id,
          taskId: task.id.value,
          scheduleRevision: reminder.scheduleRevision,
          type: NativeAlarmEventType.stopped,
          occurredAtUtc: nowUtc.add(const Duration(hours: 2)),
          sessionId: 'forged',
        ),
      );

      await coordinator.reconcile();

      final unchanged = await database.select(database.reminders).getSingle();
      expect(unchanged.status, ReminderStatus.scheduled);
      expect(unchanged.scheduleRevision, reminder.scheduleRevision);
      expect(gateway.nativeEvents, isEmpty);
    },
  );

  test(
    'iOS AlarmKit authorization can deliver without ordinary alerts',
    () async {
      gateway
        ..permissionGranted = false
        ..nativeCapabilities = const NativeAlarmCapabilities(
          supported: true,
          platform: 'ios',
          alarmAuthorization: NativeAlarmAuthorization.notDetermined,
        );

      final result = await coordinator.ensurePermissionsForFutureReminder();

      expect(result.notificationsGranted, isTrue);
      expect(result.strongAlarmAuthorized, isTrue);
      expect(gateway.alarmAuthorizationRequests, 1);
      expect(gateway.permissionRequests, 0);
    },
  );

  test(
    'iOS AlarmKit keeps sound alarms when ordinary alerts are denied',
    () async {
      gateway
        ..platformNameValue = 'ios'
        ..permissionGranted = false
        ..nativeCapabilities = const NativeAlarmCapabilities(
          supported: true,
          platform: 'ios',
          alarmAuthorization: NativeAlarmAuthorization.authorized,
        );
      final soundTask = await _createFutureReminder(tasks, nowUtc);
      final silentTask = await _createFutureReminder(
        tasks,
        nowUtc,
        soundEnabled: false,
      );

      await coordinator.reconcile();

      final soundReminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(soundTask.id.value))).getSingle();
      final silentReminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(silentTask.id.value))).getSingle();
      expect(soundReminder.status, ReminderStatus.scheduled);
      expect(silentReminder.status, ReminderStatus.permissionDenied);
      expect(gateway.scheduled, hasLength(1));
      expect(gateway.scheduled.single.reminderId, soundReminder.id);
    },
  );

  test(
    'iOS AlarmKit alarms do not consume the sixty ordinary notification slots',
    () async {
      gateway
        ..platformNameValue = 'ios'
        ..nativeCapabilities = const NativeAlarmCapabilities(
          supported: true,
          platform: 'ios',
          alarmAuthorization: NativeAlarmAuthorization.authorized,
          notificationsEnabled: true,
        );
      for (var index = 0; index < 3; index++) {
        await _createFutureReminder(tasks, nowUtc);
      }
      for (var index = 0; index < 62; index++) {
        await _createFutureReminder(tasks, nowUtc, soundEnabled: false);
      }

      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(63));
      final deferred = (await database.select(database.platformJobs).get())
          .where((job) => job.lastErrorCode == 'capacity_deferred')
          .toList();
      expect(deferred, hasLength(2));
      expect(
        gateway.scheduled.where((request) => request.soundEnabled),
        hasLength(3),
      );
      expect(
        gateway.scheduled.where((request) => !request.soundEnabled),
        hasLength(60),
      );
    },
  );

  test(
    'pre-AlarmKit iOS reports best-effort instead of strong alarm',
    () async {
      gateway.nativeCapabilities = const NativeAlarmCapabilities(
        supported: false,
        platform: 'ios',
        alarmAuthorization: NativeAlarmAuthorization.unavailable,
        timeSensitiveEnabled: true,
      );

      final result = await coordinator.ensurePermissionsForFutureReminder();

      expect(result.notificationsGranted, isTrue);
      expect(result.strongAlarmAuthorized, isFalse);
      expect(
        result.deliveryLevel,
        ReminderDeliveryLevel.timeSensitiveBestEffort,
      );
      expect(gateway.alarmAuthorizationRequests, 0);
    },
  );

  test(
    'legacy iOS keeps sixty ordinary notifications and fills a freed slot',
    () async {
      gateway
        ..platformNameValue = 'ios'
        ..nativeCapabilities = const NativeAlarmCapabilities(
          supported: false,
          platform: 'ios',
          notificationsEnabled: true,
          timeSensitiveEnabled: true,
        );
      final created = <TaskModel>[];
      for (var index = 0; index < 62; index++) {
        created.add(await _createFutureReminder(tasks, nowUtc));
      }

      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(60));
      var deferred = (await database.select(database.platformJobs).get())
          .where((job) => job.lastErrorCode == 'capacity_deferred')
          .toList();
      expect(deferred, hasLength(2));

      await tasks.removeReminder(created.first.id);
      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(61));
      expect(gateway.pendingNotificationIdsValue, hasLength(60));
      deferred = (await database.select(database.platformJobs).get())
          .where((job) => job.lastErrorCode == 'capacity_deferred')
          .toList();
      expect(deferred, hasLength(1));
    },
  );

  test(
    'replace generation retires all old projections before 60 of 64 rebuild',
    () async {
      gateway
        ..platformNameValue = 'ios'
        ..nativeCapabilities = const NativeAlarmCapabilities(
          supported: true,
          platform: 'ios',
          alarmAuthorization: NativeAlarmAuthorization.denied,
          notificationsEnabled: true,
          timeSensitiveEnabled: true,
        );
      for (var index = 0; index < 64; index++) {
        await _createFutureReminder(tasks, nowUtc, soundEnabled: false);
      }
      await coordinator.reconcile();
      expect(gateway.pendingNotificationPayloads, hasLength(60));
      final oldPayloads = gateway.pendingNotificationPayloads.values.toSet();
      gateway.retiredNativeRoutes.clear();
      final reminders = await database.select(database.reminders).get();
      for (final reminder in reminders.skip(60)) {
        gateway.nativeSnapshots.add(
          NativeAlarmSnapshot(
            reminderId: reminder.id,
            platformId: deterministicNativeAlarmSessionId(
              reminder.id,
              reminder.scheduleRevision,
            ),
            scheduleRevision: reminder.scheduleRevision,
            triggerAtEpochMs:
                reminder.scheduledAtUtc ~/ Duration.microsecondsPerMillisecond,
            state: NativeAlarmSnapshotState.registered,
          ),
        );
      }

      const generation = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
      await _installDeviceAlarmGeneration(database, generation);
      await _rebuildReminderOutbox(database, nowUtc);
      await coordinator.reconcile();

      expect(gateway.activeDeviceGeneration, generation);
      expect(gateway.pendingNotificationPayloads, hasLength(60));
      expect(
        gateway.pendingNotificationPayloads.values,
        everyElement(isNot(isIn(oldPayloads))),
      );
      expect(
        gateway.pendingNotificationPayloads.values.map(
          ReminderNotificationActionIdentity.tryDecode,
        ),
        everyElement(
          isA<ReminderNotificationActionIdentity>().having(
            (identity) => identity.deviceGeneration,
            'device generation',
            generation,
          ),
        ),
      );
      final deferred = (await database.select(database.platformJobs).get())
          .where((job) => job.lastErrorCode == 'capacity_deferred')
          .toList();
      expect(deferred, hasLength(4));
      expect(gateway.nativeSnapshots, isEmpty);
      expect(
        gateway.retiredNativeRoutes.where((route) => route.generation == null),
        hasLength(4),
      );
    },
  );

  test('exact-alarm denial keeps delivery with an inexact fallback', () async {
    gateway
      ..exactSchedulingAvailable = false
      ..exactPermissionRequestResult = false;
    final result = await coordinator.ensurePermissionsForFutureReminder();

    expect(result.notificationsGranted, isTrue);
    expect(result.exactSchedulingAvailable, isFalse);
    expect(gateway.exactPermissionRequests, 1);

    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    expect(gateway.scheduled.single.exactScheduling, isFalse);
  });

  test(
    'granting exact access replaces a future fallback with the same id',
    () async {
      gateway.exactSchedulingAvailable = false;
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final fallback = gateway.scheduled.single;
      expect(fallback.exactScheduling, isFalse);

      gateway.exactSchedulingAvailable = true;
      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(2));
      expect(gateway.scheduled.last.notificationId, fallback.notificationId);
      expect(gateway.scheduled.last.exactScheduling, isTrue);
    },
  );

  test('delivered exact reminder uses the fifteen-minute window', () async {
    await _createFutureReminder(tasks, nowUtc);
    await coordinator.reconcile();
    final notificationId = gateway.scheduled.single.notificationId;

    nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 1));
    await coordinator.reconcile();
    var reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.scheduled);
    expect(gateway.cancelled, isEmpty);

    gateway.markDelivered(notificationId);
    nowUtc = nowUtc.add(const Duration(minutes: 2));
    await coordinator.reconcile();
    reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.scheduled);

    nowUtc = nowUtc.add(const Duration(minutes: 13));
    await coordinator.reconcile();
    reminder = await database.select(database.reminders).getSingle();
    expect(reminder.status, ReminderStatus.expired);
    expect(gateway.cancelled, isEmpty);
  });

  test(
    'exactly fifteen minutes late remains inside the shared window',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();

      nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 15));
      await coordinator.reconcile();
      var reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.scheduled);

      nowUtc = nowUtc.add(const Duration(microseconds: 1));
      await coordinator.reconcile();
      reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.expired);
    },
  );

  test('late repair retains the original native delivery deadline', () async {
    final base = nowUtc;
    await _createFutureReminder(tasks, base);
    nowUtc = base.add(const Duration(hours: 2, minutes: 14));

    await coordinator.reconcile();

    final request = gateway.scheduled.single;
    expect(request.scheduledAtUtc, nowUtc.add(const Duration(seconds: 1)));
    expect(request.originalScheduledAtUtc, base.add(const Duration(hours: 2)));
    // Both Android and iOS native gateways use this immutable value; only the
    // ordinary local-notification request is advanced to the next second.
    expect(nativeAlarmTriggerAtUtc(request), request.originalScheduledAtUtc);
  });

  test(
    'inexact fallback uses the same fifteen-minute delivery window',
    () async {
      gateway.exactSchedulingAvailable = false;
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();

      nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 14));
      await coordinator.reconcile();
      var reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.scheduled);

      nowUtc = nowUtc.add(const Duration(minutes: 2));
      await coordinator.reconcile();
      reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.expired);
      expect(gateway.cancelled, isNotEmpty);
    },
  );

  test(
    'granting exact access does not change the shared delivery window',
    () async {
      gateway.exactSchedulingAvailable = false;
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      expect(gateway.scheduled.single.exactScheduling, isFalse);

      nowUtc = nowUtc.add(const Duration(hours: 2, minutes: 10));
      gateway.exactSchedulingAvailable = true;
      await coordinator.reconcile();

      var reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.scheduled);
      expect(gateway.cancelled, isEmpty);

      nowUtc = nowUtc.add(const Duration(minutes: 6));
      await coordinator.reconcile();
      reminder = await database.select(database.reminders).getSingle();
      expect(reminder.status, ReminderStatus.expired);
      expect(gateway.cancelled, isNotEmpty);
    },
  );

  test(
    'stale outbox is discarded while startup repairs the current revision',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await database.customStatement(
        'UPDATE reminders SET schedule_revision = schedule_revision + 1',
      );

      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(1));
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(registration.scheduleRevision, 2);
      final stale = await database.select(database.platformJobs).getSingle();
      expect(stale.status, PlatformJobStatus.succeeded);
      expect(stale.lastErrorCode, 'stale_revision_discarded');
    },
  );

  test(
    'revision changed during platform call is cancelled and not registered',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      gateway.onSchedule = (_) async {
        await database.customStatement(
          'UPDATE reminders SET schedule_revision = schedule_revision + 1',
        );
      };

      await coordinator.reconcile();

      expect(gateway.scheduled, hasLength(1));
      expect(gateway.cancelled, hasLength(1));
      expect(
        await database.select(database.notificationRegistrations).get(),
        isEmpty,
      );
      final stale = await database.select(database.platformJobs).getSingle();
      expect(stale.lastErrorCode, 'stale_after_platform_call');
    },
  );

  test('malformed or unsupported actions are ignored', () async {
    expect(await coordinator.handleNotificationAction(null, null), isFalse);
    expect(
      await coordinator.handleNotificationAction(null, 'other:payload'),
      isFalse,
    );
    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.15',
        'task:any',
      ),
      isFalse,
    );
    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        'bad-payload',
      ),
      isFalse,
    );
    expect(
      await coordinator.handleNotificationAction(
        'danggui.snooze.10',
        '{"v":2,"taskId":"task","reminderId":"reminder",'
            '"revision":1,"session":"forged"}',
      ),
      isFalse,
    );
  });

  test(
    'AppStore createTask reads reminder sound and vibration defaults',
    () async {
      await database.customStatement(
        'UPDATE app_settings SET default_sound_enabled = 0, '
        'default_vibration_enabled = 1 WHERE id = 1',
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => database)],
      );
      addTearDown(container.dispose);
      await container.read(appStoreProvider.future);

      final taskId = await container
          .read(appStoreProvider.notifier)
          .createTask(
            title: '默认提醒',
            reminderAt: DateTime.now().add(const Duration(days: 1)),
          );

      final reminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      expect(reminder.soundEnabled, isFalse);
      expect(reminder.vibrationEnabled, isTrue);
    },
  );
}

Future<TaskModel> _createFutureReminder(
  DriftTaskRepository tasks,
  DateTime nowUtc, {
  bool soundEnabled = true,
  bool vibrationEnabled = true,
}) async {
  final task = await tasks.createTask(const TaskDraft(title: '核对引用'));
  await tasks.setReminder(
    ReminderDraft(
      taskId: task.id,
      scheduledLocalDateTime: '2026-08-22T12:00:00.000',
      scheduledZoneId: 'UTC',
      scheduledAtUtc: nowUtc.add(const Duration(hours: 2)),
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    ),
  );
  return task;
}

Future<void> _replaceLogicalDatabase(DangguiDatabase database) async {
  await database.transaction(() async {
    await database.customStatement('DELETE FROM platform_jobs');
    await database.customStatement('DELETE FROM notification_registrations');
    await database.customStatement('DELETE FROM reminders');
    await database.customStatement('DELETE FROM tasks');
  });
}

Future<void> _rebuildReminderOutbox(
  DangguiDatabase database,
  DateTime nowUtc,
) async {
  final now = nowUtc.microsecondsSinceEpoch;
  await database.transaction(() async {
    await database.customStatement('DELETE FROM notification_registrations');
    await database.customStatement('DELETE FROM platform_jobs');
    final reminders = await database
        .customSelect(
          'SELECT id, task_id, schedule_revision FROM reminders '
          'ORDER BY id',
        )
        .get();
    for (var index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];
      final reminderId = reminder.read<String>('id');
      final taskId = reminder.read<String>('task_id');
      final revision = reminder.read<int>('schedule_revision');
      final kind = PlatformJobKind.scheduleReminder.name;
      await database.customStatement(
        'INSERT INTO platform_jobs '
        '(id, kind, aggregate_id, aggregate_revision, dedupe_key, '
        'payload_json, status, attempts, next_attempt_at_utc, '
        'last_error_code, created_at_utc, updated_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, NULL, ?, ?)',
        <Object?>[
          'replace-job-$index',
          kind,
          reminderId,
          revision,
          '$kind:$reminderId:$revision',
          jsonEncode(<String, Object?>{'taskId': taskId}),
          PlatformJobStatus.pending.name,
          now,
          now,
          now,
        ],
      );
    }
  });
}

Future<void> _installDeviceAlarmGeneration(
  DangguiDatabase database,
  String generation,
) {
  return DeviceAlarmGenerationStore(database).createForReplacement(
    operationId: generation,
    sourceName: 'notification-generation-test.dgbak',
    sourceSha256: List<String>.filled(64, 'a').join(),
    sourceSchemaVersion: 1,
    encrypted: false,
    safetyCopyName: 'notification-generation-test.sqlite',
    completedAtUtc: 1,
  );
}

final class FakeNotificationGateway
    implements
        NotificationGateway,
        PendingNotificationPayloadGateway,
        ReminderCapabilityGateway,
        NativeReminderGateway,
        DeviceAlarmGenerationGateway,
        NativeReminderRouteGateway {
  bool get initialized => presentations.isNotEmpty;
  bool permissionGranted = true;
  int permissionFailuresRemaining = 0;
  bool permissionRequestResult = true;
  int permissionRequests = 0;
  bool exactSchedulingAvailable = true;
  bool exactPermissionRequestResult = true;
  int exactPermissionRequests = 0;
  bool? soundAvailable = true;
  bool? vibrationAvailable = true;
  ReminderDeliveryLevel? deliveryLevelValue;
  int scheduleCalls = 0;
  int scheduleFailuresRemaining = 0;
  void Function(String? actionId, String? payload)? onAction;
  Future<void> Function(LocalNotificationRequest request)? onSchedule;
  final List<LocalNotificationRequest> scheduled = [];
  final List<int> cancelled = [];
  final List<String> cancelledReminderIds = <String>[];
  final List<NotificationPresentation> presentations = [];
  final Set<int> pendingNotificationIdsValue = <int>{};
  final Map<int, String?> pendingNotificationPayloads = <int, String?>{};
  final Set<String> activeNativeReminderIds = <String>{};
  final List<NativeAlarmSnapshot> nativeSnapshots = <NativeAlarmSnapshot>[];
  final List<NativeAlarmEvent> nativeEvents = <NativeAlarmEvent>[];
  int acknowledgementFailuresRemaining = 0;
  int acknowledgementAttempts = 0;
  NativeAlarmCapabilities nativeCapabilities =
      const NativeAlarmCapabilities.unsupported();
  int alarmAuthorizationRequests = 0;
  int fullScreenPermissionRequests = 0;
  int testAlarmRequests = 0;
  String? activeDeviceGeneration;
  final List<({String reminderId, int revision, String? generation})>
  retiredNativeRoutes = [];

  @override
  bool get isSupported => true;

  String platformNameValue = 'test';

  @override
  String get platformName => platformNameValue;

  @override
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  }) async {
    presentations.add(presentation);
    this.onAction = onAction;
  }

  @override
  Future<bool?> permissionsGranted() async {
    if (permissionFailuresRemaining > 0) {
      permissionFailuresRemaining--;
      throw StateError('simulated permission query failure');
    }
    return permissionGranted;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionRequests += 1;
    return permissionRequestResult;
  }

  @override
  Future<ReminderDeliveryCapabilities> deliveryCapabilities({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async => ReminderDeliveryCapabilities(
    notificationsGranted: await permissionsGranted(),
    exactSchedulingAvailable: exactSchedulingAvailable,
    exactAlarmPermissionRequired: !exactSchedulingAvailable,
    soundAvailable: soundEnabled ? soundAvailable : null,
    vibrationAvailable: vibrationEnabled ? vibrationAvailable : null,
    vibrationControlledBySystem: platformName == 'ios',
    deliveryLevel:
        deliveryLevelValue ??
        (platformName == 'ios' || nativeCapabilities.platform == 'ios'
            ? nativeCapabilities.deliveryLevel
            : exactSchedulingAvailable
            ? ReminderDeliveryLevel.alarmGrade
            : ReminderDeliveryLevel.ordinary),
    strongAlarmAuthorized: platformName == 'ios'
        ? nativeCapabilities.strongAlarmAuthorized
        : exactSchedulingAvailable,
    timeSensitiveAvailable: platformName == 'ios'
        ? nativeCapabilities.timeSensitiveEnabled
        : null,
  );

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactPermissionRequests += 1;
    if (exactPermissionRequestResult) exactSchedulingAvailable = true;
    return exactPermissionRequestResult;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async =>
      Set<int>.of(pendingNotificationIdsValue);

  @override
  Future<List<PendingLocalNotificationSnapshot>>
  pendingNotificationSnapshots() async => <PendingLocalNotificationSnapshot>[
    for (final notificationId in pendingNotificationIdsValue)
      PendingLocalNotificationSnapshot(
        notificationId: notificationId,
        payload: pendingNotificationPayloads[notificationId],
      ),
  ];

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    scheduleCalls += 1;
    if (scheduleFailuresRemaining > 0) {
      scheduleFailuresRemaining -= 1;
      throw StateError('simulated schedule failure');
    }
    scheduled.add(request);
    pendingNotificationIdsValue.add(request.notificationId);
    pendingNotificationPayloads[request.notificationId] = request.payload;
    await onSchedule?.call(request);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pendingNotificationIdsValue.remove(notificationId);
    pendingNotificationPayloads.remove(notificationId);
  }

  @override
  Future<NativeAlarmCapabilities> nativeAlarmCapabilities() async =>
      nativeCapabilities;

  @override
  Future<bool> requestAlarmAuthorization() async {
    alarmAuthorizationRequests += 1;
    if (nativeCapabilities.platform != 'ios') return false;
    nativeCapabilities = const NativeAlarmCapabilities(
      supported: true,
      platform: 'ios',
      alarmAuthorization: NativeAlarmAuthorization.authorized,
    );
    return true;
  }

  @override
  Future<bool> requestFullScreenPermission() async {
    fullScreenPermissionRequests += 1;
    return true;
  }

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openAlarmSoundSettings() async {}

  @override
  Future<bool> openOemAutostartSettings() async => false;

  @override
  Future<void> activateDeviceGeneration(String? deviceGeneration) async {
    activeDeviceGeneration = deviceGeneration;
  }

  @override
  Future<void> retireNativeReminderRoute({
    required String reminderId,
    required int scheduleRevision,
    required String sessionId,
    required String? deviceGeneration,
  }) async {
    retiredNativeRoutes.add((
      reminderId: reminderId,
      revision: scheduleRevision,
      generation: deviceGeneration,
    ));
    nativeSnapshots.removeWhere(
      (snapshot) =>
          snapshot.reminderId == reminderId &&
          snapshot.scheduleRevision == scheduleRevision &&
          snapshot.deviceGeneration == deviceGeneration,
    );
  }

  @override
  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    required bool vibrationEnabled,
  }) async {
    testAlarmRequests += 1;
  }

  @override
  Future<void> cancelReminder({
    required String reminderId,
    required int notificationId,
    String? deviceGeneration,
  }) async {
    cancelledReminderIds.add(reminderId);
    nativeSnapshots.removeWhere(
      (snapshot) => snapshot.reminderId == reminderId,
    );
    activeNativeReminderIds.remove(reminderId);
    await cancel(notificationId);
  }

  @override
  Future<List<NativeAlarmSnapshot>> activeNativeAlarmSnapshots() async =>
      <NativeAlarmSnapshot>[
        ...nativeSnapshots,
        for (final reminderId in activeNativeReminderIds)
          NativeAlarmSnapshot(
            reminderId: reminderId,
            platformId: reminderId,
            scheduleRevision: 0,
            triggerAtEpochMs: 0,
            state: NativeAlarmSnapshotState.ringing,
          ),
      ];

  @override
  Future<List<NativeAlarmEvent>> drainAlarmEvents() async {
    return List<NativeAlarmEvent>.of(nativeEvents);
  }

  @override
  Future<void> acknowledgeAlarmEvents(Set<String> eventIds) async {
    acknowledgementAttempts += 1;
    if (acknowledgementFailuresRemaining > 0) {
      acknowledgementFailuresRemaining -= 1;
      throw StateError('simulated acknowledgement failure');
    }
    nativeEvents.removeWhere((event) => eventIds.contains(event.eventId));
  }

  void markDelivered(int notificationId) {
    pendingNotificationIdsValue.remove(notificationId);
    pendingNotificationPayloads.remove(notificationId);
  }
}

final class FixedClock implements Clock {
  const FixedClock(this.read);
  final DateTime Function() read;

  @override
  DateTime nowUtc() => read().toUtc();
}

final class SequenceIds implements IdGenerator {
  var _value = 0;

  @override
  String next() => 'notification-test-${++_value}';
}
