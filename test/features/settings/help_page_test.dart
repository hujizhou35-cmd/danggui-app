import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/features/settings/help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the Chinese offline guide and searches its contents', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_testApp(const HelpPage()));
    await tester.pumpAndSettle();

    expect(find.text('帮助与操作指南'), findsOneWidget);
    expect(find.text('事项'), findsWidgets);
    expect(find.text('过往'), findsWidgets);
    expect(find.textContaining('所有内容默认只保存在当前设备'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '卡片会把提醒');
    await tester.pumpAndSettle();

    expect(find.textContaining('同日提醒显示'), findsOneWidget);
    expect(find.text('过往'), findsNothing);

    await tester.enterText(find.byType(TextField), 'not-present-anywhere');
    await tester.pumpAndSettle();

    expect(find.text('没有找到相关帮助'), findsOneWidget);
  });

  testWidgets('loads the matching English guide without a network source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const HelpPage(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Help & operation guide'), findsOneWidget);
    expect(
      find.textContaining('Your content stays on this device'),
      findsOneWidget,
    );
  });
}

Widget _testApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const <Locale>[
      Locale('zh'),
      Locale('en'),
      Locale('ja'),
      Locale('ru'),
    ],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: DangguiTheme.light(),
    home: home,
  );
}
