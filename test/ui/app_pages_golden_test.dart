import 'dart:io';

import 'package:danggui/src/app.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/services/backup/automatic_backup_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final displayFont = FontLoader('DangguiDisplay')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf'));
    final deterministicSans = FontLoader('DangguiGoldenSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf'));
    final iconFont = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait(<Future<void>>[
      displayFont.load(),
      deterministicSans.load(),
      iconFont.load(),
    ]);
  });

  testWidgets('primary pages render and navigate as a complete offline app', (
    tester,
  ) async {
    await _configureView(tester);
    final database = DangguiDatabase(NativeDatabase.memory());
    await database.quickCheck();
    await database.customStatement(
      'UPDATE app_settings SET locale_mode = ? WHERE id = 1',
      <Object?>[LocaleMode.zhHans.name],
    );
    final automaticBackupDirectory = Directory.systemTemp.createTempSync(
      'danggui-golden-auto-backup-',
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        automaticBackupCoordinatorProvider.overrideWithValue(
          AutomaticBackupCoordinator(
            clock: DateTime.now,
            readSettings: () async =>
                const AppSettingsModel(autoBackupEnabled: false),
            readPassphrase: () async => null,
            readDirectory: () async => automaticBackupDirectory,
            createBackup: ({
              required passphrase,
              required kind,
              required outputDirectory,
            }) => throw StateError('Disabled automatic backup ran.'),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
      if (automaticBackupDirectory.existsSync()) {
        automaticBackupDirectory.deleteSync(recursive: true);
      }
    });
    final controller = container.read(appStoreProvider.notifier);
    await container.read(appStoreProvider.future);

    // Keep reminder fixtures in the future so this deterministic Golden test
    // remains valid long after the v1.0.0 release date.
    final now = DateTime(2099, 8, 22, 12);
    final sameDate = DateTime(now.year, now.month, now.day + 3);
    await controller.createTask(
      title: '核对新增引用，补充理论背景。',
      dueDate: sameDate,
      plan: '晚饭后开始，预计两个小时',
      body: '复核文献清单\n☐ 补上方法部分的出处',
      reminderAt: DateTime(sameDate.year, sameDate.month, sameDate.day, 19, 50),
    );
    final crossDate = DateTime(now.year, now.month, now.day + 6);
    await controller.createTask(
      title: '整理实验数据',
      dueDate: crossDate,
      reminderAt: crossDate.subtract(const Duration(days: 1, hours: 4)),
    );
    await controller.createTask(
      title: '购买实验记录本',
      dueDate: DateTime(now.year, now.month, now.day + 9),
    );

    const appKey = Key('full-app-golden');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: appKey,
          child: DangguiApp(sansFontFamily: 'DangguiGoldenSans'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('核对新增引用，补充理论背景。'), findsOneWidget);
    expect(find.textContaining('19:50'), findsOneWidget);
    expect(find.textContaining('提醒'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(appKey),
      matchesGoldenFile('goldens/full_tasks_page.png'),
    );

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('显示'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(appKey),
      matchesGoldenFile('goldens/full_settings_page.png'),
    );

    await tester.scrollUntilVisible(
      find.text('帮助与操作指南'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('settings-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('帮助与操作指南'));
    await tester.pumpAndSettle();
    expect(find.text('搜索操作方法'), findsOneWidget);
    expect(find.textContaining('事项'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(appKey),
      matchesGoldenFile('goldens/full_help_page.png'),
    );
  });
}

Future<void> _configureView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
