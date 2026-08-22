import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'danggui_switch.dart';
import 'sketch_card.dart';

enum TaskCardStatus { active, completionPending }

/// Presentation-only schedule data for a task card.
///
/// Dates and time arrive already localized. This class only applies the four
/// approved information layouts, so it never needs a localization dependency.
@immutable
class TaskCardSchedule {
  const TaskCardSchedule({
    this.taskDateLabel,
    this.reminderDateLabel,
    this.reminderTimeLabel,
    this.reminderIsOnTaskDate,
    this.reminderSuffix = '提醒',
    this.openingParenthesis = '（',
    this.closingParenthesis = '）',
  });

  final String? taskDateLabel;
  final String? reminderDateLabel;
  final String? reminderTimeLabel;
  final bool? reminderIsOnTaskDate;
  final String reminderSuffix;
  final String openingParenthesis;
  final String closingParenthesis;

  String? get displayLabel {
    final taskDate = _clean(taskDateLabel);
    final reminderDate = _clean(reminderDateLabel);
    final reminderTime = _clean(reminderTimeLabel);
    if (reminderTime == null) return taskDate;

    final sameDay =
        reminderIsOnTaskDate ??
        (taskDate != null && reminderDate != null && taskDate == reminderDate);
    final reminderParts = <String>[
      if ((!sameDay || taskDate == null) && reminderDate != null) reminderDate,
      reminderTime,
      if (reminderSuffix.trim().isNotEmpty) reminderSuffix.trim(),
    ];
    final reminder = reminderParts.join(' ');
    if (taskDate == null) return reminder;
    return '$taskDate$openingParenthesis$reminder$closingParenthesis';
  }

  static String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.title,
    required this.switchSemanticLabel,
    required this.addToPastLabel,
    required this.deleteLabel,
    this.schedule = const TaskCardSchedule(),
    this.status = TaskCardStatus.active,
    this.alternate = false,
    this.onTap,
    this.onStatusChanged,
    this.onAddToPast,
    this.onDelete,
    this.semanticLabel,
  });

  final String title;
  final TaskCardSchedule schedule;
  final TaskCardStatus status;
  final bool alternate;
  final String switchSemanticLabel;
  final String addToPastLabel;
  final String deleteLabel;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onStatusChanged;
  final VoidCallback? onAddToPast;
  final VoidCallback? onDelete;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final isPending = status == TaskCardStatus.completionPending;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SketchCard(
      alternate: alternate,
      muted: isPending,
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: textScale > 1.3 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 12),
              DangguiSwitch(
                value: !isPending,
                semanticLabel: switchSemanticLabel,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (isPending)
            _TaskActions(
              addToPastLabel: addToPastLabel,
              deleteLabel: deleteLabel,
              onAddToPast: onAddToPast,
              onDelete: onDelete,
            )
          else
            SizedBox(
              // The pending action row uses the same fixed bottom region. A
              // single-line ellipsis keeps translated reminders usable at
              // large text sizes without changing the card's rhythm.
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  schedule.displayLabel ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: tokens.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.addToPastLabel,
    required this.deleteLabel,
    this.onAddToPast,
    this.onDelete,
  });

  final String addToPastLabel;
  final String deleteLabel;
  final VoidCallback? onAddToPast;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextButton(
              onPressed: onAddToPast,
              style: TextButton.styleFrom(
                foregroundColor: tokens.brown,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                addToPastLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: tokens.terra,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                deleteLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
