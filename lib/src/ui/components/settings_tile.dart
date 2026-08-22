import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// A responsive settings row. It grows vertically for long translations and
/// large accessibility text rather than clipping either side of the row.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showDivider = true,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool showDivider;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final titleColor = danger ? tokens.terra : tokens.ink;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 57),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: titleColor, height: 1.35),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );

    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: tokens.lineDark.withAlpha(122)))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
    if (onTap != null || semanticLabel != null) {
      result = Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        child: result,
      );
    }
    return result;
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.elliptical(21, 18),
      topRight: const Radius.elliptical(18, 23),
      bottomRight: const Radius.elliptical(23, 19),
      bottomLeft: const Radius.elliptical(19, 22),
    );
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper2.withAlpha(171),
          border: Border.all(color: tokens.lineDark.withAlpha(184)),
          borderRadius: radius,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
