import 'package:flutter/material.dart';

const dangguiSnackBarBriefDuration = Duration(milliseconds: 1500);
const dangguiSnackBarStandardDuration = Duration(seconds: 3);
const dangguiSnackBarActionDuration = Duration(seconds: 4);
const dangguiSnackBarErrorDuration = Duration(seconds: 5);

/// Shows one bounded piece of transient feedback, replacing stale messages.
///
/// [SnackBar.persist] is explicitly disabled because action snack bars persist
/// by default on current Flutter releases. Undo remains available for the full
/// requested duration, then dismisses without user intervention.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showDangguiSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = dangguiSnackBarStandardDuration,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
      action: action,
    ),
  );
}
