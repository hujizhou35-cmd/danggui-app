import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// The hand-drawn time wheel used by task reminders.
///
/// All visible strings are supplied by the caller. When [dateLabel] is set, a
/// 44dp date row is displayed above the wheels so cross-day reminders remain
/// editable without introducing a second visual language.
class ReminderDialog extends StatefulWidget {
  const ReminderDialog({
    super.key,
    required this.title,
    required this.selectedTime,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.hourSemanticLabel,
    required this.minuteSemanticLabel,
    required this.onCancel,
    required this.onConfirm,
    this.dateLabel,
    this.dateSemanticLabel,
    this.onDatePressed,
    this.onTimeChanged,
    this.minuteStep = 5,
  }) : assert(minuteStep > 0 && 60 % minuteStep == 0);

  final String title;
  final TimeOfDay selectedTime;
  final String cancelLabel;
  final String confirmLabel;
  final String hourSemanticLabel;
  final String minuteSemanticLabel;
  final String? dateLabel;
  final String? dateSemanticLabel;
  final VoidCallback? onDatePressed;
  final VoidCallback onCancel;
  final ValueChanged<TimeOfDay> onConfirm;
  final ValueChanged<TimeOfDay>? onTimeChanged;
  final int minuteStep;

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  static const _loopAnchor = 1200;

  late int _hour;
  late int _minuteIndex;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  int get _minuteCount => 60 ~/ widget.minuteStep;
  int get _minute => _minuteIndex * widget.minuteStep;

  @override
  void initState() {
    super.initState();
    _hour = widget.selectedTime.hour;
    _minuteIndex =
        (widget.selectedTime.minute / widget.minuteStep).round() % _minuteCount;
    _hourController = FixedExtentScrollController(
      initialItem: _anchoredIndex(_loopAnchor, 24, _hour),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _anchoredIndex(_loopAnchor, _minuteCount, _minuteIndex),
    );
  }

  @override
  void didUpdateWidget(covariant ReminderDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextMinuteIndex =
        (widget.selectedTime.minute / widget.minuteStep).round() % _minuteCount;
    if (widget.selectedTime.hour != _hour) {
      _hour = widget.selectedTime.hour;
      _hourController.jumpToItem(_anchoredIndex(_loopAnchor, 24, _hour));
    }
    if (nextMinuteIndex != _minuteIndex ||
        oldWidget.minuteStep != widget.minuteStep) {
      _minuteIndex = nextMinuteIndex;
      _minuteController.dispose();
      _minuteController = FixedExtentScrollController(
        initialItem: _anchoredIndex(_loopAnchor, _minuteCount, _minuteIndex),
      );
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: SizedBox(
          width: 310,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.paper2,
              border: Border.all(color: tokens.lineDark),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.elliptical(26, 22),
                topRight: const Radius.elliptical(22, 28),
                bottomRight: const Radius.elliptical(28, 22),
                bottomLeft: const Radius.elliptical(23, 27),
              ),
              boxShadow: <BoxShadow>[tokens.modalShadow],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 19),
                  ),
                  if (widget.dateLabel != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Semantics(
                      button: widget.onDatePressed != null,
                      label: widget.dateSemanticLabel ?? widget.dateLabel,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onDatePressed,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    widget.dateLabel!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: tokens.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 17),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: tokens.line),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _TimeWheel(
                          controller: _hourController,
                          modulus: 24,
                          selectedValue: _hour,
                          semanticLabel: widget.hourSemanticLabel,
                          onChanged: (value) {
                            setState(() => _hour = value);
                            _notifyChanged();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ':',
                            style: TextStyle(fontSize: 25, color: tokens.muted),
                          ),
                        ),
                        _TimeWheel(
                          controller: _minuteController,
                          modulus: _minuteCount,
                          selectedValue: _minuteIndex,
                          semanticLabel: widget.minuteSemanticLabel,
                          valueFormatter: (value) =>
                              _twoDigits(value * widget.minuteStep),
                          onChanged: (value) {
                            setState(() => _minuteIndex = value);
                            _notifyChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: <Widget>[
                      TextButton(
                        onPressed: widget.onCancel,
                        child: Text(widget.cancelLabel),
                      ),
                      FilledButton(
                        onPressed: () => widget.onConfirm(_currentTime),
                        child: Text(widget.confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TimeOfDay get _currentTime => TimeOfDay(hour: _hour, minute: _minute);

  void _notifyChanged() => widget.onTimeChanged?.call(_currentTime);

  static int _anchoredIndex(int anchor, int modulus, int value) =>
      anchor - anchor % modulus + value;

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.modulus,
    required this.selectedValue,
    required this.semanticLabel,
    required this.onChanged,
    this.valueFormatter = _defaultFormatter,
  });

  final FixedExtentScrollController controller;
  final int modulus;
  final int selectedValue;
  final String semanticLabel;
  final ValueChanged<int> onChanged;
  final String Function(int value) valueFormatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Semantics(
      container: true,
      label: semanticLabel,
      value: valueFormatter(selectedValue),
      child: SizedBox(
        width: 76,
        height: 132,
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: 44,
          diameterRatio: 1.7,
          perspective: .004,
          useMagnifier: false,
          onSelectedItemChanged: (index) => onChanged(index % modulus),
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              final value = index % modulus;
              final selected = value == selectedValue;
              return Center(
                child: Text(
                  valueFormatter(value),
                  style: TextStyle(
                    color: selected ? tokens.ink : tokens.muted2,
                    fontSize: selected ? 32 : 18,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _defaultFormatter(int value) =>
      value.toString().padLeft(2, '0');
}
