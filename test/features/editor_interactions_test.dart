import 'dart:async';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/features/notes/notes_page.dart';
import 'package:danggui/src/features/past/past_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => database)],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets('Past exposes one editor with a cross-line text selection', (
    tester,
  ) async {
    _setPhoneSize(tester);
    await tester.runAsync(
      () => controller.replacePastDocumentText('第一行\n\n第二行\n\n第三行'),
    );
    await tester.pumpWidget(_testApp(container, const PastPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final editor = find.byKey(const Key('past-continuous-document-editor'));
    expect(editor, findsOneWidget);
    final textField = tester.widget<TextField>(editor);
    final textController = textField.controller!;
    expect(textController.text, '第一行\n第二行\n第三行');

    const selectedText = '第一行\n第二行';
    textController.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: selectedText.length,
    );
    await tester.pump();
    expect(
      textController.selection.textInside(textController.text),
      selectedText,
    );

    expect(
      find.descendant(of: editor, matching: find.byType(EditableText)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Past autosave debounces rapid edits to the newest draft', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final saves = <String>[];
    await tester.pumpWidget(
      _testApp(
        container,
        PastPage(
          autosaveDelay: const Duration(milliseconds: 40),
          onPersist: (text) async => saves.add(text),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final editor = find.byKey(const Key('past-continuous-document-editor'));
    await tester.enterText(editor, '第一稿');
    await tester.pump(const Duration(milliseconds: 10));
    await tester.enterText(editor, '第二稿');
    await tester.pump(const Duration(milliseconds: 10));
    await tester.enterText(editor, '最终稿');
    await tester.pump(const Duration(milliseconds: 39));
    expect(saves, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(saves, <String>['最终稿']);
  });

  testWidgets('Past manual save flushes once and exposes visible feedback', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final write = Completer<void>();
    final saves = <String>[];
    await tester.pumpWidget(
      _testApp(
        container,
        PastPage(
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (text) async {
            saves.add(text);
            await write.future;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const Key('past-continuous-document-editor')),
      '立即保存的内容',
    );
    await tester.tap(find.byKey(const Key('past-editor-save')));
    await tester.pump();
    expect(saves, <String>['立即保存的内容']);
    expect(
      find.descendant(
        of: find.byKey(const Key('past-editor-save')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('保存'), warnIfMissed: false);
    await tester.pump();
    expect(saves, <String>['立即保存的内容']);

    write.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('Past clean manual save still confirms without writing', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var writes = 0;
    await tester.pumpWidget(
      _testApp(container, PastPage(onPersist: (text) async => writes++)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('past-editor-save')));
    await tester.pump();
    expect(writes, 0);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('Past flushes pending edits on background and disposal', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final saves = <String>[];
    await tester.pumpWidget(
      _testApp(
        container,
        PastPage(
          autosaveDelay: const Duration(seconds: 10),
          onPersist: (text) async => saves.add(text),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final editor = find.byKey(const Key('past-continuous-document-editor'));
    await tester.enterText(editor, '进入后台前的内容');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(saves, <String>['进入后台前的内容']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.enterText(editor, '销毁前的最新内容');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(saves, <String>['进入后台前的内容', '销毁前的最新内容']);
  });

  testWidgets('Past serializes an edit made during an active write', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final firstWrite = Completer<void>();
    final saves = <String>[];
    await tester.pumpWidget(
      _testApp(
        container,
        PastPage(
          autosaveDelay: const Duration(milliseconds: 20),
          onPersist: (text) async {
            saves.add(text);
            if (saves.length == 1) await firstWrite.future;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final editor = find.byKey(const Key('past-continuous-document-editor'));
    await tester.enterText(editor, '旧值');
    await tester.pump(const Duration(milliseconds: 20));
    expect(saves, <String>['旧值']);

    await tester.enterText(editor, '写入期间产生的新值');
    await tester.pump(const Duration(milliseconds: 30));
    expect(saves, <String>['旧值']);
    firstWrite.complete();
    await tester.pump();
    await tester.pump();
    expect(saves, <String>['旧值', '写入期间产生的新值']);
  });

  testWidgets('Past retains a failed draft and retries when foregrounded', (
    tester,
  ) async {
    _setPhoneSize(tester);
    var attempts = 0;
    String? saved;
    await tester.pumpWidget(
      _testApp(
        container,
        PastPage(
          autosaveDelay: const Duration(milliseconds: 20),
          autosaveRetryDelay: const Duration(seconds: 10),
          onPersist: (text) async {
            attempts++;
            if (attempts == 1) throw StateError('temporary failure');
            saved = text;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const Key('past-continuous-document-editor')),
      '不可丢失的过往',
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(attempts, 1);
    expect(saved, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(saved, '不可丢失的过往');
  });

  testWidgets(
    'Notes multi-selection exposes batch actions and can be cancelled',
    (tester) async {
      _setPhoneSize(tester);
      await tester.runAsync(() async {
        await controller.createNote(title: '甲笔记', body: '甲内容');
        await controller.createNote(title: '乙笔记', body: '乙内容');
        await controller.createNote(title: '保留笔记', body: '不应删除');
      });
      await tester.pumpWidget(_testApp(container, const NotesPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final semantics = tester.ensureSemantics();
      final allNotesChip = find.bySemanticsLabel('全部');
      expect(allNotesChip, findsOneWidget);
      expect(tester.getSize(allNotesChip).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(allNotesChip),
        matchesSemantics(
          label: '全部',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await tester.longPress(find.text('甲笔记'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.longPress(find.text('乙笔记'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('文件夹'), findsOneWidget);
      expect(find.bySemanticsLabel('导出'), findsOneWidget);
      expect(find.bySemanticsLabel('删除'), findsOneWidget);
      expect(find.bySemanticsLabel('取消'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('取消'));
      await tester.pump(const Duration(milliseconds: 300));

      final notes = container.read(appStoreProvider).requireValue.notes;
      expect(notes.map((note) => note.title).toSet(), <String>{
        '甲笔记',
        '乙笔记',
        '保留笔记',
      });
      expect(await database.select(database.trashEntries).get(), isEmpty);
      expect(find.text('甲笔记'), findsOneWidget);
      expect(find.text('乙笔记'), findsOneWidget);
      expect(find.text('保留笔记'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
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
      // Feature pages are AppShell children in production and therefore have
      // a descendant Scaffold for save feedback and snack bars.
      home: Scaffold(body: home),
    ),
  );
}
