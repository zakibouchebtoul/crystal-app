import 'package:flutter/material.dart';

/// Thin magnifying glass from the design (akar-icons search), drawn in code
/// so no SVG package is needed. Native size is 20 × 20.
class SearchIcon extends StatelessWidget {
  const SearchIcon({
    super.key,
    this.size = 20,
    this.color = const Color(0xFFB3BCC3),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SearchIconPainter(color),
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  const _SearchIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas
      ..drawCircle(const Offset(8.75, 8.75), 7.083, paint)
      ..drawLine(const Offset(13.762, 13.755), const Offset(17.5, 17.5), paint);
  }

  @override
  bool shouldRepaint(_SearchIconPainter old) => old.color != color;
}
