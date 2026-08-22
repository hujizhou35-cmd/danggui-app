import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

@immutable
class EditorToolbarItem {
  const EditorToolbarItem({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.selected = false,
    this.tooltip,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool selected;
  final String? tooltip;
}

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key, required this.items})
    : assert(items.length > 0 && items.length <= 6);

  final List<EditorToolbarItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.elliptical(18, 16),
      topRight: const Radius.elliptical(16, 19),
      bottomRight: const Radius.elliptical(19, 15),
      bottomLeft: const Radius.elliptical(15, 18),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: tokens.paper2.withAlpha(240),
        border: Border.all(color: tokens.line),
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          tokens.cardShadow.copyWith(
            color: const Color(0x1A3C3128),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          children: items
              .map((item) {
                Widget button = Semantics(
                  button: true,
                  enabled: item.onPressed != null,
                  selected: item.selected,
                  label: item.semanticLabel,
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: item.onPressed,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: item.selected
                                    ? tokens.paper3
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconTheme(
                                data: IconThemeData(
                                  color: tokens.ink,
                                  size: 20,
                                ),
                                child: Center(child: item.icon),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                if (item.tooltip != null) {
                  button = Tooltip(message: item.tooltip!, child: button);
                }
                return Expanded(child: button);
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}
