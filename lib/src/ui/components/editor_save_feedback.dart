import 'dart:async';

import 'package:flutter/material.dart';

import 'snack_bar_feedback.dart';

enum EditorSaveFeedbackState { idle, saving, saved, error }

/// Shared interaction state for the explicit save action in full-page editors.
///
/// Editors continue to autosave. This mixin gives the toolbar save affordance
/// an observable result without changing its "save and stay" meaning.
mixin EditorSaveFeedbackMixin<T extends StatefulWidget> on State<T> {
  Timer? _editorSaveFeedbackTimer;
  EditorSaveFeedbackState _editorSaveFeedbackState =
      EditorSaveFeedbackState.idle;

  EditorSaveFeedbackState get editorSaveFeedbackState =>
      _editorSaveFeedbackState;

  bool get editorSaveInProgress =>
      _editorSaveFeedbackState == EditorSaveFeedbackState.saving;

  Widget editorSaveFeedbackIcon({Key? key}) {
    final icon = switch (_editorSaveFeedbackState) {
      EditorSaveFeedbackState.saving => SizedBox(
        width: 18,
        height: 18,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      EditorSaveFeedbackState.saved => const Icon(Icons.check_rounded),
      EditorSaveFeedbackState.error => const Icon(Icons.error_outline_rounded),
      EditorSaveFeedbackState.idle => const Icon(Icons.save_outlined),
    };
    return KeyedSubtree(key: key, child: icon);
  }

  Future<void> runEditorManualSave({
    required Future<bool> Function() flush,
    required String savedLabel,
  }) async {
    if (editorSaveInProgress) return;
    _editorSaveFeedbackTimer?.cancel();
    setState(() {
      _editorSaveFeedbackState = EditorSaveFeedbackState.saving;
    });

    var saved = false;
    try {
      saved = await flush();
    } on Object catch (error) {
      if (mounted) {
        showDangguiSnackBar(
          context,
          message: error.toString(),
          duration: dangguiSnackBarErrorDuration,
        );
      }
    }
    if (!mounted) return;

    setState(() {
      _editorSaveFeedbackState = saved
          ? EditorSaveFeedbackState.saved
          : EditorSaveFeedbackState.error;
    });
    if (saved) {
      showDangguiSnackBar(
        context,
        message: savedLabel,
        duration: dangguiSnackBarBriefDuration,
      );
    }
    _editorSaveFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _editorSaveFeedbackState = EditorSaveFeedbackState.idle;
      });
    });
  }

  @protected
  void disposeEditorSaveFeedback() {
    _editorSaveFeedbackTimer?.cancel();
    _editorSaveFeedbackTimer = null;
  }
}
