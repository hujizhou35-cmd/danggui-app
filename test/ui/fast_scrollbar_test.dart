import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScrollbarPainter _scrollbarPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(DangguiFastScrollbar),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.foregroundPainter)
      .whereType<ScrollbarPainter>()
      .single;
}

void main() {
  testWidgets('short content does not paint an interactive thumb', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DangguiTheme.light().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: DangguiFastScrollbar(
              controller: controller,
              child: ListView(
                key: const Key('short-list'),
                controller: controller,
                children: const [
                  SizedBox(height: 56, child: Text('Row 1')),
                  SizedBox(height: 56, child: Text('Row 2')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.position.maxScrollExtent, 0);
    final painter = _scrollbarPainter(tester);
    final listSize = tester.getSize(find.byKey(const Key('short-list')));
    expect(
      painter.hitTestOnlyThumbInteractive(
        Offset(listSize.width - 7, 30),
        PointerDeviceKind.touch,
      ),
      isFalse,
    );
  });

  testWidgets('Android fast scrollbar stays visible and supports thumb drag', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DangguiTheme.light().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 240,
              child: DangguiFastScrollbar(
                controller: controller,
                child: ListView.builder(
                  key: const Key('long-list'),
                  controller: controller,
                  itemExtent: 56,
                  itemCount: 100,
                  itemBuilder: (context, index) => Text('Row $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.controller, same(controller));
    expect(
      tester.widget<ListView>(find.byKey(const Key('long-list'))).controller,
      same(controller),
    );
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.trackVisibility, isFalse);
    expect(scrollbar.interactive, isTrue);

    final theme = Theme.of(tester.element(find.byKey(const Key('long-list'))))
        .scrollbarTheme;
    expect(theme.minThumbLength, 44);
    expect(theme.crossAxisMargin, 4);
    expect(theme.thickness?.resolve(const <WidgetState>{}), 5);
    expect(
      theme.thickness?.resolve(const <WidgetState>{WidgetState.dragged}),
      7,
    );

    final painter = _scrollbarPainter(tester);
    final listSize = tester.getSize(find.byKey(const Key('long-list')));
    expect(
      painter.hitTestOnlyThumbInteractive(
        Offset(listSize.width - 7, 30),
        PointerDeviceKind.touch,
      ),
      isTrue,
    );

    final listRect = tester.getRect(find.byKey(const Key('long-list')));
    await tester.dragFrom(
      Offset(listRect.right - 7, listRect.top + 30),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('iOS fast scrollbar uses the native Cupertino control', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DangguiTheme.light().copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: DangguiFastScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 30,
              itemBuilder: (context, index) => Text('Row $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(CupertinoScrollbar), findsOneWidget);
  });

  testWidgets('fast scrollbar controls an expanding text editor', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final textController = TextEditingController(
      text: List<String>.generate(100, (index) => 'Line $index').join('\n'),
    );
    addTearDown(scrollController.dispose);
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DangguiTheme.light().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: DangguiFastScrollbar(
              controller: scrollController,
              child: TextField(
                key: const Key('long-editor'),
                controller: textController,
                scrollController: scrollController,
                expands: true,
                minLines: null,
                maxLines: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('long-editor')))
          .scrollController,
      same(scrollController),
    );

    final editorRect = tester.getRect(find.byKey(const Key('long-editor')));
    await tester.dragFrom(
      Offset(editorRect.right - 7, editorRect.top + 30),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
  });
}
