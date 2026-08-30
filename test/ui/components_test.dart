import 'package:danggui/src/core/theme/theme.dart';

import 'dart:ui' show SemanticsAction;

import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskCardSchedule', () {
    test('formats no reminder as only the task date', () {
      const schedule = TaskCardSchedule(taskDateLabel: '8月25日');
      expect(schedule.displayLabel, '8月25日');
    });

    test('formats a same-day reminder without repeating the date', () {
      const schedule = TaskCardSchedule(
        taskDateLabel: '8月25日',
        reminderDateLabel: '8月25日',
        reminderTimeLabel: '19:50',
      );
      expect(schedule.displayLabel, '8月25日（19:50 提醒）');
    });

    test('formats a cross-day reminder with both dates', () {
      const schedule = TaskCardSchedule(
        taskDateLabel: '8月25日',
        reminderDateLabel: '8月24日',
        reminderTimeLabel: '19:50',
      );
      expect(schedule.displayLabel, '8月25日（8月24日 19:50 提醒）');
    });

    test('formats a reminder when the task has no date', () {
      const schedule = TaskCardSchedule(
        reminderDateLabel: '8月24日',
        reminderTimeLabel: '19:50',
      );
      expect(schedule.displayLabel, '8月24日 19:50 提醒');
    });

    test('accepts localized punctuation and suffixes', () {
      const schedule = TaskCardSchedule(
        taskDateLabel: 'Aug 25',
        reminderDateLabel: 'Aug 25',
        reminderTimeLabel: '19:50',
        reminderSuffix: 'reminder',
        openingParenthesis: ' (',
        closingParenthesis: ')',
      );
      expect(schedule.displayLabel, 'Aug 25 (19:50 reminder)');
    });
  });

  testWidgets('DangguiSwitch has a 44dp target and controlled behavior', (
    tester,
  ) async {
    var value = true;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Center(
          child: DangguiSwitch(
            value: value,
            semanticLabel: '事项状态',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(DangguiSwitch)), const Size(62, 44));
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('事项状态'), findsOneWidget);
    await tester.tap(find.byType(DangguiSwitch));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    semantics.dispose();
  });

  testWidgets('compact DangguiSwitch keeps its 44dp accessibility target', (
    tester,
  ) async {
    await _pump(
      tester,
      const Center(
        child: DangguiSwitch(
          value: true,
          semanticLabel: '通知声音',
          size: DangguiSwitchSize.compact,
        ),
      ),
    );

    expect(tester.getSize(find.byType(DangguiSwitch)), const Size(45, 44));
  });

  testWidgets('DangguiIconButton exposes an actionable semantic button', (
    tester,
  ) async {
    var pressed = false;
    await _pump(
      tester,
      Center(
        child: DangguiIconButton(
          icon: const Icon(Icons.add),
          semanticLabel: 'Add item',
          onPressed: () => pressed = true,
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(find.bySemanticsLabel('Add item'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Add item'));
    await tester.pump();
    expect(pressed, isTrue);
    semantics.dispose();
  });

  testWidgets('TaskCard swaps schedule for pending actions', (tester) async {
    var added = false;
    var deleted = false;
    await _pump(
      tester,
      Center(
        child: SizedBox(
          width: 378,
          child: TaskCard(
            title: '修改论文引言',
            schedule: const TaskCardSchedule(
              taskDateLabel: '8月25日',
              reminderDateLabel: '8月24日',
              reminderTimeLabel: '19:50',
            ),
            status: TaskCardStatus.completionPending,
            switchSemanticLabel: '事项状态',
            addToPastLabel: '加入过往',
            deleteLabel: '删除',
            onAddToPast: () => added = true,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('8月25日（8月24日 19:50 提醒）'), findsNothing);
    expect(find.text('加入过往'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('加入过往'));
    await tester.tap(find.text('删除'));
    expect(added, isTrue);
    expect(deleted, isTrue);
  });

  testWidgets('TaskCard exposes a hit-testable title semantic target', (
    tester,
  ) async {
    const title = 'IME task semantics';
    const cardKey = ValueKey<String>('task-card-semantics');
    await _pump(
      tester,
      const Center(
        child: SizedBox(
          width: 378,
          child: TaskCard(
            key: cardKey,
            title: title,
            switchSemanticLabel: 'IME task semantics on',
            addToPastLabel: 'Add to past',
            deleteLabel: 'Delete',
            onTap: _noop,
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    expect(find.byKey(cardKey).hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel(title), findsOneWidget);
    expect(find.bySemanticsLabel(title).hitTestable(), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('active and pending TaskCards keep the same height', (
    tester,
  ) async {
    const activeKey = ValueKey<String>('active-card');
    const pendingKey = ValueKey<String>('pending-card');
    await _pump(
      tester,
      const SizedBox(
        width: 378,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TaskCard(
              key: activeKey,
              title: '整理实验数据',
              schedule: TaskCardSchedule(taskDateLabel: '8月25日'),
              switchSemanticLabel: '事项状态',
              addToPastLabel: '加入过往',
              deleteLabel: '删除',
            ),
            TaskCard(
              key: pendingKey,
              title: '修改论文引言',
              status: TaskCardStatus.completionPending,
              switchSemanticLabel: '事项状态',
              addToPastLabel: '加入过往',
              deleteLabel: '删除',
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(activeKey)).height,
      greaterThanOrEqualTo(128),
    );
    expect(
      tester.getSize(find.byKey(pendingKey)).height,
      tester.getSize(find.byKey(activeKey)).height,
    );
  });

  testWidgets(
    'translated pending actions stay on one 44dp row at 320px and 2.0x',
    (tester) async {
      const activeKey = ValueKey<String>('scaled-active-card');
      const pendingKey = ValueKey<String>('scaled-pending-card');
      const addLabel = 'Добавить в прошлое';
      const deleteLabel = 'Удалить безвозвратно';
      await _pump(
        tester,
        const Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TaskCard(
                key: activeKey,
                title: 'Подготовить материалы для исследования',
                schedule: TaskCardSchedule(
                  taskDateLabel: '25 августа',
                  reminderDateLabel: '24 августа',
                  reminderTimeLabel: '19:50',
                  reminderSuffix: 'напоминание',
                  openingParenthesis: ' (',
                  closingParenthesis: ')',
                ),
                switchSemanticLabel: 'Статус задачи',
                addToPastLabel: addLabel,
                deleteLabel: deleteLabel,
              ),
              TaskCard(
                key: pendingKey,
                title: 'Подготовить материалы для исследования',
                status: TaskCardStatus.completionPending,
                switchSemanticLabel: 'Статус задачи',
                addToPastLabel: addLabel,
                deleteLabel: deleteLabel,
              ),
            ],
          ),
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      final actionButtons = find.descendant(
        of: find.byKey(pendingKey),
        matching: find.byType(TextButton),
      );
      expect(actionButtons, findsNWidgets(2));
      final firstButton = actionButtons.at(0);
      final secondButton = actionButtons.at(1);
      expect(tester.getSize(firstButton).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(secondButton).height, greaterThanOrEqualTo(44));
      expect(
        tester.getTopLeft(firstButton).dy,
        tester.getTopLeft(secondButton).dy,
      );
      expect(
        tester.getSize(find.byKey(pendingKey)).height,
        tester.getSize(find.byKey(activeKey)).height,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navigation and toolbar expose responsive 44dp controls', (
    tester,
  ) async {
    var selected = 0;
    var edited = false;
    await _pump(
      tester,
      Column(
        children: <Widget>[
          EditorToolbar(
            items: <EditorToolbarItem>[
              EditorToolbarItem(
                icon: const Text('Aa'),
                semanticLabel: '文本样式',
                onPressed: () => edited = true,
              ),
              const EditorToolbarItem(
                icon: Icon(Icons.format_list_bulleted),
                semanticLabel: '项目符号',
              ),
            ],
          ),
          const Spacer(),
          StatefulBuilder(
            builder: (context, setState) => DangguiBottomNav(
              destinations: const <DangguiNavigationDestination>[
                DangguiNavigationDestination(
                  icon: Icon(Icons.checklist),
                  label: '事项',
                ),
                DangguiNavigationDestination(
                  icon: Icon(Icons.history),
                  label: '过往',
                ),
                DangguiNavigationDestination(
                  icon: Icon(Icons.note_outlined),
                  label: '笔记',
                ),
                DangguiNavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: '设置',
                ),
              ],
              currentIndex: selected,
              onTap: (index) => setState(() => selected = index),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Aa'));
    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(edited, isTrue);
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsTile grows for Russian copy at 320px and 1.6x', (
    tester,
  ) async {
    await _pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(12),
        child: SettingsGroup(
          children: <Widget>[
            SettingsTile(
              title: 'Автоматическое локальное резервное копирование',
              subtitle: 'Один раз в день; сохраняются последние тридцать копий',
              trailing: Icon(Icons.chevron_right),
              showDivider: false,
            ),
          ],
        ),
      ),
      size: const Size(320, 568),
      textScale: 1.6,
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SettingsTile)).height, greaterThan(57));
  });

  testWidgets('ExportSheet remains usable on a compact translated layout', (
    tester,
  ) async {
    var continued = false;
    await _pump(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ExportSheet(
          title: 'Экспорт',
          options: <ExportSheetOption>[
            ExportSheetOption(
              label: 'Экспортировать все личные данные',
              tag: 'ZIP',
              onPressed: () {},
            ),
            ExportSheetOption(
              label: 'Экспортировать по диапазону дат',
              tag: 'MD + JSON',
              onPressed: () {},
            ),
          ],
          cancelLabel: 'Отмена',
          continueLabel: 'Продолжить',
          onCancel: () {},
          onContinue: () => continued = true,
        ),
      ),
      size: const Size(320, 568),
    );

    await tester.tap(find.text('Продолжить'));
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReminderDialog confirms the controlled time', (tester) async {
    TimeOfDay? confirmed;
    await _pump(
      tester,
      ReminderDialog(
        title: '设置提醒时间',
        selectedTime: const TimeOfDay(hour: 18, minute: 51),
        dateLabel: '8月24日',
        dateSemanticLabel: '提醒日期',
        cancelLabel: '取消',
        confirmLabel: '确定',
        hourSemanticLabel: '小时',
        minuteSemanticLabel: '分钟',
        onCancel: () {},
        onConfirm: (value) => confirmed = value,
      ),
      size: const Size(320, 568),
    );

    await tester.tap(find.text('确定'));
    expect(confirmed, const TimeOfDay(hour: 18, minute: 51));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: DangguiTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: PaperBackground(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _noop() {}
