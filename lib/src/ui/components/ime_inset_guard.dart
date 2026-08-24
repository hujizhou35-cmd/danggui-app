import 'dart:async';

import 'package:flutter/material.dart';

/// Removes a stale keyboard inset when no editable control owns focus.
///
/// Some platform/IME combinations can leave [MediaQueryData.viewInsets]
/// reporting the last keyboard height after the keyboard has already closed.
/// Keeping the correction local to editor layouts prevents an unrelated focus
/// target (for example, a search field or a menu) from collapsing the page.
class ImeInsetGuard extends StatefulWidget {
  const ImeInsetGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ImeInsetGuard> createState() => _ImeInsetGuardState();
}

class _ImeInsetGuardState extends State<ImeInsetGuard>
    with WidgetsBindingObserver {
  var _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleRebuild();
  }

  void _handleFocusChanged() {
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    scheduleMicrotask(() {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = _editableTextHasFocus()
        ? mediaQuery.viewInsets.bottom
        : 0.0;
    return MediaQuery(
      data: mediaQuery.copyWith(
        viewInsets: mediaQuery.viewInsets.copyWith(bottom: bottomInset),
      ),
      child: widget.child,
    );
  }
}

bool _editableTextHasFocus() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !focus.hasFocus) return false;
  final focusContext = focus.context;
  if (focusContext == null) return false;
  return focusContext.widget is EditableText ||
      focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Waits for the platform keyboard inset to reach zero, with a bounded timeout.
///
/// This reads the raw [FlutterView] instead of the guarded [MediaQuery], so it
/// remains useful after a caller unfocuses an editor. It is intended for route
/// transitions that must not inherit an outgoing keyboard animation.
Future<void> waitForImeToDismiss(
  BuildContext context, {
  Duration timeout = const Duration(milliseconds: 400),
}) async {
  final view = View.of(context);
  if (view.viewInsets.bottom <= 0) return;

  final completer = Completer<void>();
  late final _ImeDismissObserver observer;
  void completeIfDismissed() {
    if (!completer.isCompleted && view.viewInsets.bottom <= 0) {
      completer.complete();
    }
  }

  observer = _ImeDismissObserver(completeIfDismissed);
  WidgetsBinding.instance.addObserver(observer);
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete();
  });
  try {
    completeIfDismissed();
    await completer.future;
  } finally {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(observer);
  }
}

class _ImeDismissObserver with WidgetsBindingObserver {
  const _ImeDismissObserver(this.onMetricsChanged);

  final VoidCallback onMetricsChanged;

  @override
  void didChangeMetrics() {
    onMetricsChanged();
  }
}
