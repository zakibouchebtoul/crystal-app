import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// The "speed arrow" from the design (flech.svg), drawn in code so no SVG
/// package is needed. Native size is 20 × 18; [width] scales it.
class StartArrowIcon extends StatelessWidget {
  const StartArrowIcon({
    super.key,
    this.width = 3,
    this.color = AppColors.primary,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 18 / 20),
      painter: _StartArrowPainter(color),
    );
  }
}

class _StartArrowPainter extends CustomPainter {
  const _StartArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20, size.height / 18);

    // Arrow head with its stem (path copied from flech.svg).
    final arrow = Path()
      ..moveTo(9.62, 0.219)
      ..cubicTo(9.473, 0.101, 9.295, 0.028, 9.108, 0.006)
      ..cubicTo(8.920, -0.015, 8.731, 0.017, 8.561, 0.098)
      ..cubicTo(8.391, 0.180, 8.247, 0.307, 8.146, 0.467)
      ..cubicTo(8.045, 0.626, 7.991, 0.810, 7.99, 0.999)
      ..lineTo(7.99, 4.999)
      ..lineTo(4.99, 4.999)
      ..cubicTo(4.44, 4.999, 3.99, 5.449, 3.99, 5.999)
      ..lineTo(3.99, 11.999)
      ..cubicTo(3.99, 12.549, 4.44, 12.999, 4.99, 12.999)
      ..lineTo(7.99, 12.999)
      ..lineTo(7.99, 16.999)
      ..cubicTo(7.991, 17.264, 8.097, 17.518, 8.284, 17.705)
      ..cubicTo(8.471, 17.892, 8.725, 17.998, 8.99, 17.999)
      ..cubicTo(9.21, 17.999, 9.43, 17.929, 9.61, 17.779)
      ..lineTo(19.61, 9.779)
      ..cubicTo(19.85, 9.589, 19.99, 9.299, 19.99, 8.999)
      ..cubicTo(19.99, 8.699, 19.85, 8.409, 19.61, 8.219)
      ..close()
      // Speed line on the left.
      ..addRect(const Rect.fromLTWH(0, 4.999, 2, 8));

    canvas.drawPath(arrow, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StartArrowPainter old) => old.color != color;
}
