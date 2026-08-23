import 'package:flutter/material.dart';

import 'ime_inset_guard.dart';
import 'paper_background.dart';

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
