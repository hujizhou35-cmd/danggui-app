import 'dart:io';

import 'package:danggui/src/app.dart';
import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/notes/note_editor_page.dart';
import 'package:danggui/src/features/notes/notes_page.dart';
import 'package:danggui/src/features/past/past_page.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
import 'package:danggui/src/features/tasks/tasks_page.dart';
import 'package:danggui/src/services/backup/automatic_backup_coordinator.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;
  late String taskId;
  late String noteId;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        automaticBackupCoordinatorProvider.overrideWithValue(
          AutomaticBackupCoordinator(
            clock: DateTime.now,
            readSettings: () async =>
                const AppSettingsModel(autoBackupEnabled: false),
            readPassphrase: () async => null,
            readDirectory: () async => Directory.systemTemp,
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
    await controller.saveSettings(
      const AppSettingsModel(localeMode: LocaleMode.zhHans),
    );
    taskId = await controller.createTask(title: '原事项');
    noteId = await controller.createNote(title: '原笔记', body: '原内容');
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets(
    'real task card route edits, flushes on back, and restores on reopen',
    (tester) => _withMountedApp(tester, () async {
      _setView(tester, const Size(412, 915));
      await _pumpRealApp(tester, container, location: '/tasks');
      expect(find.byType(TasksPage), findsOneWidget);

      await tester.tap(find.text('原事项').hitTestable());
      await _waitForFinder(tester, find.byType(TaskDetailPage));

      await tester.enterText(
        find.byKey(const Key('task-title-field')),
        '重进仍保留的事项',
      );
      final body = find.byKey(const Key('task-body-field'));
      await tester.enterText(body, '可编辑的事项内容');
      await _expectImeCycle(
        tester,
        field: body,
        toolbar: find.byKey(const Key('task-editor-toolbar')),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).hitTestable());
      await _waitForAbsence(tester, find.byType(TaskDetailPage));
      expect(find.byType(TasksPage).hitTestable(), findsOneWidget);
      final persisted = _task(container, taskId);
      expect(persisted.title, '重进仍保留的事项');
      expect(persisted.body, '可编辑的事项内容');

      await tester.tap(find.text('重进仍保留的事项').hitTestable());
      await _waitForFinder(tester, find.byType(TaskDetailPage));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('task-title-field')))
            .controller
            ?.text,
        '重进仍保留的事项',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('task-body-field')))
            .controller
            ?.text,
        '可编辑的事项内容',
      );
    }),
  );

  testWidgets(
    'real notes branch opens an editable route and persists on return',
    (tester) => _withMountedApp(tester, () async {
      _setView(tester, const Size(412, 915));
      await _pumpRealApp(tester, container, location: '/tasks');
      await _openBranch(tester, 2);
      expect(find.byType(NotesPage), findsOneWidget);

      await tester.tap(find.text('原笔记').hitTestable());
      await _waitForFinder(tester, find.byType(NoteEditorPage));
      await tester.enterText(
        find.byKey(const Key('note-editor-title')),
        '重进仍保留的笔记',
      );
      final body = find.byKey(const Key('note-editor-body'));
      await tester.enterText(body, '现在可以正常编辑');
      await _expectImeCycle(
        tester,
        field: body,
        toolbar: find.byKey(const Key('note-editor-toolbar')),
      );

      await tester.tap(find.byKey(const Key('note-editor-back')));
      await _waitForAbsence(tester, find.byType(NoteEditorPage));
      expect(find.byType(NotesPage).hitTestable(), findsOneWidget);
      final persisted = _note(container, noteId);
      expect(persisted.title, '重进仍保留的笔记');
      expect(persisted.body, '现在可以正常编辑');

      await tester.tap(find.text('重进仍保留的笔记').hitTestable());
      await _waitForFinder(tester, find.byType(NoteEditorPage));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-editor-title')))
            .controller
            ?.text,
        '重进仍保留的笔记',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-editor-body')))
            .controller
            ?.text,
        '现在可以正常编辑',
      );
    }),
  );

  testWidgets(
    'visible note body pointer transfers focus from the title',
    (tester) => _withMountedApp(tester, () async {
      _setView(tester, const Size(412, 915));
      await _pumpRealApp(tester, container, location: '/tasks');
      await _openBranch(tester, 2);
      await tester.tap(find.text('原笔记').hitTestable());
      await _waitForFinder(tester, find.byType(NoteEditorPage));

      final title = find.byKey(const Key('note-editor-title'));
      final body = find.byKey(const Key('note-editor-body'));
      final bodyEditable = find.descendant(
        of: body,
        matching: find.byType(EditableText),
      );
      await tester.tap(title);
      await tester.pump();
      final titleEditable = find.descendant(
        of: title,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
        isTrue,
      );
      expect(
        tester.widget<EditableText>(bodyEditable).focusNode.hasFocus,
        isFalse,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 427);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(body);
      await tester.pump(const Duration(milliseconds: 250));

      final renderEditable = tester
          .state<EditableTextState>(bodyEditable)
          .renderEditable;
      final visibleBodyEditor = MatrixUtils.transformRect(
        renderEditable.getTransformTo(null),
        Offset.zero & renderEditable.size,
      ).intersect(tester.getRect(find.byKey(EditorPageFrame.editorKey)));
      expect(visibleBodyEditor.width, greaterThanOrEqualTo(24));
      expect(visibleBodyEditor.height, greaterThanOrEqualTo(24));
      final tapPoint = Offset(
        visibleBodyEditor.left + visibleBodyEditor.width * 0.1,
        visibleBodyEditor.top + visibleBodyEditor.height * 0.1,
      );
      final hitTest = tester.hitTestOnBinding(tapPoint);
      expect(
        hitTest.path.any((entry) => identical(entry.target, renderEditable)),
        isTrue,
      );
      final gesture = await tester.startGesture(tapPoint);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        tester.widget<EditableText>(bodyEditable).focusNode.hasFocus,
        isTrue,
      );
    }),
  );

  testWidgets(
    'real shell hides navigation for the Past IME without double offset',
    (tester) => _withMountedApp(tester, () async {
      _setView(tester, const Size(320, 568), textScaleFactor: 2);
      await _pumpRealApp(tester, container, location: '/tasks');
      await _openBranch(tester, 1);
      expect(find.byType(PastPage), findsOneWidget);
      expect(
        find.byKey(const Key('app-shell-bottom-navigation')),
        findsOneWidget,
      );

      final editor = find.byKey(const Key('past-continuous-document-editor'));
      await tester.enterText(editor, '第一行\n\n第二行');
      await _expectImeCycle(
        tester,
        field: editor,
        toolbar: find.byKey(const Key('past-editor-toolbar')),
        shellHosted: true,
      );
      expect(find.byKey(const Key('past-editor-top-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _waitForPastText(tester, container, '第一行\n\n第二行');

      await _openBranch(tester, 0);
      expect(find.byType(TasksPage), findsOneWidget);
      await _openBranch(tester, 1);
      expect(tester.widget<TextField>(editor).controller?.text, '第一行\n\n第二行');
    }),
  );

  testWidgets(
    'DangguiApp preserves a system accessibility scale above two times',
    (tester) => _withMountedApp(tester, () async {
      _setView(tester, const Size(1024, 1366), textScaleFactor: 3.2);
      await _pumpRealApp(tester, container, location: '/tasks');

      final pageContext = tester.element(find.byType(TasksPage));
      expect(
        MediaQuery.textScalerOf(pageContext).scale(1),
        closeTo(3.2, 0.001),
      );
      expect(tester.takeException(), isNull);
    }),
  );
}

Future<void> _withMountedApp(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  try {
    await body();
  } finally {
    // Dispose the routed app while the test is still active. DangguiApp starts
    // asynchronous notification reconciliation, so its widget tree must be
    // detached before the provider container and database are closed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

TaskViewModel _task(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .tasks
    .singleWhere((task) => task.id == id);

NoteViewModel _note(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .notes
    .singleWhere((note) => note.id == id);

Future<void> _pumpRealApp(
  WidgetTester tester,
  ProviderContainer container, {
  required String location,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DangguiApp()),
  );
  await tester.pump();
  container.read(routerProvider).go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await _waitForFinder(
    tester,
    find.byKey(const Key('app-shell-bottom-navigation')),
  );
}

Future<void> _openBranch(WidgetTester tester, int index) async {
  final navFinder = find.byKey(const Key('app-shell-bottom-navigation'));
  expect(navFinder, findsOneWidget);
  final nav = tester.widget<DangguiBottomNav>(navFinder);
  final destination = find.descendant(
    of: navFinder,
    matching: find.text(nav.destinations[index].label),
  );
  await tester.tap(destination.hitTestable());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForAbsence(WidgetTester tester, Finder finder) async {
  for (
    var attempt = 0;
    attempt < 40 && finder.evaluate().isNotEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}

Future<void> _waitForPastText(
  WidgetTester tester,
  ProviderContainer container,
  String expected,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final actual = container
        .read(appStoreProvider)
        .requireValue
        .pastBlocks
        .map((block) => block.text)
        .join('\n\n');
    if (actual == expected) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  final actual = container
      .read(appStoreProvider)
      .requireValue
      .pastBlocks
      .map((block) => block.text)
      .join('\n\n');
  expect(actual, expected);
}

Future<void> _expectImeCycle(
  WidgetTester tester, {
  required Finder field,
  required Finder toolbar,
  bool shellHosted = false,
}) async {
  final initialBottom = tester.getBottomLeft(toolbar).dy;
  expect(
    (tester
                .widget<AnimatedPadding>(
                  find.byKey(EditorPageFrame.insetPaddingKey),
                )
                .padding
            as EdgeInsets)
        .bottom,
    0,
  );

  await tester.tap(field);
  await tester.pump();
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(
    (tester
                .widget<AnimatedPadding>(
                  find.byKey(EditorPageFrame.insetPaddingKey),
                )
                .padding
            as EdgeInsets)
        .bottom,
    300,
  );
  expect(
    tester.getBottomLeft(toolbar).dy,
    lessThanOrEqualTo(tester.view.physicalSize.height - 300),
  );
  expect(find.byKey(EditorPageFrame.topBarKey), findsOneWidget);
  if (shellHosted) {
    expect(find.byKey(const Key('app-shell-bottom-navigation')), findsNothing);
    expect(
      tester.getBottomLeft(toolbar).dy,
      closeTo(tester.view.physicalSize.height - 300 - 10, .1),
      reason: 'the hidden shell bar must not be subtracted a second time',
    );
  }
  expect(tester.takeException(), isNull);

  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(
    (tester
                .widget<AnimatedPadding>(
                  find.byKey(EditorPageFrame.insetPaddingKey),
                )
                .padding
            as EdgeInsets)
        .bottom,
    0,
  );
  expect(tester.getBottomLeft(toolbar).dy, closeTo(initialBottom, .1));
  if (shellHosted) {
    expect(
      find.byKey(const Key('app-shell-bottom-navigation')),
      findsOneWidget,
    );
  }
}

void _setView(WidgetTester tester, Size size, {double textScaleFactor = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
