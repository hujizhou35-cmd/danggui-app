import 'dart:io';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/app.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/tasks/task_creation_sheet.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
import 'package:danggui/src/services/backup/automatic_backup_coordinator.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:danggui/src/services/notifications/notification_settings_launcher.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;
  late _FakeNotificationSettingsLauncher settingsLauncher;
  late _FakeNotificationGateway notificationGateway;
  late Directory backupDirectory;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    backupDirectory = await Directory.systemTemp.createTemp(
      'danggui-task-test-',
    );
    settingsLauncher = _FakeNotificationSettingsLauncher();
    notificationGateway = _FakeNotificationGateway();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        notificationCoordinatorProvider.overrideWithValue(
          NotificationCoordinator(
            () async => database,
            gateway: notificationGateway,
          ),
        ),
        notificationSettingsLauncherProvider.overrideWithValue(
          settingsLauncher,
        ),
        automaticBackupCoordinatorProvider.overrideWithValue(
          AutomaticBackupCoordinator(
            clock: DateTime.now,
            readSettings: () async =>
                const AppSettingsModel(autoBackupEnabled: false),
            readPassphrase: () async => null,
            readDirectory: () async => backupDirectory,
            createBackup: ({
              required passphrase,
              required kind,
              required outputDirectory,
            }) => throw StateError('Disabled automatic backup ran.'),
          ),
        ),
      ],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    await backupDirectory.delete(recursive: true);
  });

  test('next reminder defaults to the next future five-minute boundary', () {
    expect(
      nextReminderTime(DateTime(2026, 8, 23, 10, 2, 45)),
      DateTime(2026, 8, 23, 10, 5),
    );
    expect(
      nextReminderTime(DateTime(2026, 8, 23, 10, 5)),
      DateTime(2026, 8, 23, 10, 10),
    );
    expect(
      nextReminderTime(DateTime.utc(2026, 8, 23, 23, 59, 59)),
      DateTime.utc(2026, 8, 24),
    );
  });

  testWidgets('shared creation sheet defaults to today and can clear it', (
    tester,
  ) async {
    TaskCreationResult? saved;
    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              saved = await showTaskCreationSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final expectedToday = DateTime(now.year, now.month, now.day);
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(TaskCreationSheet)))
            .formatMediumDate(expectedToday),
      ),
      findsOneWidget,
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'task-creation-title',
    );

    await tester.enterText(
      find.byKey(const Key('task-creation-title')),
      '当天事项',
    );
    await tester.tap(find.byKey(const Key('task-creation-clear-due-date')));
    await tester.tap(find.byKey(const Key('task-creation-more-settings')));
    await tester.pumpAndSettle();

    expect(saved?.title, '当天事项');
    expect(saved?.dueDate, isNull);
    expect(saved?.openDetails, isTrue);
  });

  testWidgets('keyboard submit honors the configured details continuation', (
    tester,
  ) async {
    TaskCreationResult? saved;
    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              saved = await showTaskCreationSheet(context, openDetails: true);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-creation-title')),
      '键盘继续事项',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(saved?.title, '键盘继续事项');
    expect(saved?.openDetails, isTrue);
  });

  testWidgets('shared creation sheet preserves conversion body and options', (
    tester,
  ) async {
    TaskCreationResult? saved;
    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              saved = await showTaskCreationSheet(
                context,
                initialTitle: '来自笔记',
                initialBody: '已有正文',
                openDetails: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-creation-body')), findsOneWidget);
    final now = DateTime.now();
    final expectedToday = DateTime(now.year, now.month, now.day);
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(TaskCreationSheet)))
            .formatMediumDate(expectedToday),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('task-creation-save')));
    await tester.pumpAndSettle();

    expect(saved?.title, '来自笔记');
    expect(saved?.body, '已有正文');
    expect(saved?.dueDate, expectedToday);
    expect(saved?.openDetails, isTrue);
  });

  testWidgets('task detail exposes stable editors and reminder lifecycle', (
    tester,
  ) async {
    final reminderAt = DateTime.now().add(const Duration(hours: 2));
    final taskId = (await tester.runAsync(
      () => controller.createTask(
        title: '核对提醒',
        dueDate: DateTime.now(),
        reminderAt: reminderAt,
      ),
    ))!;

    await tester.pumpWidget(
      _providerApp(
        container,
        TaskDetailPage(
          taskId: taskId,
          autosaveDelay: const Duration(milliseconds: 20),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(EditorPageFrame), findsOneWidget);
    expect(find.byKey(const Key('task-title-field')), findsOneWidget);
    expect(find.byKey(const Key('task-due-date-field')), findsOneWidget);
    expect(find.byKey(const Key('task-reminder-field')), findsOneWidget);
    expect(find.byKey(const Key('task-body-field')), findsOneWidget);
    expect(find.byKey(const Key('task-editor-toolbar')), findsOneWidget);
    expect(find.text('提醒已安排'), findsOneWidget);

    await tester.runAsync(() async {
      await database.customStatement(
        'UPDATE reminders SET status = ?, pause_reason = ? WHERE task_id = ?',
        <Object?>[
          ReminderStatus.permissionDenied.name,
          ReminderPauseReason.permissionDenied.name,
          taskId,
        ],
      );
      await controller.refresh();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('权限受限'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-reminder-open-settings')));
    await tester.pump();
    expect(settingsLauncher.openCount, 1);

    await tester.runAsync(() => controller.setTaskActive(taskId, false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('事项关闭'), findsOneWidget);

    await tester.runAsync(() async {
      await controller.setTaskActive(taskId, true);
      await database.customStatement(
        'UPDATE reminders SET scheduled_at_utc = ?, status = ?, '
        'pause_reason = NULL WHERE task_id = ?',
        <Object?>[
          DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .microsecondsSinceEpoch,
          ReminderStatus.expired.name,
          taskId,
        ],
      );
      await controller.refresh();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('提醒时间已过，不会补发。'), findsOneWidget);
  });

  testWidgets(
    'permission-denied reminder status fits a narrow large-text screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final taskId = (await tester.runAsync(
        () => controller.createTask(
          title: 'Large text reminder',
          reminderAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      ))!;
      await tester.runAsync(() async {
        await database.customStatement(
          'UPDATE reminders SET status = ?, pause_reason = ? WHERE task_id = ?',
          <Object?>[
            ReminderStatus.permissionDenied.name,
            ReminderPauseReason.permissionDenied.name,
            taskId,
          ],
        );
        await controller.refresh();
      });

      await tester.pumpWidget(
        _providerApp(
          container,
          TaskDetailPage(taskId: taskId),
          locale: const Locale('en'),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final status = find.byKey(const Key('task-reminder-status'));
      final settings = find.byKey(const Key('task-reminder-open-settings'));
      final label = find.text('Permission restricted; reminder time saved');
      expect(status, findsOneWidget);
      expect(settings, findsOneWidget);
      expect(label, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(settings);
      await tester.pump();
      final statusRect = tester.getRect(status);
      final settingsRect = tester.getRect(settings);
      final labelRect = tester.getRect(label);
      expect(statusRect.left, greaterThanOrEqualTo(0));
      expect(statusRect.right, lessThanOrEqualTo(320));
      expect(settingsRect.left, greaterThanOrEqualTo(statusRect.left));
      expect(settingsRect.right, lessThanOrEqualTo(statusRect.right));
      expect(settingsRect.top, greaterThanOrEqualTo(labelRect.bottom));
      expect(settingsRect.bottom, lessThanOrEqualTo(568));

      await tester.tap(settings);
      await tester.pump();
      expect(settingsLauncher.openCount, 1);
    },
  );

  testWidgets('task detail refuses to confirm a past reminder time', (
    tester,
  ) async {
    final taskId = (await tester.runAsync(
      () => controller.createTask(title: '不接受过去时间'),
    ))!;
    final fixedNow = DateTime(2026, 8, 23, 10, 2);
    await tester.pumpWidget(
      _providerApp(
        container,
        TaskDetailPage(taskId: taskId, now: () => fixedNow),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('task-reminder-field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final dialog = tester.widget<ReminderDialog>(find.byType(ReminderDialog));
    dialog.onConfirm(const TimeOfDay(hour: 10, minute: 0));
    await tester.pump();

    expect(find.byType(ReminderDialog), findsOneWidget);
    expect(find.text('提醒时间已过，不会补发。'), findsOneWidget);
    dialog.onCancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      container.read(appStoreProvider).requireValue.tasks.single.reminderAt,
      isNull,
    );
  });

  testWidgets(
    'task editor saves the reminder and surfaces a permission-query failure',
    (tester) async {
      final fixedNow = DateTime.now();
      final reminderAt = nextReminderTime(fixedNow)
          .add(const Duration(hours: 1));
      final taskId = (await tester.runAsync(
        () => controller.createTask(title: '权限失败仍保存'),
      ))!;
      notificationGateway.throwOnPermissionQuery = true;

      await tester.pumpWidget(
        _providerApp(
          container,
          TaskDetailPage(
            taskId: taskId,
            now: () => fixedNow,
            autosaveDelay: const Duration(milliseconds: 20),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('task-reminder-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final dialog = tester.widget<ReminderDialog>(find.byType(ReminderDialog));
      dialog.onConfirm(TimeOfDay.fromDateTime(reminderAt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (container
              .read(appStoreProvider)
              .requireValue
              .tasks
              .single
              .reminderStatus !=
          ReminderStatus.permissionDenied) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Permission-denied reminder state was not saved.');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      final task = container.read(appStoreProvider).requireValue.tasks.single;
      expect(task.reminderAt, reminderAt);
      expect(task.reminderPauseReason, ReminderPauseReason.permissionDenied);
      expect(find.textContaining('权限受限'), findsOneWidget);
      expect(
        find.byKey(const Key('task-reminder-open-settings')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('AppStore reads durable reminder status and pause reason', () async {
    final taskId = await controller.createTask(
      title: '状态数据',
      reminderAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(
      container.read(appStoreProvider).requireValue.tasks.single.reminderStatus,
      ReminderStatus.scheduled,
    );

    await controller.setTaskActive(taskId, false);
    final task = container.read(appStoreProvider).requireValue.tasks.single;
    expect(task.reminderStatus, ReminderStatus.paused);
    expect(task.reminderPauseReason, ReminderPauseReason.taskClosed);
  });

  test(
    'closing and reopening a task never revives a cancelled reminder',
    () async {
      final taskId = await controller.createTask(
        title: '取消后保持取消',
        reminderAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final created = container
          .read(appStoreProvider)
          .requireValue
          .tasks
          .single;
      await controller.updateTask(created.copyWith(reminderAt: null));

      final cancelledBeforeClose = await database
          .customSelect(
            'SELECT status FROM reminders WHERE task_id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingle();
      expect(
        cancelledBeforeClose.read<String>('status'),
        ReminderStatus.cancelled.name,
      );
      final jobsBeforeClose = await database
          .customSelect('SELECT COUNT(*) AS count FROM platform_jobs')
          .getSingle();

      await controller.setTaskActive(taskId, false);
      await controller.setTaskActive(taskId, true);

      final cancelledAfterReopen = await database
          .customSelect(
            'SELECT status FROM reminders WHERE task_id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingle();
      expect(
        cancelledAfterReopen.read<String>('status'),
        ReminderStatus.cancelled.name,
      );
      final jobsAfterReopen = await database
          .customSelect('SELECT COUNT(*) AS count FROM platform_jobs')
          .getSingle();
      expect(
        jobsAfterReopen.read<int>('count'),
        jobsBeforeClose.read<int>('count'),
      );
      final reopened = container
          .read(appStoreProvider)
          .requireValue
          .tasks
          .single;
      expect(reopened.reminderAt, isNull);
      expect(reopened.reminderStatus, isNull);
    },
  );

  test(
    'editing a closed task preserves its reminder pause until reopen',
    () async {
      final taskId = await controller.createTask(
        title: '关闭后编辑',
        reminderAt: DateTime.now().add(const Duration(hours: 2)),
      );
      await controller.setTaskActive(taskId, false);
      final closedTask = container
          .read(appStoreProvider)
          .requireValue
          .tasks
          .single;

      await controller.updateTask(closedTask.copyWith(body: '关闭时修改正文'));

      var reminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      expect(reminder.status, ReminderStatus.paused);
      expect(reminder.pauseReason, ReminderPauseReason.taskClosed);
      final closedEditJob =
          await (database.select(database.platformJobs)..where(
                (row) =>
                    row.aggregateRevision.equals(reminder.scheduleRevision),
              ))
              .getSingle();
      expect(closedEditJob.kind, PlatformJobKind.cancelReminder);

      await controller.setTaskActive(taskId, true);

      reminder = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      expect(reminder.status, ReminderStatus.scheduled);
      expect(reminder.pauseReason, isNull);
      final reopenJob =
          await (database.select(database.platformJobs)..where(
                (row) =>
                    row.aggregateRevision.equals(reminder.scheduleRevision),
              ))
              .getSingle();
      expect(reopenJob.kind, PlatformJobKind.scheduleReminder);
    },
  );

  test('task reminder mutations immediately update the platform and Undo restores it', () async {
    final firstTime = DateTime.now().add(const Duration(hours: 2));
    final taskId = await controller.createTask(
      title: '立即同步提醒',
      body: '可搜索正文',
      reminderAt: firstTime,
    );
    expect(notificationGateway.active, hasLength(1));

    final secondTime = firstTime.add(const Duration(hours: 1));
    var task = container.read(appStoreProvider).requireValue.tasks.single;
    await controller.updateTask(task.copyWith(reminderAt: secondTime));
    expect(
      notificationGateway.active.values.single.scheduledAtUtc,
      secondTime.toUtc(),
    );

    await controller.setTaskActive(taskId, false);
    expect(notificationGateway.active, isEmpty);
    await controller.setTaskActive(taskId, true);
    expect(notificationGateway.active, hasLength(1));

    await controller.deleteTask(taskId);
    expect(notificationGateway.active, isEmpty);
    var reminder = await (database.select(
      database.reminders,
    )..where((row) => row.taskId.equals(taskId))).getSingle();
    expect(reminder.status, ReminderStatus.paused);
    expect(reminder.pauseReason, ReminderPauseReason.user);
    expect(
      await database
          .customSelect(
            'SELECT scope FROM search_records WHERE scope = ? AND entity_id = ?',
            variables: <Variable<Object>>[
              Variable.withString(SearchScope.task.name),
              Variable.withString(taskId),
            ],
          )
          .get(),
      isEmpty,
    );

    await controller.restoreTask(taskId);
    expect(notificationGateway.active, hasLength(1));
    reminder = await (database.select(
      database.reminders,
    )..where((row) => row.taskId.equals(taskId))).getSingle();
    expect(reminder.status, ReminderStatus.scheduled);
    expect(reminder.pauseReason, isNull);
    final search = await database
        .customSelect(
          'SELECT title_norm, body_norm FROM search_records WHERE scope = ? '
          'AND entity_id = ?',
          variables: <Variable<Object>>[
            Variable.withString(SearchScope.task.name),
            Variable.withString(taskId),
          ],
        )
        .getSingle();
    expect(search.read<String>('title_norm'), '立即同步提醒');
    expect(search.read<String>('body_norm'), contains('可搜索正文'));

    task = container.read(appStoreProvider).requireValue.tasks.single;
    await controller.updateTask(task.copyWith(reminderAt: null));
    expect(notificationGateway.active, isEmpty);

    final archiveId = await controller.createTask(
      title: '归档取消提醒',
      reminderAt: DateTime.now().add(const Duration(hours: 4)),
    );
    expect(notificationGateway.active, hasLength(1));
    await controller.setTaskActive(archiveId, false);
    await controller.addTaskToPast(archiveId);
    expect(notificationGateway.active, isEmpty);
  });

  test('platform failures do not roll back committed reminder edits', () async {
    notificationGateway.throwOnInitialize = true;
    final taskId = await controller.createTask(
      title: '平台暂不可用',
      reminderAt: DateTime.now().add(const Duration(hours: 2)),
    );

    final task = container.read(appStoreProvider).requireValue.tasks.single;
    expect(task.id, taskId);
    expect(task.reminderAt, isNotNull);
    final pendingJob = await database.select(database.platformJobs).getSingle();
    expect(pendingJob.status, PlatformJobStatus.pending);

    notificationGateway.throwOnInitialize = false;
    await container.read(notificationCoordinatorProvider).reconcile();
    expect(notificationGateway.active, hasLength(1));
  });

  test('changing locale refreshes already scheduled platform copy', () async {
    await controller.saveSettings(
      const AppSettingsModel(localeMode: LocaleMode.en),
    );
    await controller.createTask(
      title: 'Locale reminder',
      reminderAt: DateTime.now().add(const Duration(hours: 2)),
    );
    final schedulesBefore = notificationGateway.scheduled.length;
    expect(notificationGateway.scheduled.last.body, 'Danggui task reminder');

    await controller.saveSettings(
      const AppSettingsModel(localeMode: LocaleMode.zhHans),
    );

    expect(notificationGateway.scheduled.length, greaterThan(schedulesBefore));
    expect(notificationGateway.scheduled.last.body, '当归事项提醒');
  });

  test('a stale snooze action cannot revive a cancelled reminder', () async {
    final taskId = await controller.createTask(
      title: '旧操作不可复活',
      reminderAt: DateTime.now().add(const Duration(hours: 2)),
    );
    final task = container.read(appStoreProvider).requireValue.tasks.single;
    await controller.updateTask(task.copyWith(reminderAt: null));

    final handled = await container
        .read(notificationCoordinatorProvider)
        .handleNotificationAction('danggui.snooze.10', 'task:$taskId');

    expect(handled, isFalse);
    expect(notificationGateway.active, isEmpty);
    final reminder = await (database.select(
      database.reminders,
    )..where((row) => row.taskId.equals(taskId))).getSingle();
    expect(reminder.status, ReminderStatus.cancelled);
  });

  testWidgets(
    'an external snooze survives a body-only save in an open task editor',
    (tester) async {
      final taskId = await tester.runAsync(
        () => controller.createTask(
          title: '稍后提醒合并',
          reminderAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      await tester.pumpWidget(
        _providerApp(
          container,
          TaskDetailPage(
            taskId: taskId!,
            autosaveDelay: const Duration(milliseconds: 20),
          ),
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        expect(
          await container
              .read(notificationCoordinatorProvider)
              .snoozeReminderForTask(taskId, minutes: 10),
          isTrue,
        );
        await controller.refresh();
      });
      await tester.pump();
      final snoozed = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();

      await tester.enterText(
        find.byKey(const Key('task-body-field')),
        '稍后提醒后编辑正文',
      );
      await tester.pump(const Duration(milliseconds: 30));
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (container.read(appStoreProvider).requireValue.tasks.single.body !=
          '稍后提醒后编辑正文') {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Body-only autosave did not finish.');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      final afterBodySave = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      expect(afterBodySave.scheduledAtUtc, snoozed.scheduledAtUtc);
      expect(afterBodySave.snoozedUntilUtc, snoozed.snoozedUntilUtc);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'title and plan edits refresh a snoozed notification without moving it',
    () async {
      final taskId = await controller.createTask(
        title: '旧通知标题',
        plan: '旧通知计划',
        reminderAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(
        await container
            .read(notificationCoordinatorProvider)
            .snoozeReminderForTask(taskId, minutes: 10),
        isTrue,
      );
      await controller.refresh();
      final before = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      final scheduleCallsBefore = notificationGateway.scheduled.length;
      final task = container.read(appStoreProvider).requireValue.tasks.single;

      await controller.updateTask(
        task.copyWith(title: '新通知标题', plan: '新通知计划'),
        updateReminder: false,
      );

      final after = await (database.select(
        database.reminders,
      )..where((row) => row.taskId.equals(taskId))).getSingle();
      expect(after.scheduledAtUtc, before.scheduledAtUtc);
      expect(after.snoozedUntilUtc, before.snoozedUntilUtc);
      expect(
        notificationGateway.scheduled.length,
        greaterThan(scheduleCallsBefore),
      );
      final platformCopy = notificationGateway.active.values.single;
      expect(platformCopy.title, '新通知标题');
      expect(platformCopy.body, '新通知计划');
      expect(
        platformCopy.scheduledAtUtc.microsecondsSinceEpoch,
        before.scheduledAtUtc,
      );
    },
  );

  testWidgets(
    'cold-start notification reconcile refreshes the AppStore view model',
    (tester) async {
      await tester.runAsync(() async {
        final taskId = await controller.createTask(
          title: '冷启动权限恢复',
          reminderAt: DateTime.now().add(const Duration(hours: 2)),
        );
        await database.customStatement(
          'UPDATE reminders SET status = ?, pause_reason = ? WHERE task_id = ?',
          <Object?>[
            ReminderStatus.permissionDenied.name,
            ReminderPauseReason.permissionDenied.name,
            taskId,
          ],
        );
        await controller.refresh();
      });
      expect(
        container
            .read(appStoreProvider)
            .requireValue
            .tasks
            .single
            .reminderStatus,
        ReminderStatus.permissionDenied,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DangguiApp(),
        ),
      );
      await tester.pump();
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (container
              .read(appStoreProvider)
              .requireValue
              .tasks
              .single
              .reminderStatus !=
          ReminderStatus.scheduled) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('AppStore did not refresh after reconcile.');
        }
        // The application schedules its first reconciliation from a
        // post-frame callback. Keep advancing the widget tree while allowing
        // the real database and coordinator futures to finish.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(
        container
            .read(appStoreProvider)
            .requireValue
            .tasks
            .single
            .reminderPauseReason,
        isNull,
      );
      expect(notificationGateway.scheduled, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _FakeNotificationSettingsLauncher
    implements NotificationSettingsLauncher {
  int openCount = 0;

  @override
  Future<void> open() async {
    openCount++;
  }
}

final class _FakeNotificationGateway implements NotificationGateway {
  final List<LocalNotificationRequest> scheduled = <LocalNotificationRequest>[];
  final List<int> cancelled = <int>[];
  final Map<int, LocalNotificationRequest> active =
      <int, LocalNotificationRequest>{};
  bool throwOnInitialize = false;
  bool throwOnPermissionQuery = false;
  bool throwOnSchedule = false;
  bool throwOnCancel = false;

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'test';

  @override
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  }) async {
    if (throwOnInitialize) throw StateError('initialize failed');
  }

  @override
  Future<bool?> permissionsGranted() async {
    if (throwOnPermissionQuery) throw StateError('permission query failed');
    return true;
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<Set<int>> pendingNotificationIds() async => active.keys.toSet();

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    if (throwOnSchedule) throw StateError('schedule failed');
    scheduled.add(request);
    active[request.notificationId] = request;
  }

  @override
  Future<void> cancel(int notificationId) async {
    if (throwOnCancel) throw StateError('cancel failed');
    cancelled.add(notificationId);
    active.remove(notificationId);
  }
}

Widget _providerApp(
  ProviderContainer container,
  Widget home, {
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: _localizedApp(home, locale: locale, textScaler: textScaler),
  );
}

Widget _localizedApp(
  Widget home, {
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: DangguiTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
}
