import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Design tokens shared by every Danggui surface.
///
/// Keeping the hand-drawn geometry here makes the visual language consistent
/// and, importantly, deterministic for golden tests.
@immutable
class DangguiThemeExtension extends ThemeExtension<DangguiThemeExtension> {
  const DangguiThemeExtension({
    required this.paper,
    required this.paper2,
    required this.paper3,
    required this.ink,
    required this.muted,
    required this.muted2,
    required this.line,
    required this.lineDark,
    required this.sage,
    required this.sageSoft,
    required this.terra,
    required this.terraSoft,
    required this.brown,
    required this.cardShadow,
    required this.modalShadow,
    required this.cardRadiusA,
    required this.cardRadiusB,
    required this.controlRadius,
    required this.sheetRadius,
    required this.pageHorizontalPadding,
    required this.detailHorizontalPadding,
    required this.cardGap,
    required this.cardPadding,
  });

  static const light = DangguiThemeExtension(
    paper: Color(0xFFF4EFE7),
    paper2: Color(0xFFFBF8F2),
    paper3: Color(0xFFEFE7DC),
    ink: Color(0xFF2E2925),
    muted: Color(0xFF81786F),
    muted2: Color(0xFFAAA197),
    line: Color(0xFFD8CEC1),
    lineDark: Color(0xFFBEB2A4),
    sage: Color(0xFF6F8068),
    sageSoft: Color(0xFFDCE5D8),
    terra: Color(0xFFB5684C),
    terraSoft: Color(0xFFF0DDD4),
    brown: Color(0xFF8A654A),
    cardShadow: BoxShadow(
      color: Color(0x0E43352B),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
    modalShadow: BoxShadow(
      color: Color(0x1A342A22),
      blurRadius: 36,
      offset: Offset(0, 14),
    ),
    cardRadiusA: BorderRadius.only(
      topLeft: Radius.elliptical(23, 19),
      topRight: Radius.elliptical(19, 25),
      bottomRight: Radius.elliptical(25, 20),
      bottomLeft: Radius.elliptical(20, 24),
    ),
    cardRadiusB: BorderRadius.only(
      topLeft: Radius.elliptical(20, 24),
      topRight: Radius.elliptical(24, 19),
      bottomRight: Radius.elliptical(19, 25),
      bottomLeft: Radius.elliptical(25, 20),
    ),
    controlRadius: BorderRadius.only(
      topLeft: Radius.elliptical(15, 13),
      topRight: Radius.elliptical(13, 16),
      bottomRight: Radius.elliptical(16, 12),
      bottomLeft: Radius.elliptical(12, 17),
    ),
    sheetRadius: BorderRadius.only(
      topLeft: Radius.elliptical(28, 25),
      topRight: Radius.elliptical(25, 30),
    ),
    pageHorizontalPadding: 17,
    detailHorizontalPadding: 24,
    cardGap: 14,
    cardPadding: 18,
  );

  final Color paper;
  final Color paper2;
  final Color paper3;
  final Color ink;
  final Color muted;
  final Color muted2;
  final Color line;
  final Color lineDark;
  final Color sage;
  final Color sageSoft;
  final Color terra;
  final Color terraSoft;
  final Color brown;

  final BoxShadow cardShadow;
  final BoxShadow modalShadow;
  final BorderRadius cardRadiusA;
  final BorderRadius cardRadiusB;
  final BorderRadius controlRadius;
  final BorderRadius sheetRadius;

  final double pageHorizontalPadding;
  final double detailHorizontalPadding;
  final double cardGap;
  final double cardPadding;

  DangguiThemeExtension compact() => copyWith(cardGap: 9, cardPadding: 13);

  @override
  DangguiThemeExtension copyWith({
    Color? paper,
    Color? paper2,
    Color? paper3,
    Color? ink,
    Color? muted,
    Color? muted2,
    Color? line,
    Color? lineDark,
    Color? sage,
    Color? sageSoft,
    Color? terra,
    Color? terraSoft,
    Color? brown,
    BoxShadow? cardShadow,
    BoxShadow? modalShadow,
    BorderRadius? cardRadiusA,
    BorderRadius? cardRadiusB,
    BorderRadius? controlRadius,
    BorderRadius? sheetRadius,
    double? pageHorizontalPadding,
    double? detailHorizontalPadding,
    double? cardGap,
    double? cardPadding,
  }) {
    return DangguiThemeExtension(
      paper: paper ?? this.paper,
      paper2: paper2 ?? this.paper2,
      paper3: paper3 ?? this.paper3,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      line: line ?? this.line,
      lineDark: lineDark ?? this.lineDark,
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      terra: terra ?? this.terra,
      terraSoft: terraSoft ?? this.terraSoft,
      brown: brown ?? this.brown,
      cardShadow: cardShadow ?? this.cardShadow,
      modalShadow: modalShadow ?? this.modalShadow,
      cardRadiusA: cardRadiusA ?? this.cardRadiusA,
      cardRadiusB: cardRadiusB ?? this.cardRadiusB,
      controlRadius: controlRadius ?? this.controlRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      pageHorizontalPadding:
          pageHorizontalPadding ?? this.pageHorizontalPadding,
      detailHorizontalPadding:
          detailHorizontalPadding ?? this.detailHorizontalPadding,
      cardGap: cardGap ?? this.cardGap,
      cardPadding: cardPadding ?? this.cardPadding,
    );
  }

  @override
  DangguiThemeExtension lerp(covariant DangguiThemeExtension other, double t) {
    return DangguiThemeExtension(
      paper: Color.lerp(paper, other.paper, t)!,
      paper2: Color.lerp(paper2, other.paper2, t)!,
      paper3: Color.lerp(paper3, other.paper3, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineDark: Color.lerp(lineDark, other.lineDark, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageSoft: Color.lerp(sageSoft, other.sageSoft, t)!,
      terra: Color.lerp(terra, other.terra, t)!,
      terraSoft: Color.lerp(terraSoft, other.terraSoft, t)!,
      brown: Color.lerp(brown, other.brown, t)!,
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
      modalShadow: BoxShadow.lerp(modalShadow, other.modalShadow, t)!,
      cardRadiusA: BorderRadius.lerp(cardRadiusA, other.cardRadiusA, t)!,
      cardRadiusB: BorderRadius.lerp(cardRadiusB, other.cardRadiusB, t)!,
      controlRadius: BorderRadius.lerp(controlRadius, other.controlRadius, t)!,
      sheetRadius: BorderRadius.lerp(sheetRadius, other.sheetRadius, t)!,
      pageHorizontalPadding: ui.lerpDouble(
        pageHorizontalPadding,
        other.pageHorizontalPadding,
        t,
      )!,
      detailHorizontalPadding: ui.lerpDouble(
        detailHorizontalPadding,
        other.detailHorizontalPadding,
        t,
      )!,
      cardGap: ui.lerpDouble(cardGap, other.cardGap, t)!,
      cardPadding: ui.lerpDouble(cardPadding, other.cardPadding, t)!,
    );
  }
}

extension DangguiThemeContext on BuildContext {
  DangguiThemeExtension get dangguiTheme =>
      Theme.of(this).extension<DangguiThemeExtension>() ??
      DangguiThemeExtension.light;
}
