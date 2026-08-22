import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

enum DangguiSwitchSize { task, compact }

/// The 62×35 status switch from the approved task cards.
///
/// [DangguiSwitchSize.compact] renders the approved 45×26 settings control.
/// Both variants retain a hit target of at least 44dp.
class DangguiSwitch extends StatelessWidget {
  const DangguiSwitch({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.onChanged,
    this.size = DangguiSwitchSize.task,
  });

  final bool value;
  final String semanticLabel;
  final ValueChanged<bool>? onChanged;
  final DangguiSwitchSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final enabled = onChanged != null;
    final compact = size == DangguiSwitchSize.compact;
    final trackWidth = compact ? 45.0 : 62.0;
    final trackHeight = compact ? 26.0 : 35.0;
    final knobSize = compact ? 20.0 : 27.0;
    final trackPadding = compact ? 3.0 : 4.0;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          onHorizontalDragUpdate: enabled
              ? (details) {
                  final delta = details.primaryDelta ?? 0;
                  if (delta > 1 && !value) onChanged!(true);
                  if (delta < -1 && value) onChanged!(false);
                }
              : null,
          child: SizedBox(
            width: trackWidth,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: trackWidth,
                height: trackHeight,
                padding: EdgeInsets.all(trackPadding),
                decoration: BoxDecoration(
                  color: value ? tokens.sage : const Color(0xFFD4D0CA),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.ink.withAlpha(18)),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFDF8),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x2E27231F),
                          blurRadius: 7,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
