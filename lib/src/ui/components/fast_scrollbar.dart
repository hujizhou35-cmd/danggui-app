import 'package:flutter/material.dart';

/// A persistent, draggable scrollbar for Danggui's long-form mobile surfaces.
///
/// The caller must give the same [controller] to the descendant scrollable.
/// Keeping that relationship explicit avoids accidental attachment to another
/// primary scroll view when a page contains horizontal lists or text fields.
class DangguiFastScrollbar extends StatelessWidget {
  const DangguiFastScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: false,
      // Material Scrollbar defaults to non-interactive on Android. This is a
      // fast scrollbar, so dragging and track taps must work on every platform.
      interactive: true,
      child: child,
    );
  }
}
