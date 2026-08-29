import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/main.dart' as app;
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/features/notes/note_editor_page.dart';
import 'package:danggui/src/features/notes/notes_page.dart';
import 'package:danggui/src/features/past/past_page.dart';
import 'package:danggui/src/features/settings/help_page.dart';
import 'package:danggui/src/features/settings/settings_page.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start exposes all primary areas and offline help', (
    tester,
  ) async {
    final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(
      () =>
          WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy,
    );
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

    await _exerciseProductionEditors(tester);

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

Future<void> _exerciseProductionEditors(WidgetTester tester) async {
  final runToken = DateTime.now().microsecondsSinceEpoch;
  final taskTitle = 'IME task $runToken';
  final taskBody = 'Task body persisted through a real keyboard route.';
  final noteTitle = 'IME note $runToken';
  final noteBody = 'Note body persisted through a real keyboard route.';
  final pastMarker = 'Past editor IME marker $runToken';

  final taskListContext = tester.element(find.byType(TasksPage));
  final providerContainer = ProviderScope.containerOf(taskListContext);
  final taskL10n = AppLocalizations.of(taskListContext);
  final addTask = find.bySemanticsLabel(taskL10n.addTask).hitTestable();
  expect(addTask, findsAtLeastNWidgets(1));
  await tester.tap(addTask.first);
  await tester.pump();
  final creationTitle = find.byKey(const Key('task-creation-title'));
  await _waitFor(
    tester,
    creationTitle,
    phase: 'task creation sheet',
    timeout: const Duration(seconds: 12),
  );
  await _waitForIme(tester, creationTitle, visible: true);
  await tester.enterText(creationTitle, taskTitle);
  final moreSettings = find.byKey(const Key('task-creation-more-settings'));
  await tester.ensureVisible(moreSettings);
  await tester.pump(const Duration(milliseconds: 200));
  expect(moreSettings.hitTestable(), findsOneWidget);
  await tester.tap(moreSettings.hitTestable());
  await tester.pump();
  await _waitFor(
    tester,
    find.byType(TaskDetailPage),
    phase: 'task detail from quick creation',
    timeout: const Duration(seconds: 15),
  );

  final taskBodyField = find.byKey(const Key('task-body-field'));
  await tester.ensureVisible(taskBodyField);
  await tester.pump(const Duration(milliseconds: 250));
  await _tapEditable(tester, taskBodyField, phase: 'task body focus');
  await _waitForIme(tester, taskBodyField, visible: true);
  await tester.enterText(taskBodyField, taskBody);
  await tester.pump();
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('task-editor-toolbar')),
    phase: 'task editor with IME',
    imeVisible: true,
  );
  await _hideImeAndVerifyReset(tester, taskBodyField);
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('task-editor-toolbar')),
    phase: 'task editor after IME dismissal',
    imeVisible: false,
  );
  await _tapEditorBack(tester, phase: 'task editor save and close');
  await _waitForCondition(
    tester,
    () => find.byType(TaskDetailPage).evaluate().isEmpty,
    phase: 'task detail route closing after save',
    timeout: const Duration(seconds: 15),
  );

  await _waitForCondition(
    tester,
    () =>
        providerContainer
            .read(appStoreProvider)
            .value
            ?.tasks
            .any((task) => task.title == taskTitle && task.body == taskBody) ??
        false,
    phase: 'saved task state',
    timeout: const Duration(seconds: 12),
  );
  final savedTask = providerContainer
      .read(appStoreProvider)
      .requireValue
      .tasks
      .singleWhere((task) => task.title == taskTitle);
  final taskCardRoot = find.byKey(ValueKey<String>(savedTask.id));
  await _waitFor(
    tester,
    taskCardRoot,
    phase: 'saved task card mounted',
    timeout: const Duration(seconds: 12),
  );
  await tester.ensureVisible(taskCardRoot);
  await tester.pump(const Duration(milliseconds: 250));
  final taskCard = find
      .descendant(of: taskCardRoot, matching: find.byType(SketchCard))
      .hitTestable();
  await _waitFor(
    tester,
    taskCard,
    phase: 'saved task card interaction',
    timeout: const Duration(seconds: 12),
  );
  await tester.tap(taskCard);
  await tester.pump();
  await _waitFor(
    tester,
    find.byType(TaskDetailPage),
    phase: 'reopened task detail',
    timeout: const Duration(seconds: 12),
  );
  expect(_textFieldValue(tester, taskBodyField), taskBody);
  await _tapEditorBack(tester, phase: 'reopened task detail close');
  await _waitForCondition(
    tester,
    () => find.byType(TaskDetailPage).evaluate().isEmpty,
    phase: 'reopened task detail route closing',
    timeout: const Duration(seconds: 12),
  );

  await _openDestination(tester, index: 2, page: find.byType(NotesPage));
  final notesContext = tester.element(find.byType(NotesPage));
  final notesL10n = AppLocalizations.of(notesContext);
  final addNote = find.bySemanticsLabel(notesL10n.newNote).hitTestable();
  expect(addNote, findsOneWidget);
  await tester.tap(addNote);
  await tester.pump();
  await _waitFor(
    tester,
    find.byType(NoteEditorPage),
    phase: 'new note editor',
    timeout: const Duration(seconds: 12),
  );

  final noteTitleField = find.byKey(const Key('note-editor-title'));
  await _tapEditable(tester, noteTitleField, phase: 'note title focus');
  await _waitForIme(tester, noteTitleField, visible: true);
  await tester.enterText(noteTitleField, noteTitle);
  final noteBodyField = find.byKey(const Key('note-editor-body'));
  await tester.ensureVisible(noteBodyField);
  await tester.pump(const Duration(milliseconds: 250));
  await _tapEditable(tester, noteBodyField, phase: 'note body focus');
  await _waitForIme(tester, noteBodyField, visible: true);
  await tester.enterText(noteBodyField, noteBody);
  await tester.pump();
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('note-editor-toolbar')),
    phase: 'note editor with IME',
    imeVisible: true,
  );
  await _hideImeAndVerifyReset(tester, noteBodyField);
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('note-editor-toolbar')),
    phase: 'note editor after IME dismissal',
    imeVisible: false,
  );
  await _tapEditorBack(tester, phase: 'note editor save and close');
  await _waitForCondition(
    tester,
    () => find.byType(NoteEditorPage).evaluate().isEmpty,
    phase: 'note editor route closing after save',
    timeout: const Duration(seconds: 15),
  );

  await _waitForCondition(
    tester,
    () =>
        providerContainer
            .read(appStoreProvider)
            .value
            ?.notes
            .any((note) => note.title == noteTitle && note.body == noteBody) ??
        false,
    phase: 'saved note state',
    timeout: const Duration(seconds: 12),
  );
  final savedNote = providerContainer
      .read(appStoreProvider)
      .requireValue
      .notes
      .singleWhere((note) => note.title == noteTitle);
  final noteCardRoot = find.byKey(ValueKey<String>(savedNote.id));
  await _waitFor(
    tester,
    noteCardRoot,
    phase: 'saved note card mounted',
    timeout: const Duration(seconds: 12),
  );
  await tester.ensureVisible(noteCardRoot);
  await tester.pump(const Duration(milliseconds: 250));
  final noteCard = find
      .descendant(of: noteCardRoot, matching: find.byType(SketchCard))
      .hitTestable();
  await _waitFor(
    tester,
    noteCard,
    phase: 'saved note card interaction',
    timeout: const Duration(seconds: 12),
  );
  await tester.tap(noteCard);
  await tester.pump();
  await _waitFor(
    tester,
    find.byType(NoteEditorPage),
    phase: 'reopened note editor',
    timeout: const Duration(seconds: 12),
  );
  expect(_textFieldValue(tester, noteTitleField), noteTitle);
  expect(_textFieldValue(tester, noteBodyField), noteBody);
  await _tapEditorBack(tester, phase: 'reopened note editor close');
  await _waitForCondition(
    tester,
    () => find.byType(NoteEditorPage).evaluate().isEmpty,
    phase: 'reopened note editor route closing',
    timeout: const Duration(seconds: 12),
  );

  await _openDestination(tester, index: 1, page: find.byType(PastPage));
  final pastEditor = find.byKey(const Key('past-continuous-document-editor'));
  final existingPastText = _textFieldValue(tester, pastEditor);
  final updatedPastText = existingPastText.isEmpty
      ? pastMarker
      : '$existingPastText\n\n$pastMarker';
  await _tapEditable(tester, pastEditor, phase: 'past editor focus');
  await _waitForIme(tester, pastEditor, visible: true);
  await tester.enterText(pastEditor, updatedPastText);
  await tester.pump();
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('past-editor-toolbar')),
    phase: 'past editor with IME',
    imeVisible: true,
  );
  await _hideImeAndVerifyReset(tester, pastEditor);
  await _expectEditorChromeVisible(
    tester,
    toolbar: find.byKey(const Key('past-editor-toolbar')),
    phase: 'past editor after IME dismissal',
    imeVisible: false,
  );

  await _openDestination(tester, index: 0, page: find.byType(TasksPage));
  await _waitForCondition(
    tester,
    () =>
        providerContainer
            .read(appStoreProvider)
            .value
            ?.pastBlocks
            .any((block) => block.text.contains(pastMarker)) ??
        false,
    phase: 'past editor durable save',
    timeout: const Duration(seconds: 12),
  );
  await _openDestination(tester, index: 1, page: find.byType(PastPage));
  expect(_textFieldValue(tester, pastEditor), contains(pastMarker));
  await _openDestination(tester, index: 0, page: find.byType(TasksPage));
}

String _textFieldValue(WidgetTester tester, Finder finder) {
  final field = tester.widget<TextField>(finder);
  final controller = field.controller;
  expect(controller, isNotNull, reason: 'The production editor must own data.');
  return controller!.text;
}

Future<void> _tapEditable(
  WidgetTester tester,
  Finder field, {
  required String phase,
}) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  expect(editable, findsOneWidget, reason: '$phase requires an EditableText.');

  // TextField's outer RenderMouseRegion can be clipped while a large multiline
  // EditableText inside it still receives the real pointer. Suppress only that
  // outer-render-object warning, then prove the intended inner editor owns
  // focus before any direct enterText call is allowed.
  await tester.tap(field, warnIfMissed: false);
  await tester.pump();
  await _waitForCondition(
    tester,
    () => tester.widget<EditableText>(editable).focusNode.hasFocus,
    phase: phase,
    timeout: const Duration(seconds: 3),
  );
}

Future<void> _waitForIme(
  WidgetTester tester,
  Finder editable, {
  required bool visible,
}) async {
  await _waitForCondition(
    tester,
    () {
      if (editable.evaluate().isEmpty) return false;
      final bottom = View.of(tester.element(editable)).viewInsets.bottom;
      return visible ? bottom > 0 : bottom == 0;
    },
    phase: visible ? 'real keyboard opening' : 'real keyboard dismissal',
    timeout: const Duration(seconds: 8),
  );
  if (visible) {
    // Let EditorPageFrame's bounded inset animation reach its stable geometry
    // before checking that the toolbar sits above the raw platform inset.
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _hideImeAndVerifyReset(
  WidgetTester tester,
  Finder editable,
) async {
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _waitForIme(tester, editable, visible: false);
  await tester.pump(const Duration(milliseconds: 250));
  expect(MediaQuery.viewInsetsOf(tester.element(editable)).bottom, 0);
}

Future<void> _expectEditorChromeVisible(
  WidgetTester tester, {
  required Finder toolbar,
  required String phase,
  required bool imeVisible,
}) async {
  final topBar = find.byKey(EditorPageFrame.topBarKey);
  expect(
    topBar,
    findsOneWidget,
    reason: '$phase must keep the top bar mounted.',
  );
  expect(
    toolbar,
    findsOneWidget,
    reason: '$phase must keep the toolbar mounted.',
  );

  // A route transition can retain the previous IME's raw inset while the new
  // EditableText and EditorPageFrame are still acquiring focus. API 36 also
  // animates that hand-off over multiple platform frames. Wait for the actual
  // toolbar geometry to converge instead of treating the first non-zero raw
  // inset as a settled layout; the same strict final boundary remains below.
  var stableFrames = 0;
  await _waitForCondition(
    tester,
    () {
      if (topBar.evaluate().isEmpty || toolbar.evaluate().isEmpty) return false;
      final toolbarContext = tester.element(toolbar);
      final view = View.of(toolbarContext);
      final rawInset = view.viewInsets.bottom / view.devicePixelRatio;
      final guardedInset = MediaQuery.viewInsetsOf(toolbarContext).bottom;
      final padding = tester
          .widget<AnimatedPadding>(find.byKey(EditorPageFrame.insetPaddingKey))
          .padding
          .resolve(Directionality.of(toolbarContext));
      final usableBottom =
          (view.physicalSize.height - view.viewInsets.bottom) /
          view.devicePixelRatio;
      final insetStateMatches = imeVisible
          ? rawInset > 0 &&
                (guardedInset - rawInset).abs() <= 1 &&
                (padding.bottom - rawInset).abs() <= 1
          : rawInset <= 0.5 && guardedInset <= 0.5 && padding.bottom <= 0.5;
      final geometryMatches =
          tester.getRect(topBar).bottom <= usableBottom + 1 &&
          tester.getRect(toolbar).bottom <= usableBottom + 1;
      if (!insetStateMatches || !geometryMatches) {
        stableFrames = 0;
        return false;
      }
      stableFrames += 1;
      return stableFrames >= 2;
    },
    phase: '$phase stable ${imeVisible ? 'visible' : 'hidden'} IME geometry',
    timeout: const Duration(seconds: 8),
  );

  final view = View.of(tester.element(toolbar));
  final usableBottom =
      (view.physicalSize.height - view.viewInsets.bottom) /
      view.devicePixelRatio;
  final topRect = tester.getRect(topBar);
  final toolbarRect = tester.getRect(toolbar);
  expect(topRect.top, greaterThanOrEqualTo(0), reason: phase);
  expect(topRect.bottom, lessThanOrEqualTo(usableBottom + 1), reason: phase);
  expect(toolbarRect.top, greaterThanOrEqualTo(0), reason: phase);
  expect(
    toolbarRect.bottom,
    lessThanOrEqualTo(usableBottom + 1),
    reason: '$phase toolbar must remain above the real keyboard inset.',
  );
}

Future<void> _tapEditorBack(
  WidgetTester tester, {
  required String phase,
}) async {
  final back = find.byIcon(Icons.arrow_back_rounded).hitTestable();
  expect(
    back,
    findsOneWidget,
    reason: '$phase requires a visible back action.',
  );
  await tester.tap(back);
  await tester.pump();
  _expectNoUnhandledException(tester, phase);
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

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  required String phase,
  required Duration timeout,
}) async {
  const pollingInterval = Duration(milliseconds: 200);
  final maximumPumps = (timeout.inMicroseconds / pollingInterval.inMicroseconds)
      .ceil();
  for (var attempt = 0; attempt < maximumPumps; attempt += 1) {
    if (condition()) return;
    await tester.pump(pollingInterval);
    _expectNoUnhandledException(tester, phase);
  }
  fail('$phase did not complete within ${timeout.inSeconds} seconds.');
}

void _expectNoUnhandledException(WidgetTester tester, String phase) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'An unhandled Flutter exception occurred during $phase.',
  );
}
