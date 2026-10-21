import 'package:flutter/material.dart';

import 'svg_path.dart';

/// Thin back arrow from the design (famicons arrow-back-outline), drawn in
/// code. [forward] mirrors it to point right.
class ArrowIcon extends StatelessWidget {
  const ArrowIcon({
    super.key,
    this.size = 16,
    this.color = const Color(0xFF0D0D12),
    this.forward = false,
  });

  final double size;
  final Color color;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _ArrowPainter(color),
    );
    return forward ? Transform.flip(flipX: true, child: icon) : icon;
  }
}

final _arrow = parseSvgPath('M7.625 12.5L3.125 8L7.625 3.5M3.75 8H12.875');

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16);
    canvas.drawPath(
      _arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}
