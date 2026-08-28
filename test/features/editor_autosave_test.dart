import 'dart:async';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/features/notes/note_editor_page.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late String taskId;
  late String noteId;
  late _BlockingNotificationGateway notificationGateway;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    notificationGateway = _BlockingNotificationGateway();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        notificationCoordinatorProvider.overrideWithValue(
          NotificationCoordinator(
            () async => database,
            gateway: notificationGateway,
          ),
        ),
      ],
    );
    await container.read(appStoreProvider.future);
    taskId = await container
        .read(appStoreProvider.notifier)
        .createTask(title: '原任务');
    noteId = await container
        .read(appStoreProvider.notifier)
        .createNote(title: '原笔记', body: '');
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets(
    'task autosave debounces rapid edits and keeps the newest draft',
    (tester) async {
      final saves = <TaskViewModel>[];

      await tester.pumpWidget(
        _testApp(
          container,
          TaskDetailPage(
            taskId: taskId,
            autosaveDelay: const Duration(milliseconds: 40),
            onPersist: (task) async => saves.add(task),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        saves,
        isEmpty,
        reason: 'hydration must not be treated as an edit',
      );

      final body = find.byType(TextField).at(2);
      await tester.enterText(body, '第一个草稿');
      await tester.pump(const Duration(milliseconds: 10));
      await tester.enterText(body, '第二个草稿');
      await tester.pump(const Duration(milliseconds: 10));
      await tester.enterText(body, '最终内容');
      await tester.pump(const Duration(milliseconds: 45));
      await tester.pump();

      expect(saves, hasLength(1));
      expect(saves.single.body, '最终内容');
    },
  );

  testWidgets('task autosave serializes an edit made during an active write', (
    tester,
  ) async {
    final firstWrite = Completer<void>();
    final saves = <TaskViewModel>[];

    await tester.pumpWidget(
      _testApp(
        container,
        TaskDetailPage(
          taskId: taskId,
          autosaveDelay: const Duration(milliseconds: 20),
          onPersist: (task) async {
            saves.add(task);
            if (saves.length == 1) await firstWrite.future;
          },
        ),
      ),
    );
    await tester.pump();

    final body = find.byType(TextField).at(2);
    await tester.enterText(body, '旧值');
    await tester.pump(const Duration(milliseconds: 25));
    expect(saves.map((item) => item.body), <String>['旧值']);

    await tester.enterText(body, '写入期间产生的新值');
    await tester.pump(const Duration(milliseconds: 25));
    firstWrite.complete();
    await tester.pump();
    await tester.pump();

    expect(saves.map((item) => item.body), <String>['旧值', '写入期间产生的新值']);
  });

  testWidgets('task editor flushes a pending draft before disposal', (
    tester,
  ) async {
    final saves = <TaskViewModel>[];

    await tester.pumpWidget(
      _testApp(
        container,
        TaskDetailPage(
          taskId: taskId,
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (task) async => saves.add(task),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '销毁前必须保存');
    expect(saves, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(saves, hasLength(1));
    expect(saves.single.body, '销毁前必须保存');
  });

  testWidgets(
    'task real AppStore rebases a second edit after its own in-flight save',
    (tester) async {
      late String reminderTaskId;
      await tester.runAsync(() async {
        reminderTaskId = await container
            .read(appStoreProvider.notifier)
            .createTask(
              title: '原提醒事项',
              reminderAt: DateTime.now().add(const Duration(hours: 2)),
            );
      });
      final baseline = _task(container, reminderTaskId);
      final gate = notificationGateway.blockNextSchedule();
      await tester.pumpWidget(
        _testApp(
          container,
          TaskDetailPage(
            taskId: reminderTaskId,
            autosaveDelay: const Duration(milliseconds: 20),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('task-title-field')),
        '第一次提交',
      );
      await tester.pump(const Duration(milliseconds: 25));
      await _pumpUntil(
        tester,
        () => notificationGateway.blockedScheduleEntered,
      );

      await tester.enterText(
        find.byKey(const Key('task-title-field')),
        '写入期间的第二次提交',
      );
      gate.complete();
      await _pumpUntil(
        tester,
        () => _task(container, reminderTaskId).title == '写入期间的第二次提交',
      );

      final persisted = _task(container, reminderTaskId);
      expect(persisted.rowVersion, baseline.rowVersion + 2);
      expect(
        find.byKey(const Key('task-editor-version-conflict')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'task dirty draft does not adopt or overwrite an external rowVersion',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          container,
          TaskDetailPage(
            taskId: taskId,
            autosaveDelay: const Duration(seconds: 10),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('task-body-field')),
        '本地未保存内容',
      );
      final baseline = _task(container, taskId);

      await tester.runAsync(
        () => container
            .read(appStoreProvider.notifier)
            .updateTask(baseline.copyWith(title: '外部标题', body: '外部已保存内容')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('task-editor-version-conflict')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('task-body-field')))
            .controller!
            .text,
        '本地未保存内容',
      );
      await tester.pump(const Duration(seconds: 11));
      expect(_task(container, taskId).body, '外部已保存内容');

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('task-editor-version-conflict')),
          matching: find.text('重新加载'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('task-editor-version-conflict')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('task-body-field')))
            .controller!
            .text,
        '外部已保存内容',
      );
    },
  );

  testWidgets('task manual save flushes the draft and confirms success', (
    tester,
  ) async {
    final saves = <TaskViewModel>[];

    await tester.pumpWidget(
      _testApp(
        container,
        TaskDetailPage(
          taskId: taskId,
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (task) async => saves.add(task),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '事项按钮立即保存');

    await tester.tap(find.byKey(const Key('task-editor-save')));
    await tester.pump();

    expect(saves, hasLength(1));
    expect(saves.single.body, '事项按钮立即保存');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.byType(TaskDetailPage), findsOneWidget);
  });

  testWidgets('note autosave debounces rapid edits and flushes on disposal', (
    tester,
  ) async {
    final saves = <NoteViewModel>[];

    await tester.pumpWidget(
      _testApp(
        container,
        NoteEditorPage(
          noteId: noteId,
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (note) async => saves.add(note),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(saves, isEmpty, reason: 'hydration must not be treated as an edit');

    final body = find.byType(TextField).at(1);
    await tester.enterText(body, '一');
    await tester.enterText(body, '一二');
    await tester.enterText(body, '一二三');
    expect(saves, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(saves, hasLength(1));
    expect(saves.single.body, '一二三');
  });

  testWidgets('note autosave retains a failed draft and retries it', (
    tester,
  ) async {
    var attempts = 0;
    NoteViewModel? saved;

    await tester.pumpWidget(
      _testApp(
        container,
        NoteEditorPage(
          noteId: noteId,
          autosaveDelay: const Duration(milliseconds: 20),
          autosaveRetryDelay: const Duration(milliseconds: 30),
          onPersist: (note) async {
            attempts++;
            if (attempts == 1) throw StateError('temporary write failure');
            saved = note;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '不可丢失的草稿');
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(attempts, 1);
    expect(saved, isNull);

    await tester.pump(const Duration(milliseconds: 35));
    await tester.pump();

    expect(attempts, 2);
    expect(saved?.body, '不可丢失的草稿');
  });

  testWidgets(
    'note real AppStore rebases a second edit after its own in-flight save',
    (tester) async {
      final baseline = _note(container, noteId);
      final firstSaveEntered = Completer<void>();
      final releaseFirstSave = Completer<void>();
      var saveCount = 0;
      await tester.pumpWidget(
        _testApp(
          container,
          NoteEditorPage(
            noteId: noteId,
            autosaveDelay: const Duration(milliseconds: 20),
            onPersist: (note) async {
              saveCount++;
              if (saveCount == 1) {
                firstSaveEntered.complete();
                await releaseFirstSave.future;
              }
              await container.read(appStoreProvider.notifier).updateNote(note);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('note-editor-body')),
        '第一次提交',
      );
      await tester.pump(const Duration(milliseconds: 25));
      await _pumpUntil(tester, () => firstSaveEntered.isCompleted);

      await tester.enterText(
        find.byKey(const Key('note-editor-body')),
        '写入期间的第二次提交',
      );
      releaseFirstSave.complete();
      await _pumpUntil(
        tester,
        () => _note(container, noteId).body == '写入期间的第二次提交',
      );

      final persisted = _note(container, noteId);
      expect(persisted.rowVersion, baseline.rowVersion + 2);
      expect(saveCount, 2);
      expect(
        find.byKey(const Key('note-editor-version-conflict')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'note dirty draft does not adopt or overwrite an external rowVersion',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          container,
          NoteEditorPage(
            noteId: noteId,
            autosaveDelay: const Duration(seconds: 10),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('note-editor-body')),
        '本地未保存笔记',
      );
      final baseline = _note(container, noteId);

      await tester.runAsync(
        () => container
            .read(appStoreProvider.notifier)
            .updateNote(baseline.copyWith(title: '外部笔记', body: '外部已保存笔记')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('note-editor-version-conflict')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-editor-body')))
            .controller!
            .text,
        '本地未保存笔记',
      );
      await tester.pump(const Duration(seconds: 11));
      expect(_note(container, noteId).body, '外部已保存笔记');

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('note-editor-version-conflict')),
          matching: find.text('重新加载'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('note-editor-version-conflict')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-editor-body')))
            .controller!
            .text,
        '外部已保存笔记',
      );
    },
  );

  testWidgets('note manual save flushes the draft and confirms success', (
    tester,
  ) async {
    final saves = <NoteViewModel>[];

    await tester.pumpWidget(
      _testApp(
        container,
        NoteEditorPage(
          noteId: noteId,
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (note) async => saves.add(note),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '点击按钮立即保存');

    await tester.tap(find.byKey(const Key('note-editor-save')));
    await tester.pump();

    expect(saves, hasLength(1));
    expect(saves.single.body, '点击按钮立即保存');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.byType(NoteEditorPage), findsOneWidget);
  });

  testWidgets(
    'note manual save ignores a duplicate tap during an active write',
    (tester) async {
      final write = Completer<void>();
      final saves = <NoteViewModel>[];

      await tester.pumpWidget(
        _testApp(
          container,
          NoteEditorPage(
            noteId: noteId,
            autosaveDelay: const Duration(seconds: 10),
            onPersist: (note) async {
              saves.add(note);
              await write.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '只写入一次');

      await tester.tap(find.byKey(const Key('note-editor-save')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('note-editor-save')));
      await tester.pump();

      expect(saves, hasLength(1));
      write.complete();
      await tester.pump();
      await tester.pump();
      expect(saves, hasLength(1));
      expect(find.text('已保存'), findsOneWidget);
    },
  );
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

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
  throw StateError('Timed out waiting for editor persistence.');
}

final class _BlockingNotificationGateway implements NotificationGateway {
  Completer<void>? _nextScheduleGate;
  bool blockedScheduleEntered = false;
  final Set<int> _pending = <int>{};

  Completer<void> blockNextSchedule() {
    blockedScheduleEntered = false;
    return _nextScheduleGate = Completer<void>();
  }

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'ios';

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
  Future<Set<int>> pendingNotificationIds() async => Set<int>.of(_pending);

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    final gate = _nextScheduleGate;
    if (gate != null) {
      _nextScheduleGate = null;
      blockedScheduleEntered = true;
      await gate.future;
    }
    _pending.add(request.notificationId);
  }

  @override
  Future<void> cancel(int notificationId) async {
    _pending.remove(notificationId);
  }
}

Widget _testApp(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
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
