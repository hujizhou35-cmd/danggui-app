import 'package:flutter/material.dart';

import 'danggui_theme_extension.dart';

abstract final class DangguiTheme {
  static ThemeData light({
    bool compact = false,
    bool serifBody = false,
    String? sansFontFamily,
  }) {
    final tokens = compact
        ? DangguiThemeExtension.light.compact()
        : DangguiThemeExtension.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.sage,
          brightness: Brightness.light,
        ).copyWith(
          primary: tokens.sage,
          onPrimary: const Color(0xFFFFFDF8),
          primaryContainer: tokens.sageSoft,
          onPrimaryContainer: tokens.ink,
          secondary: tokens.brown,
          onSecondary: const Color(0xFFFFFDF8),
          secondaryContainer: tokens.paper3,
          onSecondaryContainer: tokens.ink,
          error: tokens.terra,
          onError: const Color(0xFFFFFDF8),
          errorContainer: tokens.terraSoft,
          onErrorContainer: tokens.ink,
          surface: tokens.paper2,
          onSurface: tokens.ink,
          outline: tokens.lineDark,
          outlineVariant: tokens.line,
          shadow: const Color(0x1A342A22),
          scrim: const Color(0x3D2D2722),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.paper,
      fontFamily: sansFontFamily,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    final body = base.textTheme.apply(
      fontFamily: serifBody ? 'DangguiDisplay' : sansFontFamily,
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );
    final textTheme = body.copyWith(
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.9),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 15, height: 1.65),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 12,
        color: tokens.muted,
        height: 1.45,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontFamily: 'DangguiDisplay',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontFamily: 'DangguiDisplay',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 13,
        color: tokens.muted,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      dividerColor: tokens.line,
      iconTheme: IconThemeData(color: tokens.ink, size: 21),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.paper2,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tokens.paper2,
        modalBarrierColor: const Color(0x3D2D2722),
        showDragHandle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted2),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF34302D),
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: tokens.paper2,
          fontSize: 13,
        ),
        actionTextColor: const Color(0xFFEBC7B9),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: tokens.controlRadius),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brown,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.sage,
          foregroundColor: const Color(0xFFFFFDF8),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: tokens.controlRadius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
