import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import 'onboarding_screen.dart';

/// Animated splash: glowing pens draw the diamond, it "crystallizes" into
/// the solid logo with a burst of light, a pen draws the wave, "Crystal" is
/// revealed, and a shine sweeps across — over rising bubbles and soft rays.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Whole intro timeline, including the time the finished logo stays on
  // screen. Every step below is a fraction (0–1) of this duration.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..addStatusListener(_onIntroStatus);

  // Endless background motion: rising bubbles and slowly turning rays.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  // Slow "breathing" of the glow behind the logo.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _intro.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in [_diamondAsset, _waveAsset, _textAsset]) {
      precacheImage(AssetImage(asset), context);
    }
    OnboardingScreen.precache(context);
  }

  void _onIntroStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const OnboardingScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// Progress (0–1) of a step that runs from [begin] to [end] of the intro.
  double _step(double begin, double end, [Curve curve = Curves.linear]) {
    final t = ((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final logoWidth = (screen.width * 0.45).clamp(150.0, 240.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnimatedBuilder(
          animation: Listenable.merge([_intro, _ambient, _glow]),
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BubblesPainter(
                    time: _ambient.value,
                    opacity: _step(0, 0.12, Curves.easeOut),
                  ),
                ),
              ),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size.square(logoWidth * 2.2),
                      painter: _RaysPainter(
                        rotation: _ambient.value * 2 * math.pi / 3,
                        opacity: _step(_crystallize, 0.55, Curves.easeOut),
                      ),
                    ),
                    _buildGlow(logoWidth * 1.5),
                    _buildLogo(logoWidth),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlow(double size) {
    final strength =
        _step(_crystallize, 0.45, Curves.easeOut) * (0.22 + 0.08 * _glow.value);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: strength),
            Colors.white.withValues(alpha: strength * 0.35),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }

  /// All positions are in "logo units": the logo is a 234 × 161 box, and
  /// [k] converts those units to logical pixels.
  Widget _buildLogo(double width) {
    final k = width / 234;

    // Diamond: drawn as lines, then filled in with a small "pop".
    final fill = _step(_crystallize, _crystallize + 0.06, Curves.easeOut);
    final pop =
        math.sin(math.pi * _step(_crystallize, _crystallize + 0.1)) * 0.07;
    final diamondCenter = Alignment(124 / 234 * 2 - 1, 43 / 161 * 2 - 1);

    // Wave: how far the pen has travelled along it.
    final wave = _step(0.4, 0.56, Curves.easeInOut);
    final waveMetric = _wavePath.computeMetrics().first;
    final pen = waveMetric
        .getTangentForOffset(waveMetric.length * wave)!
        .position;

    final shine = _step(0.68, 0.82, Curves.easeInOut);

    return SizedBox(
      width: width,
      height: 161 * k,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BurstPainter(
                progress: _step(_crystallize, _crystallize + 0.16),
                center: Offset(124 * k, 40 * k),
                maxRadius: 120 * k,
              ),
            ),
          ),
          // Wave image revealed up to the pen, plus the glowing pen head.
          Positioned(
            left: 57.7 * k,
            top: 74.1 * k,
            width: 148.4 * k,
            child: ClipRect(
              clipper: _RevealClipper(wave >= 1 ? 1 : (pen.dx - 57.7) / 148.4),
              child: Image.asset(_waveAsset),
            ),
          ),
          if (wave > 0 && wave < 1)
            Positioned.fill(
              child: CustomPaint(
                painter: _PenHeadPainter(position: pen * k, radius: 2.2 * k),
              ),
            ),
          Positioned(
            left: 0,
            top: 110.7 * k,
            width: width,
            child: _buildText(k, shine),
          ),
          Positioned(
            left: 70.5 * k,
            top: 0,
            width: 107 * k,
            child: Transform.scale(
              scale: 1 + pop,
              child: Opacity(
                opacity: fill,
                child: _Shine(
                  progress: shine,
                  child: Image.asset(_diamondAsset),
                ),
              ),
            ),
          ),
          // Pen strokes drawing the diamond; they dissolve as it fills in.
          Positioned.fill(
            child: Transform.scale(
              scale: 1 + pop,
              alignment: diamondCenter,
              child: CustomPaint(
                painter: _DiamondLinesPainter(
                  k: k,
                  outline: _step(0.03, 0.25, Curves.easeInOut),
                  facets: _step(0.14, _crystallize, Curves.easeInOut),
                  opacity: 1 - _step(_crystallize + 0.03, _crystallize + 0.12),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _SparklePainter(
                k: k,
                sparkles: [
                  for (final s in _sparkles)
                    (s, _step(s.start, s.start + 0.14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Crystal" wiped in from left to right with a soft edge.
  Widget _buildText(double k, double shine) {
    final reveal = _step(0.5, 0.66, Curves.easeOutCubic);
    final edge = -0.15 + 1.3 * reveal;
    return Transform.translate(
      offset: Offset(-12 * k * (1 - reveal), 0),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: const [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [0, edge.clamp(0.0, 1.0), (edge + 0.15).clamp(0.0, 1.0), 1],
        ).createShader(rect),
        child: _Shine(progress: shine, child: Image.asset(_textAsset)),
      ),
    );
  }
}

/// Moment (fraction of the intro) the drawn diamond turns solid.
const _crystallize = 0.3;

const _diamondAsset = 'assets/images/crystal_diamond.png';
const _waveAsset = 'assets/images/crystal_wave.png';
const _textAsset = 'assets/images/crystal_text.png';

// Diamond corners in logo units, measured from the logo artwork.
const _top = Offset(124, 0);
const _topLeft = Offset(90.9, 0);
const _topRight = Offset(156.7, 0);
const _left = Offset(70.8, 25.4);
const _right = Offset(177, 25.4);
const _girdleLeft = Offset(100.2, 24.9);
const _girdleRight = Offset(147.2, 24.9);
const _bottom = Offset(124, 85.9);

Path _polyline(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

// Two pens start at the top and meet at the bottom tip.
final _outlinePaths = [
  _polyline([_top, _topRight, _right, _bottom]),
  _polyline([_top, _topLeft, _left, _bottom]),
];

final _facetPaths = [
  _polyline([_topLeft, _girdleLeft, _top, _girdleRight, _topRight]),
  _polyline([_left, _girdleLeft, _girdleRight, _right]),
  _polyline([_girdleLeft, _bottom]),
  _polyline([_girdleRight, _bottom]),
];

// Center line of the wave in logo units, measured from the logo artwork.
final _wavePath = _polyline(const [
  Offset(58.5, 96.5),
  Offset(63.8, 99.4),
  Offset(69.8, 101.2),
  Offset(75.8, 101.6),
  Offset(81.8, 100.9),
  Offset(87.9, 99.5),
  Offset(93.9, 97.8),
  Offset(99.9, 95.8),
  Offset(106, 94.2),
  Offset(112, 93.3),
  Offset(118, 93.1),
  Offset(124, 94.2),
  Offset(130.1, 95.9),
  Offset(136.1, 97.3),
  Offset(142.1, 97.5),
  Offset(148.1, 97),
  Offset(154.2, 95.5),
  Offset(160.2, 93.3),
  Offset(166.2, 90.5),
  Offset(172.2, 87.1),
  Offset(178.3, 83.6),
  Offset(184.3, 80.2),
  Offset(190.3, 77.6),
  Offset(196.3, 75.6),
  Offset(202.4, 74.3),
  Offset(206, 73.6),
]);

typedef _Sparkle = ({Offset position, double size, double start});

const List<_Sparkle> _sparkles = [
  (position: Offset(66, 6), size: 9, start: 0.72),
  (position: Offset(186, 28), size: 7, start: 0.77),
  (position: Offset(168, 68), size: 5, start: 0.82),
  (position: Offset(88, 52), size: 6, start: 0.86),
];

/// Sweeps a pale-blue glint across [child] while [progress] goes 0 → 1.
class _Shine extends StatelessWidget {
  const _Shine({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    final pos = -0.3 + 1.6 * progress;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Colors.white, Color(0xFF9CCBFF), Colors.white],
        stops: [
          (pos - 0.15).clamp(0.0, 1.0),
          pos.clamp(0.0, 1.0),
          (pos + 0.15).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Clips the child to its left [progress] fraction, so it draws itself in.
class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}

/// Glowing pen lines tracing the diamond: first the outline (two pens
/// meeting at the tip), then the inner facets.
class _DiamondLinesPainter extends CustomPainter {
  _DiamondLinesPainter({
    required this.k,
    required this.outline,
    required this.facets,
    required this.opacity,
  });

  final double k;
  final double outline;
  final double facets;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || outline <= 0) return;
    canvas.scale(k);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: opacity);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    void draw(Path path, double t, {bool penHead = false}) {
      if (t <= 0) return;
      for (final metric in path.computeMetrics()) {
        final partial = metric.extractPath(0, metric.length * t);
        canvas
          ..drawPath(partial, glow)
          ..drawPath(partial, line);
        if (penHead && t < 1) _drawPenHead(canvas, metric, t);
      }
    }

    for (final path in _outlinePaths) {
      draw(path, outline, penHead: true);
    }
    for (final path in _facetPaths) {
      draw(path, facets);
    }
  }

  void _drawPenHead(Canvas canvas, PathMetric metric, double t) {
    final p = metric.getTangentForOffset(metric.length * t)!.position;
    canvas
      ..drawCircle(
        p,
        5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(p, 1.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DiamondLinesPainter old) =>
      old.outline != outline ||
      old.facets != facets ||
      old.opacity != opacity ||
      old.k != k;
}

/// Bright glowing dot that leads the wave as it's drawn.
class _PenHeadPainter extends CustomPainter {
  _PenHeadPainter({required this.position, required this.radius});

  final Offset position;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(
        position,
        radius * 3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2),
      )
      ..drawCircle(position, radius, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PenHeadPainter old) => old.position != position;
}

/// Flash of light and an expanding ring when the diamond turns solid.
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.center,
    required this.maxRadius,
  });

  final double progress;
  final Offset center;
  final double maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = 1 - progress;

    final flashRadius = maxRadius * (0.4 + 0.6 * eased);
    canvas
      ..drawCircle(
        center,
        flashRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.55 * fade),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: flashRadius)),
      )
      ..drawCircle(
        center,
        maxRadius * (0.35 + 0.65 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fade + 0.5
          ..color = Colors.white.withValues(alpha: 0.7 * fade),
      );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

/// Soft light rays turning slowly behind the logo.
class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.rotation, required this.opacity});

  final double rotation;
  final double opacity;

  static const _count = 12;
  static const _halfWidth = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.08 * opacity),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final rays = Path();
    for (var i = 0; i < _count; i++) {
      final angle = rotation + i * 2 * math.pi / _count;
      rays
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(angle - _halfWidth),
          center.dy + radius * math.sin(angle - _halfWidth),
        )
        ..lineTo(
          center.dx + radius * math.cos(angle + _halfWidth),
          center.dy + radius * math.sin(angle + _halfWidth),
        )
        ..close();
    }
    canvas.drawPath(rays, paint);
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.rotation != rotation || old.opacity != opacity;
}

typedef _Bubble = ({double x, double radius, int speed, double phase});

/// Soap bubbles drifting up the screen.
class _BubblesPainter extends CustomPainter {
  _BubblesPainter({required this.time, required this.opacity});

  /// 0–1, looping.
  final double time;
  final double opacity;

  static final List<_Bubble> _bubbles = () {
    final random = math.Random(7);
    return [
      for (var i = 0; i < 22; i++)
        (
          x: random.nextDouble(),
          radius: 2 + random.nextDouble() * 6,
          // Whole numbers so the loop is seamless.
          speed: 1 + random.nextInt(3),
          phase: random.nextDouble(),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.28 * opacity);
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.45 * opacity);

    for (final b in _bubbles) {
      final travel = (time * b.speed + b.phase) % 1;
      final y = size.height + b.radius - travel * (size.height + b.radius * 2);
      final sway = math.sin((travel * 4 + b.phase) * 2 * math.pi) * 8;
      final center = Offset(b.x * size.width + sway, y);
      canvas
        ..drawCircle(center, b.radius, ring)
        ..drawCircle(
          center - Offset(b.radius * 0.35, b.radius * 0.35),
          b.radius * 0.22,
          highlight,
        );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) =>
      old.time != time || old.opacity != opacity;
}

/// Four-point twinkling stars; each grows, turns, and shrinks away.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.k, required this.sparkles});

  final double k;
  final List<(_Sparkle, double)> sparkles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final (sparkle, t) in sparkles) {
      if (t == 0 || t == 1) continue;
      final r = sparkle.size * k * math.sin(math.pi * t);
      canvas
        ..save()
        ..translate(sparkle.position.dx * k, sparkle.position.dy * k)
        ..rotate(t * math.pi / 2)
        ..drawPath(_star(r), paint)
        ..restore();
    }
  }

  Path _star(double r) {
    final w = r * 0.18;
    return Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(w, -w, r, 0)
      ..quadraticBezierTo(w, w, 0, r)
      ..quadraticBezierTo(-w, w, -r, 0)
      ..quadraticBezierTo(-w, -w, 0, -r)
      ..close();
  }

  @override
  bool shouldRepaint(_SparklePainter old) => true;
}
