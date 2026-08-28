import 'dart:io';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/settings/settings_page.dart';
import 'package:danggui/src/services/backup/backup_service.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => database)],
    );
    await container.read(appStoreProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('app store persists locale and automatic backup time', () async {
    const changed = AppSettingsModel(
      localeMode: LocaleMode.en,
      autoBackupHourLocal: 4,
      autoBackupMinuteLocal: 35,
    );

    await container.read(appStoreProvider.notifier).saveSettings(changed);

    final settings = container.read(appStoreProvider).requireValue.settings;
    expect(settings.localeMode, LocaleMode.en);
    expect(settings.autoBackupHourLocal, 4);
    expect(settings.autoBackupMinuteLocal, 35);
  });

  test('dismissed manual backup share is never reported as created', () {
    expect(
      manualBackupShareWasAccepted(
        const ShareResult('', ShareResultStatus.dismissed),
      ),
      isFalse,
    );
    expect(manualBackupShareWasAccepted(null), isFalse);
    expect(
      manualBackupShareWasAccepted(
        const ShareResult('save-to-files', ShareResultStatus.success),
      ),
      isTrue,
    );
    expect(manualBackupShareWasAccepted(ShareResult.unavailable), isTrue);
  });

  testWidgets('shows the 1.1.5 product version without build metadata', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _settingsApp(
        container,
        const SettingsPage(loadLatestBackupStatus: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _scrollToText(tester, '关于当归', maximumDrags: 20);
    expect(find.text('帮助与隐私'), findsOneWidget);
    expect(find.text('版本 1.1.5'), findsOneWidget);
    expect(find.textContaining('1.1.5+6'), findsNothing);
  });

  testWidgets('shows complete settings and exposes every locale choice', (
    tester,
  ) async {
    _setPhoneSize(tester);

    await tester.pumpWidget(
      _settingsApp(
        container,
        const SettingsPage(loadLatestBackupStatus: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('显示'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);

    await tester.tap(find.text('语言'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('exact settings failure does not report notification denial', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final gateway = _ExactRequestFailureGateway();
    final coordinator = NotificationCoordinator(
      () async => database,
      gateway: gateway,
    );
    final settingsContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        notificationCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(() {
      settingsContainer.dispose();
      coordinator.dispose();
    });
    await settingsContainer.read(appStoreProvider.future);
    await tester.pumpWidget(
      _settingsApp(
        settingsContainer,
        const SettingsPage(loadLatestBackupStatus: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _scrollToText(tester, '闹钟权限检查');
    await tester.tap(find.text('闹钟权限检查'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('未开启精确提醒权限'), findsOneWidget);
    expect(find.textContaining('通知已被禁用'), findsNothing);
    expect(gateway.exactPermissionRequests, 1);
  });

  testWidgets('backup action is operational through its injectable seam', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var backupCreated = false;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onCreateBackup: () async => backupCreated = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final createBackup = find.text('立即创建备份');
    await tester.drag(
      find.byKey(const PageStorageKey<String>('settings-list')),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(createBackup, findsOneWidget);
    await tester.tap(createBackup);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(backupCreated, isTrue);
    expect(find.text('备份已创建'), findsOneWidget);
  });

  testWidgets('shows an honest empty latest-backup state', (tester) async {
    _setPhoneSize(tester);
    final latestBackupSubscription = await _preloadLatestBackup(
      tester,
      container,
    );
    await tester.pumpWidget(_settingsApp(container, const SettingsPage()));
    await tester.pump();
    latestBackupSubscription.close();

    await _scrollToText(tester, '最近一次备份');

    expect(find.text('尚无备份记录'), findsOneWidget);
  });

  testWidgets('shows latest successful backup status from the database', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final completed = DateTime.utc(2026, 8, 22, 10, 30);
    await tester.runAsync(
      () => _insertBackupRun(
        database,
        id: 'backup-success',
        kind: 'manual',
        status: 'succeeded',
        completedAt: completed,
      ),
    );
    final latestBackupSubscription = await _preloadLatestBackup(
      tester,
      container,
    );
    await tester.pumpWidget(_settingsApp(container, const SettingsPage()));
    await tester.pump();
    latestBackupSubscription.close();

    await _scrollToText(tester, '最近一次备份');

    expect(find.textContaining('成功 · 手动 ·'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets(
    'shows a newer failed automatic backup without inventing success',
    (tester) async {
      _setPhoneSize(tester);
      await tester.runAsync(() async {
        await _insertBackupRun(
          database,
          id: 'backup-success-old',
          kind: 'manual',
          status: 'succeeded',
          completedAt: DateTime.utc(2026, 8, 21, 10),
        );
        await _insertBackupRun(
          database,
          id: 'backup-failed-new',
          kind: 'daily',
          status: 'failed',
          completedAt: DateTime.utc(2026, 8, 22, 10),
        );
      });
      final latestBackupSubscription = await _preloadLatestBackup(
        tester,
        container,
      );
      await tester.pumpWidget(_settingsApp(container, const SettingsPage()));
      await tester.pump();
      latestBackupSubscription.close();

      await _scrollToText(tester, '最近一次备份');

      expect(find.textContaining('失败 · 每日自动 ·'), findsOneWidget);
      expect(find.textContaining('成功 · 手动 ·'), findsNothing);
    },
  );

  testWidgets(
    'encryption is off by default and requires explicit confirmation',
    (tester) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(
        _settingsApp(
          container,
          const SettingsPage(loadLatestBackupStatus: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final encryption = find.text('备份加密');
      await tester.drag(
        find.byKey(const PageStorageKey<String>('settings-list')),
        const Offset(0, -620),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(encryption, findsOneWidget);
      expect(
        container
            .read(appStoreProvider)
            .requireValue
            .settings
            .backupEncryptionEnabled,
        isFalse,
      );

      final settingsTile = find.ancestor(
        of: encryption,
        matching: find.byType(SettingsTile),
      );
      final toggle = find.descendant(
        of: settingsTile,
        matching: find.byType(DangguiSwitch),
      );
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('加密密码不会上传或找回'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        container
            .read(appStoreProvider)
            .requireValue
            .settings
            .backupEncryptionEnabled,
        isFalse,
      );
    },
  );

  testWidgets('inspects backup and cancellation never restores', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var inspectCalls = 0;
    var restoreCalls = 0;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('selected.dgbak'),
          onInspectBackup: (source, {passphrase}) async {
            inspectCalls += 1;
            return _inspection();
          },
          onRestoreBackupFile:
              (source, {passphrase, mode = RestoreMode.replace}) async {
                restoreCalls += 1;
                return _restoreResult(mode);
              },
          onReconcileNotifications: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);

    expect(find.text('检查备份'), findsOneWidget);
    expect(find.text('应用版本'), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    expect(find.text('事项'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(inspectCalls, 1);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(restoreCalls, 0);
    expect(find.text('备份已恢复'), findsNothing);
  });

  testWidgets('passes merge mode and refreshes before showing success', (
    tester,
  ) async {
    _setPhoneSize(tester);
    RestoreMode? receivedMode;
    var refreshed = false;
    var reconciled = false;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('selected.dgbak'),
          onInspectBackup: (source, {passphrase}) async => _inspection(),
          onRestoreBackupFile:
              (source, {passphrase, mode = RestoreMode.replace}) async {
                receivedMode = mode;
                return _restoreResult(mode);
              },
          onRefreshAfterRestore: () async => refreshed = true,
          onReconcileNotifications: () async {
            expect(refreshed, isTrue);
            reconciled = true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await tester.tap(find.byKey(const ValueKey<String>('restore-mode-merge')));
    await _pumpUntil(tester, () => reconciled);

    expect(receivedMode, RestoreMode.merge);
    expect(refreshed, isTrue);
    expect(reconciled, isTrue);
    expect(find.text('备份已恢复'), findsOneWidget);
  });

  testWidgets('replace mode requires a stronger second confirmation', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var restoreCalls = 0;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('selected.dgbak'),
          onInspectBackup: (source, {passphrase}) async => _inspection(),
          onRestoreBackupFile:
              (source, {passphrase, mode = RestoreMode.replace}) async {
                restoreCalls += 1;
                return _restoreResult(mode);
              },
          onReconcileNotifications: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('restore-mode-replace')),
    );
    await tester.pumpAndSettle();

    expect(find.text('确定覆盖当前数据？'), findsOneWidget);
    expect(restoreCalls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(restoreCalls, 0);
  });

  testWidgets('passes replace mode only after destructive confirmation', (
    tester,
  ) async {
    _setPhoneSize(tester);
    RestoreMode? receivedMode;
    var refreshed = false;
    var reconciled = false;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('selected.dgbak'),
          onInspectBackup: (source, {passphrase}) async => _inspection(),
          onRestoreBackupFile:
              (source, {passphrase, mode = RestoreMode.replace}) async {
                receivedMode = mode;
                return _restoreResult(mode);
              },
          onRefreshAfterRestore: () async => refreshed = true,
          onReconcileNotifications: () async {
            expect(refreshed, isTrue);
            reconciled = true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('restore-mode-replace')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-replace-restore')),
    );
    await _pumpUntil(tester, () => reconciled);

    expect(receivedMode, RestoreMode.replace);
    expect(refreshed, isTrue);
    expect(find.text('备份已恢复'), findsOneWidget);
  });

  testWidgets('restore failure never displays a success message', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var restoreAttempted = false;
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('selected.dgbak'),
          onInspectBackup: (source, {passphrase}) async => _inspection(),
          onRestoreBackupFile:
              (source, {passphrase, mode = RestoreMode.replace}) async {
                restoreAttempted = true;
                throw StateError('restore failed');
              },
          onReconcileNotifications: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await tester.tap(find.byKey(const ValueKey<String>('restore-mode-merge')));
    await _pumpUntil(
      tester,
      () =>
          restoreAttempted &&
          find.textContaining('备份恢复失败').evaluate().isNotEmpty,
    );

    expect(find.textContaining('备份恢复失败'), findsOneWidget);
    expect(find.textContaining('restore failed'), findsNothing);
    expect(find.text('备份已恢复'), findsNothing);
  });

  const damagedBackupCases = <(Locale, String, String)>[
    (Locale('zh'), '从备份恢复', '备份文件已损坏或内容不完整'),
    (
      Locale('en'),
      'Restore from backup',
      'This backup is damaged or incomplete',
    ),
    (Locale('ja'), 'バックアップから復元', 'バックアップが破損または不完全'),
    (
      Locale('ru'),
      'Восстановить из копии',
      'Резервная копия повреждена или неполна',
    ),
  ];
  for (final testCase in damagedBackupCases) {
    testWidgets('${testCase.$1.languageCode} localizes damaged backup errors', (
      tester,
    ) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(
        _settingsApp(
          container,
          SettingsPage(
            loadLatestBackupStatus: false,
            onPickBackup: () async => File('damaged.dgbak'),
            onInspectBackup: (source, {passphrase}) async =>
                throw const FormatException('Backup archive is damaged.'),
          ),
          locale: testCase.$1,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await _openRestore(tester, label: testCase.$2);
      await _pumpUntil(
        tester,
        () => find.textContaining(testCase.$3).evaluate().isNotEmpty,
      );

      expect(find.textContaining(testCase.$3), findsOneWidget);
      expect(find.textContaining('Backup archive is damaged'), findsNothing);
    });
  }

  testWidgets('incompatible backup error is classified and localized', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('foreign.dgbak'),
          onInspectBackup: (source, {passphrase}) async =>
              throw const FormatException('Backup belongs to a different app.'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await _pumpUntil(
      tester,
      () => find.textContaining('该备份不属于当归').evaluate().isNotEmpty,
    );

    expect(find.textContaining('该备份不属于当归'), findsOneWidget);
    expect(find.textContaining('different app'), findsNothing);
    expect(find.text('备份已恢复'), findsNothing);
  });

  testWidgets('wrong backup password stays in a localized retry flow', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(
      _settingsApp(
        container,
        SettingsPage(
          loadLatestBackupStatus: false,
          onPickBackup: () async => File('encrypted.dgbak'),
          onInspectBackup: (source, {passphrase}) async {
            if (passphrase == null) {
              throw const FormatException('This backup requires a passphrase.');
            }
            throw const FormatException(
              'Passphrase is wrong or backup is damaged.',
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _openRestore(tester);
    await tester.enterText(find.byType(TextField).last, 'wrong-passphrase');
    await tester.tap(find.text('确定').last);
    await _pumpUntil(
      tester,
      () => find.textContaining('密码不正确，或加密备份已损坏').evaluate().isNotEmpty,
    );

    expect(find.textContaining('密码不正确，或加密备份已损坏'), findsOneWidget);
    expect(find.textContaining('Passphrase is wrong'), findsNothing);
    expect(find.text('备份已恢复'), findsNothing);
  });
}

Future<ProviderSubscription<AsyncValue<LatestBackupRun?>>> _preloadLatestBackup(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late ProviderSubscription<AsyncValue<LatestBackupRun?>> subscription;
  await tester.runAsync(() async {
    subscription = container.listen(
      latestBackupRunProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    await container
        .read(latestBackupRunProvider.future)
        .timeout(const Duration(seconds: 5));
  });
  return subscription;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; !condition() && attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
  await tester.pumpAndSettle();
}

Future<void> _openRestore(WidgetTester tester, {String label = '从备份恢复'}) async {
  await _scrollToText(tester, label);
  final restore = find.text(label);
  await tester.tap(restore);
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(
  WidgetTester tester,
  String text, {
  int maximumDrags = 8,
}) async {
  final target = find.text(text);
  final list = find.byKey(const PageStorageKey<String>('settings-list'));
  for (
    var attempt = 0;
    target.evaluate().isEmpty && attempt < maximumDrags;
    attempt++
  ) {
    await tester.drag(list, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _insertBackupRun(
  DangguiDatabase database, {
  required String id,
  required String kind,
  required String status,
  required DateTime completedAt,
}) {
  final micros = completedAt.toUtc().microsecondsSinceEpoch;
  return database.customStatement(
    'INSERT INTO backup_runs '
    '(id, kind, status, app_version, database_schema_version, '
    'manifest_version, started_at_utc, completed_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[id, kind, status, '1.0.0+1', 1, 1, micros - 1000, micros],
  );
}

BackupInspection _inspection() {
  return const BackupInspection(
    manifest: <String, Object?>{
      'appVersion': '1.0.0+1',
      'databaseSchemaVersion': 1,
      'createdAtUtc': '2026-08-22T10:30:00.000Z',
    },
    recordCounts: <String, int>{
      'tasks': 3,
      'notes': 2,
      'folders': 1,
      'document_blocks': 8,
      'past_events': 1,
      'reminders': 2,
      'trash_entries': 0,
    },
    encrypted: true,
    archiveSha256:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  );
}

RestoreResult _restoreResult(RestoreMode mode) {
  return RestoreResult(
    manifest: const <String, Object?>{'databaseSchemaVersion': 1},
    safetyCopy: File('safety.sqlite'),
    encrypted: true,
    mode: mode,
  );
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _settingsApp(
  ProviderContainer container,
  Widget home, {
  Locale locale = const Locale('zh'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: DangguiTheme.light(),
      home: home,
    ),
  );
}

final class _ExactRequestFailureGateway
    implements NotificationGateway, ReminderCapabilityGateway {
  int exactPermissionRequests = 0;

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'test';

  @override
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  }) async {}

  @override
  Future<bool?> permissionsGranted() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<ReminderDeliveryCapabilities> deliveryCapabilities({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async => const ReminderDeliveryCapabilities(
    notificationsGranted: true,
    exactSchedulingAvailable: false,
    exactAlarmPermissionRequired: true,
    soundAvailable: true,
    vibrationAvailable: true,
    vibrationControlledBySystem: false,
  );

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactPermissionRequests++;
    throw StateError('settings unavailable');
  }

  @override
  Future<Set<int>> pendingNotificationIds() async => const <int>{};

  @override
  Future<void> schedule(LocalNotificationRequest request) async {}

  @override
  Future<void> cancel(int notificationId) async {}
}
