import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Light line-art doodles and floating outline circles behind the white
/// sign-in screens. Positions come from the mockups (402 × 874) and scale
/// with the screen.
class DoodleBackground extends StatefulWidget {
  const DoodleBackground._({
    super.key,
    required List<_Doodle> doodles,
    required List<Offset> circles,
  }) : _doodles = doodles,
       _circles = circles;

  /// Layout of the "Login or create an account" screen.
  const DoodleBackground.login({Key? key})
    : this._(
        key: key,
        doodles: const [
          _Doodle(_broom, Rect.fromLTWH(245, 31, 129, 129)),
          _Doodle(_petTimer, Rect.fromLTWH(246, 319, 153, 153)),
          _Doodle(_house, Rect.fromLTWH(105, 597, 104, 104)),
        ],
        circles: const [
          Offset(124, 66),
          Offset(306, 632),
          Offset(363, 692),
          Offset(57, 764),
        ],
      );

  /// Layout of the "Choose your account type" screen.
  const DoodleBackground.accountType({Key? key})
    : this._(
        key: key,
        doodles: const [
          _Doodle(_broom, Rect.fromLTWH(245, 31, 129, 129)),
          _Doodle(_petTimer, Rect.fromLTWH(237, 465, 153, 153)),
          _Doodle(_house, Rect.fromLTWH(116, 597, 104, 104)),
        ],
        circles: const [
          Offset(124, 66),
          Offset(363, 692),
          Offset(57, 764),
          Offset(204, 805),
        ],
      );

  final List<_Doodle> _doodles;

  /// Circle centers in mockup coordinates.
  final List<Offset> _circles;

  static const preload = [_broom, _petTimer, _house];

  @override
  State<DoodleBackground> createState() => _DoodleBackgroundState();
}

const _broom = 'assets/images/decor/broom.png';
const _petTimer = 'assets/images/decor/pet_timer.png';
const _house = 'assets/images/decor/house.png';

const _designSize = Size(402, 874);

class _Doodle {
  const _Doodle(this.asset, this.rect);

  final String asset;
  final Rect rect;
}

class _DoodleBackgroundState extends State<DoodleBackground>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / _designSize.width;
        final sy = constraints.maxHeight / _designSize.height;
        final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);

        return FadeTransition(
          opacity: fade,
          child: Stack(
            children: [
              for (final (i, doodle) in widget._doodles.indexed)
                Positioned(
                  left: doodle.rect.left * sx,
                  top: doodle.rect.top * sy,
                  width: doodle.rect.width * sx,
                  height: doodle.rect.height * sx,
                  child: AnimatedBuilder(
                    animation: _float,
                    // Each doodle sways gently, out of step with the others.
                    builder: (context, child) => Transform.rotate(
                      angle:
                          math.sin((_float.value + i / 3) * 2 * math.pi) *
                          0.025,
                      child: child,
                    ),
                    child: Image.asset(doodle.asset, fit: BoxFit.contain),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CirclesPainter(
                    circles: [
                      for (final c in widget._circles)
                        Offset(c.dx * sx, c.dy * sy),
                    ],
                    radius: 16 * sx,
                    time: _float,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thin outline circles that bob up and down like bubbles.
class _CirclesPainter extends CustomPainter {
  _CirclesPainter({
    required this.circles,
    required this.radius,
    required this.time,
  }) : super(repaint: time);

  final List<Offset> circles;
  final double radius;
  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.doodle;
    for (final (i, c) in circles.indexed) {
      final bob = math.sin((time.value + i * 0.27) * 2 * math.pi) * 5;
      canvas.drawCircle(c + Offset(0, bob), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CirclesPainter old) =>
      old.circles != circles || old.radius != radius;
}
