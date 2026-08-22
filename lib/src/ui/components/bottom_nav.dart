import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

@immutable
class DangguiNavigationDestination {
  const DangguiNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.semanticLabel,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  final String? semanticLabel;
}

class DangguiBottomNav extends StatelessWidget {
  const DangguiBottomNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  }) : assert(destinations.length >= 2);

  final List<DangguiNavigationDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF7F7F3EC),
        border: Border(top: BorderSide(color: tokens.lineDark.withAlpha(140))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          height: 77,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            child: Row(
              children: List<Widget>.generate(destinations.length, (index) {
                final destination = destinations[index];
                final selected = index == currentIndex;
                final color = selected ? tokens.ink : tokens.muted2;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: destination.semanticLabel ?? destination.label,
                    onTap: () => onTap(index),
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: () => onTap(index),
                          radius: 32,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconTheme(
                                  data: IconThemeData(
                                    color: color,
                                    size: 23,
                                    weight: selected ? 700 : 400,
                                  ),
                                  child: selected
                                      ? destination.selectedIcon ??
                                            destination.icon
                                      : destination.icon,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  destination.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
