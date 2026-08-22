import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// A 39dp hand-drawn control inside a standards-compliant 44dp hit target.
class DangguiIconButton extends StatelessWidget {
  const DangguiIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.selected = false,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    Widget result = Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onPressed,
            radius: 24,
            containedInkWell: true,
            highlightShape: BoxShape.rectangle,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: selected
                        ? tokens.paper3
                        : tokens.paper2.withAlpha(163),
                    border: Border.all(
                      color: tokens.muted.withAlpha(90),
                      width: 1.2,
                    ),
                    borderRadius: tokens.controlRadius,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: tokens.ink, size: 21),
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return result;
  }
}
