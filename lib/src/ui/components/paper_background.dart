import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// The warm, subtly textured paper surface used by every top-level page.
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    super.key,
    required this.child,
    this.padding,
    this.includeTexture = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool includeTexture;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return ColoredBox(
      color: tokens.paper,
      child: CustomPaint(
        painter: includeTexture
            ? _PaperTexturePainter(paper: tokens.paper, line: tokens.brown)
            : null,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter({required this.paper, required this.line});

  final Color paper;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = paper);

    final upperGlow =
        RadialGradient(
          colors: <Color>[const Color(0xB3FFFFFF), const Color(0x00FFFFFF)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * .84, size.height * .15),
            radius: size.shortestSide * .42,
          ),
        );
    canvas.drawRect(bounds, Paint()..shader = upperGlow);

    final lowerGlow =
        RadialGradient(
          colors: <Color>[const Color(0x4DFFFFFF), const Color(0x00FFFFFF)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * .1, size.height * .82),
            radius: size.shortestSide * .34,
          ),
        );
    canvas.drawRect(bounds, Paint()..shader = lowerGlow);

    final grain = Paint()
      ..color = line.withAlpha(4)
      ..strokeWidth = .5;
    for (double y = .5; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grain);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.line != line;
}
