import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/main.dart' as app;
import 'package:danggui/src/features/notes/notes_page.dart';
import 'package:danggui/src/features/past/past_page.dart';
import 'package:danggui/src/features/settings/help_page.dart';
import 'package:danggui/src/features/settings/settings_page.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start exposes all primary areas and offline help', (
    tester,
  ) async {
    // Calling the production entry point exercises the real database, plugin
    // registrations, startup reconciliation, router, and launch transition.
    app.main();

    await _waitFor(
      tester,
      find.byType(TasksPage),
      phase: 'production cold start',
      timeout: const Duration(seconds: 40),
    );
    _expectNoUnhandledException(tester, 'production cold start');

    final initialNav = tester.widget<DangguiBottomNav>(
      find.byType(DangguiBottomNav),
    );
    expect(initialNav.destinations, hasLength(4));
    expect(
      initialNav.destinations.map((destination) => destination.label).toSet(),
      hasLength(4),
      reason: 'Every primary destination must have a distinct localized label.',
    );
    expect(initialNav.currentIndex, 0);

    await _openDestination(tester, index: 1, page: find.byType(PastPage));
    await _openDestination(tester, index: 2, page: find.byType(NotesPage));
    await _openDestination(tester, index: 3, page: find.byType(SettingsPage));

    final settingsContext = tester.element(find.byType(SettingsPage));
    final localizations = AppLocalizations.of(settingsContext);
    final helpEntry = find.text(localizations.helpTitle);
    await _scrollUntilVisible(
      tester,
      helpEntry,
      scrollable: find.byType(ListView),
      phase: 'offline help entry',
    );
    await tester.tap(helpEntry.hitTestable());
    await tester.pump();

    await _waitFor(
      tester,
      find.byType(HelpPage),
      phase: 'offline help route',
      timeout: const Duration(seconds: 12),
    );
    await _waitFor(
      tester,
      find.byType(SelectionArea),
      phase: 'bundled offline help document',
      timeout: const Duration(seconds: 12),
    );

    final helpContext = tester.element(find.byType(HelpPage));
    final helpLocalizations = AppLocalizations.of(helpContext);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == helpLocalizations.helpSearchHint,
      ),
      findsOneWidget,
    );
    _expectNoUnhandledException(tester, 'offline help rendering');
  });
}

Future<void> _openDestination(
  WidgetTester tester, {
  required int index,
  required Finder page,
}) async {
  final navFinder = find.byType(DangguiBottomNav);
  final nav = tester.widget<DangguiBottomNav>(navFinder);
  final destinationLabel = nav.destinations[index].label;
  final destination = find.descendant(
    of: navFinder,
    matching: find.text(destinationLabel),
  );

  expect(destination.hitTestable(), findsOneWidget);
  await tester.tap(destination.hitTestable());
  await tester.pump();
  await _waitFor(
    tester,
    page,
    phase: 'primary destination $index',
    timeout: const Duration(seconds: 12),
  );

  final updatedNav = tester.widget<DangguiBottomNav>(navFinder);
  expect(updatedNav.currentIndex, index);
  _expectNoUnhandledException(tester, 'primary destination $index');
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder target, {
  required Finder scrollable,
  required String phase,
  int maximumDrags = 12,
}) async {
  for (var attempt = 0; attempt <= maximumDrags; attempt += 1) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    if (attempt == maximumDrags) break;

    expect(
      scrollable.hitTestable(),
      findsAtLeastNWidgets(1),
      reason: '$phase requires a visible scrollable.',
    );
    await tester.drag(scrollable.hitTestable().first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 250));
    _expectNoUnhandledException(tester, '$phase scroll ${attempt + 1}');
  }

  fail('$phase was not reachable after $maximumDrags bounded drags.');
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  required String phase,
  required Duration timeout,
}) async {
  const pollingInterval = Duration(milliseconds: 200);
  final maximumPumps = (timeout.inMicroseconds / pollingInterval.inMicroseconds)
      .ceil();
  for (var attempt = 0; attempt < maximumPumps; attempt += 1) {
    if (finder.evaluate().isNotEmpty) break;
    await tester.pump(pollingInterval);
    _expectNoUnhandledException(tester, phase);
  }

  expect(
    finder,
    findsOneWidget,
    reason: '$phase did not complete within ${timeout.inSeconds} seconds.',
  );
}

void _expectNoUnhandledException(WidgetTester tester, String phase) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'An unhandled Flutter exception occurred during $phase.',
  );
}
