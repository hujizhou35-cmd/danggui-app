import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
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
    'reconcile schedules inexact-capable request with persisted defaults',
    () async {
      await database.customStatement(
        'UPDATE app_settings SET default_snooze_minutes = 30 WHERE id = 1',
      );
      final task = await _createFutureReminder(tasks, nowUtc);

      await coordinator.reconcile();

      expect(gateway.initialized, isTrue);
      expect(gateway.scheduled, hasLength(1));
      final request = gateway.scheduled.single;
      expect(request.title, '核对引用');
      expect(request.payload, 'task:${task.id.value}');
      expect(request.defaultSnoozeMinutes, 30);
      expect(request.soundEnabled, isTrue);
      expect(request.vibrationEnabled, isTrue);
      expect(request.body, '当归事项提醒');
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(registration.scheduleRevision, 1);
      expect(registration.platform, 'test');
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

  test(
    'reconcile cancels a delayed pending alarm before it can catch up',
    () async {
      await _createFutureReminder(tasks, nowUtc);
      await coordinator.reconcile();
      final registration = await database
          .select(database.notificationRegistrations)
          .getSingle();
      expect(
        gateway.pendingNotificationIdsValue,
        contains(registration.platformNotificationId),
      );

      nowUtc = nowUtc.add(const Duration(hours: 3));
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

        final handled = await coordinator.handleNotificationAction(
          'danggui.snooze.$minutes',
          'task:${task.id.value}',
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

  test('future-reminder permission check prompts only when needed', () async {
    gateway.permissionGranted = true;
    expect(await coordinator.ensurePermissionsForFutureReminder(), isTrue);
    expect(gateway.permissionRequests, 0);

    gateway
      ..permissionGranted = false
      ..permissionRequestResult = false;
    expect(await coordinator.ensurePermissionsForFutureReminder(), isFalse);
    expect(gateway.permissionRequests, 1);
  });

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

final class FakeNotificationGateway implements NotificationGateway {
  bool get initialized => presentations.isNotEmpty;
  bool permissionGranted = true;
  int permissionFailuresRemaining = 0;
  bool permissionRequestResult = true;
  int permissionRequests = 0;
  int scheduleCalls = 0;
  int scheduleFailuresRemaining = 0;
  void Function(String? actionId, String? payload)? onAction;
  Future<void> Function(LocalNotificationRequest request)? onSchedule;
  final List<LocalNotificationRequest> scheduled = [];
  final List<int> cancelled = [];
  final List<NotificationPresentation> presentations = [];
  final Set<int> pendingNotificationIdsValue = <int>{};

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'test';

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
  Future<Set<int>> pendingNotificationIds() async =>
      Set<int>.of(pendingNotificationIdsValue);

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    scheduleCalls += 1;
    if (scheduleFailuresRemaining > 0) {
      scheduleFailuresRemaining -= 1;
      throw StateError('simulated schedule failure');
    }
    scheduled.add(request);
    pendingNotificationIdsValue.add(request.notificationId);
    await onSchedule?.call(request);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pendingNotificationIdsValue.remove(notificationId);
  }

  void markDelivered(int notificationId) {
    pendingNotificationIdsValue.remove(notificationId);
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
