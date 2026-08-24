import 'dart:async';

import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ImeInsetGuard ignores a stale inset without editable focus', (
    tester,
  ) async {
    _setView(tester, const Size(412, 915));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);

    await tester.pumpWidget(
      _testApp(
        ImeInsetGuard(
          child: Builder(
            builder: (context) => Text(
              '${MediaQuery.viewInsetsOf(context).bottom}',
              key: const Key('reported-inset'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0.0'), findsOneWidget);
  });

  testWidgets('ImeInsetGuard preserves the inset only for editable focus', (
    tester,
  ) async {
    _setView(tester, const Size(412, 915));
    await tester.pumpWidget(
      _testApp(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: ImeInsetGuard(
            child: Builder(
              builder: (context) => Column(
                children: <Widget>[
                  Text(
                    '${MediaQuery.viewInsetsOf(context).bottom}',
                    key: const Key('reported-inset'),
                  ),
                  const TextField(key: Key('editable-field')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('editable-field')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.text('300.0'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(
      find.text('0.0'),
      findsOneWidget,
      reason: 'a residual platform inset must not keep the page collapsed',
    );
  });

  testWidgets('EditorPageFrame keeps its top bar and toolbar above the IME', (
    tester,
  ) async {
    _setView(tester, const Size(320, 568));
    await tester.pumpWidget(
      _testApp(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: EditorPageFrame(
                topBar: const SizedBox(
                  key: Key('test-top-bar'),
                  height: 56,
                  child: Text('Top'),
                ),
                editor: const TextField(
                  key: Key('test-editor'),
                  expands: true,
                  minLines: null,
                  maxLines: null,
                ),
                toolbar: const SizedBox(
                  key: Key('test-toolbar'),
                  height: 50,
                  child: Text('Toolbar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final initialToolbarBottom = tester
        .getBottomLeft(find.byKey(const Key('test-toolbar')))
        .dy;
    await tester.tap(find.byKey(const Key('test-editor')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-top-bar')), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const Key('test-toolbar'))).dy,
      lessThanOrEqualTo(268),
    );
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const Key('test-toolbar'))).dy,
      initialToolbarBottom,
    );
  });

  testWidgets('waitForImeToDismiss observes raw metrics until zero', (
    tester,
  ) async {
    _setView(tester, const Size(412, 915));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    late BuildContext guardedContext;
    await tester.pumpWidget(
      _testApp(
        Builder(
          builder: (context) {
            guardedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    var completed = false;
    unawaited(
      waitForImeToDismiss(
        guardedContext,
        timeout: const Duration(seconds: 1),
      ).then((_) => completed = true),
    );
    await tester.pump();
    expect(completed, isFalse);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(completed, isTrue);
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(theme: DangguiTheme.light(), home: home);
}

void _setView(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
