import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feedback durations stay bounded by category', () {
    expect(dangguiSnackBarBriefDuration, const Duration(milliseconds: 1500));
    expect(dangguiSnackBarStandardDuration, const Duration(seconds: 3));
    expect(dangguiSnackBarActionDuration, const Duration(seconds: 4));
    expect(dangguiSnackBarErrorDuration, const Duration(seconds: 5));
  });

  testWidgets('action feedback is non-persistent and replaces stale messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DangguiTheme.light(),
        home: const Scaffold(body: SizedBox(key: Key('feedback-host'))),
      ),
    );
    final context = tester.element(find.byKey(const Key('feedback-host')));

    showDangguiSnackBar(
      context,
      message: 'first',
      duration: dangguiSnackBarErrorDuration,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('first'), findsOneWidget);

    showDangguiSnackBar(
      context,
      message: 'deleted',
      duration: dangguiSnackBarActionDuration,
      action: SnackBarAction(label: 'undo', onPressed: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('deleted'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, dangguiSnackBarActionDuration);
    expect(snackBar.persist, isFalse);

    await tester.pump(dangguiSnackBarActionDuration);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('deleted'), findsNothing);
  });
}
