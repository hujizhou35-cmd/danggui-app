import 'dart:async';

import 'package:flutter/material.dart';

import 'ime_inset_guard.dart';
import 'paper_background.dart';

/// Waits until a [PopScope.canPop] change has crossed a rendered-frame
/// boundary before an editor asks its Navigator to pop.
///
/// Editor saves finish asynchronously and can resume during the current
/// frame's post-frame phase. A single post-frame callback may therefore run
/// before the updated `canPop` value has been built, causing the Navigator to
/// reject the pop with the stale value. Two bounded frame callbacks guarantee
/// that at least one build has applied the permission change.
Future<void> waitForEditorRoutePopBarrier() {
  final binding = WidgetsBinding.instance;
  final completer = Completer<void>();
  binding.addPostFrameCallback((_) {
    binding.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    binding.scheduleFrame();
  });
  binding.scheduleFrame();
  return completer.future;
}

/// Shared, single-inset layout for full-page and shell-hosted editors.
///
/// The caller owns the surrounding [Scaffold]. That Scaffold must set
/// `resizeToAvoidBottomInset: false` so this frame remains the only layer that
/// responds to the IME.
class EditorPageFrame extends StatelessWidget {
  const EditorPageFrame({
    super.key,
    required this.topBar,
    required this.editor,
    required this.toolbar,
    this.includeBottomSafeArea = true,
    this.insetAnimationDuration = const Duration(milliseconds: 180),
  });

  static const topBarKey = Key('editor-page-top-bar');
  static const editorKey = Key('editor-page-body');
  static const toolbarKey = Key('editor-page-toolbar');
  static const insetPaddingKey = Key('editor-page-inset-padding');

  final Widget topBar;
  final Widget editor;
  final Widget toolbar;
  final bool includeBottomSafeArea;
  final Duration insetAnimationDuration;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: PaperBackground(
        child: ImeInsetGuard(
          child: Builder(
            builder: (context) {
              return AnimatedPadding(
                key: insetPaddingKey,
                duration: insetAnimationDuration,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: <Widget>[
                      KeyedSubtree(key: topBarKey, child: topBar),
                      Expanded(
                        child: KeyedSubtree(key: editorKey, child: editor),
                      ),
                      SafeArea(
                        top: false,
                        bottom: includeBottomSafeArea,
                        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: KeyedSubtree(key: toolbarKey, child: toolbar),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
