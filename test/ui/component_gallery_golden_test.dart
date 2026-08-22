import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_support.dart';

void main() {
  setUpAll(() async {
    final displayFont = FontLoader('DangguiDisplay')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf'));
    final iconFont = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait(<Future<void>>[displayFont.load(), iconFont.load()]);
  });

  testWidgets('task card states and navigation remain visually stable', (
    tester,
  ) async {
    await _configureView(tester);
    const galleryKey = Key('task-gallery');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _goldenTheme(),
        home: RepaintBoundary(
          key: galleryKey,
          child: PaperBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: <Widget>[
                  DangguiTopBar(
                    actions: <Widget>[
                      DangguiIconButton(
                        icon: const Icon(Icons.search),
                        semanticLabel: '搜索',
                        onPressed: () {},
                      ),
                      DangguiIconButton(
                        icon: const Icon(Icons.swap_vert),
                        semanticLabel: '排序',
                        onPressed: () {},
                      ),
                      DangguiIconButton(
                        icon: const Icon(Icons.add),
                        semanticLabel: '新建事项',
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(17, 3, 17, 14),
                      children: <Widget>[
                        const TaskCard(
                          title: '同日提醒',
                          schedule: TaskCardSchedule(
                            taskDateLabel: '8月25日',
                            reminderDateLabel: '8月25日',
                            reminderTimeLabel: '19:50',
                          ),
                          switchSemanticLabel: '事项状态',
                          addToPastLabel: '加入过往',
                          deleteLabel: '删除',
                        ),
                        const SizedBox(height: 14),
                        const TaskCard(
                          title: '跨日提醒',
                          alternate: true,
                          schedule: TaskCardSchedule(
                            taskDateLabel: '8月25日',
                            reminderDateLabel: '8月24日',
                            reminderTimeLabel: '19:50',
                          ),
                          switchSemanticLabel: '事项状态',
                          addToPastLabel: '加入过往',
                          deleteLabel: '删除',
                        ),
                        const SizedBox(height: 14),
                        const TaskCard(
                          title: '仅有提醒',
                          schedule: TaskCardSchedule(
                            reminderDateLabel: '8月24日',
                            reminderTimeLabel: '19:50',
                          ),
                          switchSemanticLabel: '事项状态',
                          addToPastLabel: '加入过往',
                          deleteLabel: '删除',
                        ),
                        const SizedBox(height: 14),
                        TaskCard(
                          title: '关闭状态',
                          alternate: true,
                          status: TaskCardStatus.completionPending,
                          switchSemanticLabel: '事项状态',
                          addToPastLabel: '加入过往',
                          deleteLabel: '删除',
                          onAddToPast: () {},
                          onDelete: () {},
                        ),
                      ],
                    ),
                  ),
                  DangguiBottomNav(
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
                    currentIndex: 0,
                    onTap: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(galleryKey),
      matchesGoldenFile(
        reviewedPlatformGolden('task_cards_and_navigation.png'),
      ),
    );
  });

  testWidgets('settings and editor controls remain visually stable', (
    tester,
  ) async {
    await _configureView(tester);
    const galleryKey = Key('support-gallery');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _goldenTheme(),
        home: RepaintBoundary(
          key: galleryKey,
          child: PaperBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('显示', style: _goldenTheme().textTheme.titleMedium),
                      const SizedBox(height: 11),
                      SettingsGroup(
                        children: <Widget>[
                          const SettingsTile(
                            title: '字体',
                            subtitle: '日期与标题使用宋体，正文使用黑体',
                            trailing: Text('思源组合'),
                          ),
                          SettingsTile(
                            title: '通知声音',
                            subtitle: '事项提醒时播放声音',
                            trailing: DangguiSwitch(
                              value: true,
                              semanticLabel: '通知声音',
                              size: DangguiSwitchSize.compact,
                              onChanged: (_) {},
                            ),
                          ),
                          const SettingsTile(
                            title: '帮助与使用指南',
                            subtitle: '详细了解事项、过往、笔记与备份',
                            trailing: Icon(Icons.chevron_right),
                            showDivider: false,
                          ),
                        ],
                      ),
                      const Spacer(),
                      EditorToolbar(
                        items: <EditorToolbarItem>[
                          EditorToolbarItem(
                            icon: const Text('Aa'),
                            semanticLabel: '文本样式',
                            onPressed: () {},
                          ),
                          EditorToolbarItem(
                            icon: const Icon(Icons.format_list_bulleted),
                            semanticLabel: '项目符号',
                            onPressed: () {},
                          ),
                          EditorToolbarItem(
                            icon: const Icon(Icons.format_list_numbered),
                            semanticLabel: '编号',
                            onPressed: () {},
                          ),
                          EditorToolbarItem(
                            icon: const Icon(Icons.check_box_outlined),
                            semanticLabel: '清单',
                            selected: true,
                            onPressed: () {},
                          ),
                          EditorToolbarItem(
                            icon: const Icon(Icons.add),
                            semanticLabel: '插入',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(galleryKey),
      matchesGoldenFile(reviewedPlatformGolden('settings_and_toolbar.png')),
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

ThemeData _goldenTheme() {
  final base = DangguiTheme.light();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'DangguiDisplay'),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontFamily: 'DangguiDisplay', fontSize: 14),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontFamily: 'DangguiDisplay', fontSize: 14),
        ),
      ),
    ),
  );
}
