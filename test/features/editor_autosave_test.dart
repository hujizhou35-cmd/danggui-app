import 'dart:async';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/features/notes/note_editor_page.dart';
import 'package:danggui/src/features/tasks/task_detail_page.dart';
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

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => database)],
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
