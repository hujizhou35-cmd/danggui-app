import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// The shared 58dp page toolbar. Safe-area handling belongs to the page shell.
class DangguiTopBar extends StatelessWidget {
  const DangguiTopBar({
    super.key,
    this.leading,
    this.content,
    this.actions = const <Widget>[],
    this.padding,
  });

  final Widget? leading;
  final Widget? content;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.fromLTRB(
              tokens.pageHorizontalPadding,
              4,
              tokens.pageHorizontalPadding,
              6,
            ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              if (content != null) const SizedBox(width: 10),
            ],
            if (content != null) Expanded(child: content!) else const Spacer(),
            if (actions.isNotEmpty) ...<Widget>[
              if (content != null || leading != null) const SizedBox(width: 10),
              for (var index = 0; index < actions.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                actions[index],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
