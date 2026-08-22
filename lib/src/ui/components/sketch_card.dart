import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// A deterministic hand-drawn card with a faint inner contour.
class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 17, 15),
    this.constraints = const BoxConstraints(minHeight: 98),
    this.alternate = false,
    this.muted = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.duration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;
  final bool alternate;
  final bool muted;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final radius = alternate ? tokens.cardRadiusB : tokens.cardRadiusA;
    final color = selected
        ? tokens.sageSoft.withAlpha(190)
        : muted
        ? tokens.paper3.withAlpha(204)
        : tokens.paper2.withAlpha(222);
    final borderColor = muted
        ? tokens.lineDark.withAlpha(178)
        : tokens.lineDark.withAlpha(209);

    Widget card = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      constraints: constraints,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: radius,
        boxShadow: <BoxShadow>[tokens.cardShadow],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 3, 5, 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.line.withAlpha(72)),
                          borderRadius: radius,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );

    if (semanticLabel != null || onTap != null || onLongPress != null) {
      card = Semantics(
        container: true,
        button: onTap != null || onLongPress != null,
        selected: selected,
        label: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
