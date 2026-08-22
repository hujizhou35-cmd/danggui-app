import 'package:danggui/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DangguiTheme exposes the approved palette and density variants', () {
    final regular = DangguiTheme.light();
    final compact = DangguiTheme.light(compact: true);
    final regularTokens = regular.extension<DangguiThemeExtension>()!;
    final compactTokens = compact.extension<DangguiThemeExtension>()!;

    expect(regular.scaffoldBackgroundColor, const Color(0xFFF4EFE7));
    expect(regular.colorScheme.primary, const Color(0xFF6F8068));
    expect(regularTokens.ink, const Color(0xFF2E2925));
    expect(regularTokens.cardGap, 14);
    expect(compactTokens.cardGap, 9);
    expect(compactTokens.cardPadding, 13);
  });

  test('theme extension lerps geometry and colors', () {
    const source = DangguiThemeExtension.light;
    final target = source.copyWith(paper: Colors.white, cardGap: 10);
    final middle = source.lerp(target, .5);

    expect(middle.paper, Color.lerp(source.paper, Colors.white, .5));
    expect(middle.cardGap, 12);
    expect(middle.cardRadiusA, isNotNull);
  });
}
