import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/main.dart' as app;
import 'package:danggui/src/app.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/launch/startup_page.dart';
import 'package:danggui/src/features/notes/notes_page.dart';
import 'package:danggui/src/features/past/past_page.dart';
import 'package:danggui/src/features/settings/settings_page.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/readme_screenshot_support.dart';

const _locale = String.fromEnvironment(
  'README_SCREENSHOT_LOCALE',
  defaultValue: 'en',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture deterministic README product screenshots', (
    tester,
  ) async {
    expect(
      readmeScreenshotLocales,
      contains(_locale),
      reason: 'README_SCREENSHOT_LOCALE must be zh or en.',
    );
    final fixture = ReadmeScreenshotFixture.forLocale(_locale);

    // Exercise the production entry point, database, services, router and UI.
    // Screenshot mode keeps the real startup composition visible until this
    // test explicitly advances to Tasks.
    app.main();
    await waitForReadmeScreenshotFinder(
      tester,
      find.byType(StartupPage),
      phase: 'production cold start',
      timeout: const Duration(seconds: 40),
    );
    final startupContext = tester.element(find.byType(StartupPage));
    final container = ProviderScope.containerOf(startupContext);
    await waitForReadmeScreenshotCondition(
      tester,
      () => container.read(appStoreProvider).hasValue,
      phase: 'local store initialization',
      timeout: const Duration(seconds: 40),
    );
    final controller = container.read(appStoreProvider.notifier);
    final database = await container.read(databaseProvider.future);

    expect(
      container.read(appStoreProvider).requireValue.tasks,
      isEmpty,
      reason: 'The screenshot emulator must start with an empty app database.',
    );
    expect(
      container.read(appStoreProvider).requireValue.notes,
      isEmpty,
      reason: 'The screenshot emulator must not contain personal notes.',
    );

    await controller.saveSettings(
      AppSettingsModel(
        localeMode: _locale == 'zh' ? LocaleMode.zhHans : LocaleMode.en,
        fontMode: FontMode.sans,
        textScalePercent: 100,
        density: DisplayDensity.loose,
        defaultSoundEnabled: false,
        defaultVibrationEnabled: false,
        defaultSnoozeMinutes: 10,
        autoBackupEnabled: false,
        autoBackupHourLocal: 2,
        autoBackupMinuteLocal: 0,
        backupEncryptionEnabled: false,
        helpSeenVersion: 0,
      ),
    );
    await waitForReadmeScreenshotCondition(
      tester,
      () =>
          Localizations.localeOf(tester.element(find.byType(StartupPage)))
              .languageCode ==
          _locale,
      phase: 'explicit screenshot locale',
    );

    final seeded = await _seedSyntheticWorkflow(
      container,
      controller,
      fixture,
      database,
    );

    // Android renders Flutter on a SurfaceView by default. Convert it once so
    // IntegrationTestWidgetsFlutterBinding can return actual device PNGs.
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 400));

    final router = container.read(routerProvider);
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.startup,
      readyWhen: find.byKey(
        const ValueKey<String>('startup-watercolor-decoded-frame'),
      ),
      phase: 'branded startup',
    );
    expect(find.byType(StartupPage), findsOneWidget);

    router.go('/tasks');
    await tester.pump();
    await waitForReadmeScreenshotFinder(
      tester,
      find.text(fixture.reminderTaskTitle),
      phase: 'seeded task list',
    );
    await waitForReadmeScreenshotCondition(
      tester,
      () => find.byType(StartupPage).evaluate().isEmpty,
      phase: 'startup route disposal',
    );
    expect(find.textContaining('19:30'), findsAtLeastNWidgets(1));
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.tasksReminders,
      readyWhen: find.byType(TasksPage),
      phase: 'tasks and reminder',
    );

    router.go('/tasks/${seeded.detailTaskId}');
    await tester.pump();
    await waitForReadmeScreenshotFinder(
      tester,
      find.byType(TaskDetailPage),
      phase: 'task detail route',
    );
    expect(
      _textFieldValue(tester, const Key('task-title-field')),
      fixture.detailTaskTitle,
    );
    expect(
      _textFieldValue(tester, const Key('task-plan-field')),
      fixture.detailTaskPlan,
    );
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.taskDetail,
      readyWhen: find.byKey(const Key('task-body-field')),
      phase: 'task detail',
      stabilizeFor: const Duration(milliseconds: 500),
    );

    router.go('/past');
    await tester.pump();
    await waitForReadmeScreenshotFinder(
      tester,
      find.byType(PastPage),
      phase: 'Past route',
    );
    await waitForReadmeScreenshotCondition(
      tester,
      () => find.byType(TaskDetailPage).evaluate().isEmpty,
      phase: 'task detail route disposal',
    );
    expect(
      _textFieldValue(tester, const Key('past-continuous-document-editor')),
      contains('2032-05-12'),
    );
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.past,
      readyWhen: find.byKey(const Key('past-continuous-document-editor')),
      phase: 'Past workflow',
    );

    router.go('/notes');
    await tester.pump();
    await waitForReadmeScreenshotFinder(
      tester,
      find.text(fixture.firstNoteTitle),
      phase: 'seeded notes',
    );
    expect(find.text(fixture.primaryFolder), findsOneWidget);
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.notes,
      readyWhen: find.byType(NotesPage),
      phase: 'notes workflow',
    );

    router.go('/settings');
    await tester.pump();
    await waitForReadmeScreenshotFinder(
      tester,
      find.byType(SettingsPage),
      phase: 'settings route',
    );
    final settingsContext = tester.element(find.byType(SettingsPage));
    final l10n = AppLocalizations.of(settingsContext);
    final settingsScrollable = find.descendant(
      of: find.byKey(const PageStorageKey<String>('settings-list')),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      find.text(l10n.exportAllData),
      280,
      scrollable: settingsScrollable,
    );
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.exportSettings,
      readyWhen: find.text(l10n.exportAllData),
      phase: 'data export settings',
    );

    await tester.scrollUntilVisible(
      find.text(l10n.privacy),
      280,
      scrollable: settingsScrollable,
    );
    expect(find.text(l10n.localOnlySummary), findsOneWidget);
    await captureReadmeScreenshot(
      binding,
      tester,
      locale: _locale,
      frame: ReadmeScreenshotFrame.privacySettings,
      readyWhen: find.text(l10n.privacy),
      phase: 'privacy settings',
    );
  });
}

Future<_SeededWorkflow> _seedSyntheticWorkflow(
  ProviderContainer container,
  AppStoreController controller,
  ReadmeScreenshotFixture fixture,
  DangguiDatabase database,
) async {
  await controller.createTask(
    title: fixture.reminderTaskTitle,
    dueDate: DateTime(2032, 5, 18),
    reminderAt: DateTime(2032, 5, 18, 19, 30),
    plan: fixture.reminderTaskPlan,
    body: fixture.reminderTaskBody,
    soundEnabled: false,
    vibrationEnabled: false,
  );
  final detailTaskId = await controller.createTask(
    title: fixture.detailTaskTitle,
    dueDate: DateTime(2032, 5, 21),
    plan: fixture.detailTaskPlan,
    body: fixture.detailTaskBody,
  );
  await controller.createTask(
    title: fixture.thirdTaskTitle,
    dueDate: DateTime(2032, 5, 19),
  );

  final primaryFolderId = await controller.createFolder(fixture.primaryFolder);
  final secondaryFolderId = await controller.createFolder(
    fixture.secondaryFolder,
  );
  final firstNoteId = await controller.createNote(
    title: fixture.firstNoteTitle,
    body: fixture.firstNoteBody,
    folderId: primaryFolderId,
  );
  final secondNoteId = await controller.createNote(
    title: fixture.secondNoteTitle,
    body: fixture.secondNoteBody,
    folderId: primaryFolderId,
  );
  final thirdNoteId = await controller.createNote(
    title: fixture.thirdNoteTitle,
    body: fixture.thirdNoteBody,
    folderId: secondaryFolderId,
  );
  await controller.replacePastDocumentText(fixture.pastDocument);

  final noteDates = <String, DateTime>{
    firstNoteId: DateTime.utc(2032, 5, 15, 9),
    secondNoteId: DateTime.utc(2032, 5, 14, 18, 30),
    thirdNoteId: DateTime.utc(2032, 5, 13, 7, 45),
  };
  for (final entry in noteDates.entries) {
    await database.customStatement(
      'UPDATE notes SET updated_at_utc = ?, pinned_at_utc = ? WHERE id = ?',
      <Object?>[
        entry.value.microsecondsSinceEpoch,
        entry.key == firstNoteId ? entry.value.microsecondsSinceEpoch : null,
        entry.key,
      ],
    );
  }
  await controller.refresh();
  expect(container.read(appStoreProvider).requireValue.tasks, hasLength(3));
  expect(container.read(appStoreProvider).requireValue.notes, hasLength(3));
  return _SeededWorkflow(detailTaskId: detailTaskId);
}

String _textFieldValue(WidgetTester tester, Key key) {
  final field = tester.widget<TextField>(find.byKey(key));
  expect(field.controller, isNotNull);
  return field.controller!.text;
}

final class _SeededWorkflow {
  const _SeededWorkflow({required this.detailTaskId});

  final String detailTaskId;
}
