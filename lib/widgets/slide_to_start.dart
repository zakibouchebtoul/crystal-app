import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import 'start_arrow_icon.dart';

/// Swipe-to-confirm button: drag the blue knob to the right (or tap it)
/// to trigger [onCompleted], which receives the button's end point in
/// global coordinates (handy for a reveal transition from there).
///
/// Idle: the label shimmers and chevrons pulse towards the arrow.
/// Dragging: the knob lifts and stretches with speed, leaves a trail of
/// bubbles, its label turns into an arrow, and the target arrow grows and
/// glows; a haptic tick marks every quarter. Completing: the knob fills
/// the bar, a check pops in and bubbles burst out.
class SlideToStart extends StatefulWidget {
  const SlideToStart({
    super.key,
    required this.label,
    required this.onCompleted,
  });

  final String label;
  final ValueChanged<Offset> onCompleted;

  @override
  State<SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<SlideToStart>
    with TickerProviderStateMixin {
  static const _height = 58.0;
  static const _padding = 8.0;
  static const _knobWidth = 137.0;
  static const _knobHeight = _height - _padding * 2;
  static const _trackColor = Color(0xFFF5F7FB);
  static const _trailColor = Color(0xFFDDEBFB);

  // Knob position, 0 = start, 1 = end of the track.
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // Looping idle hints: arrow nudge, label shimmer, chevron pulse.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  // Finish sequence: knob fills the bar and the check pops in.
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  // Drives the bubbles and the speed stretch every frame while needed.
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;

  final _bubbles = <_Bubble>[];
  final _random = math.Random();

  bool _dragging = false;
  bool _completed = false;
  double _stretch = 0; // 0–1, how much the knob is stretched by speed
  double _emitDistance = 0; // drag distance since the last bubble
  int _lastQuarter = 0; // for the haptic ticks

  @override
  void dispose() {
    _ticker.dispose();
    _position.dispose();
    _idle.dispose();
    _finish.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Interaction

  void _onDragStart(DragStartDetails _) {
    if (_completed) return;
    setState(() => _dragging = true);
    _ensureTicking();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxOffset) {
    if (_completed) return;
    _position.value += details.delta.dx / maxOffset;

    // Stretch with speed (pixels per frame), smoothed.
    final speed = (details.delta.dx.abs() / 18).clamp(0.0, 1.0);
    _stretch = math.max(_stretch, speed);

    // A haptic tick each time a new quarter of the track is reached.
    final quarter = (_position.value * 4).floor();
    if (quarter > _lastQuarter && quarter < 4) HapticFeedback.selectionClick();
    _lastQuarter = quarter;

    // Leave bubbles behind the knob as it moves forward.
    if (details.delta.dx > 0) {
      _emitDistance += details.delta.dx;
      while (_emitDistance > 7) {
        _emitDistance -= 7;
        _emitTrailBubble(_position.value * maxOffset);
      }
    }
    _ensureTicking();
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    setState(() => _dragging = false);
    if (_position.value > 0.7 || details.primaryVelocity! > 800) {
      _complete();
    } else {
      HapticFeedback.lightImpact();
      _lastQuarter = 0;
      _position.animateBack(0, curve: Curves.easeOutBack);
    }
  }

  Future<void> _complete() async {
    if (_completed) return;
    setState(() {
      _completed = true;
      _dragging = false;
    });
    await _position.animateTo(1, curve: Curves.easeOut);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _burst();
    await _finish.forward();
    if (!mounted) return;
    final box = context.findRenderObject()! as RenderBox;
    widget.onCompleted(
      box.localToGlobal(Offset(box.size.width - 30, box.size.height / 2)),
    );
  }

  // ---------------------------------------------------------------------
  // Bubbles and per-frame updates

  void _ensureTicking() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    for (final b in _bubbles) {
      b
        ..position += b.velocity * dt
        ..velocity = b.velocity * math.pow(0.08, dt).toDouble()
        ..velocity -=
            Offset(0, 30 * dt) // drift upward
        ..age += dt;
    }
    _bubbles.removeWhere((b) => b.age >= b.life);
    _stretch *= math.pow(0.002, dt).toDouble(); // ease back quickly

    setState(() {});
    if (_bubbles.isEmpty && _stretch < 0.01 && !_dragging) {
      _stretch = 0;
      _ticker.stop();
    }
  }

  /// One small bubble from the knob's back edge, drifting back and up.
  void _emitTrailBubble(double knobLeft) {
    _bubbles.add(
      _Bubble(
        position: Offset(
          _padding + knobLeft + 10 + _random.nextDouble() * 10,
          _padding + 6 + _random.nextDouble() * (_knobHeight - 12),
        ),
        velocity: Offset(
          -20 - _random.nextDouble() * 40,
          (_random.nextDouble() - 0.5) * 40,
        ),
        radius: 1.5 + _random.nextDouble() * 2.5,
        life: 0.6 + _random.nextDouble() * 0.5,
      ),
    );
  }

  /// A burst of bubbles from the end of the bar on completion.
  void _burst() {
    final box = context.findRenderObject()! as RenderBox;
    final origin = Offset(box.size.width - 30, box.size.height / 2);
    for (var i = 0; i < 28; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 80 + _random.nextDouble() * 220;
      _bubbles.add(
        _Bubble(
          position: origin,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          radius: 2 + _random.nextDouble() * 4,
          life: 0.7 + _random.nextDouble() * 0.6,
          light: true,
        ),
      );
    }
    _ensureTicking();
  }

  // ---------------------------------------------------------------------
  // Layout

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - _padding * 2;
        final maxOffset = innerWidth - _knobWidth;
        return AnimatedBuilder(
          animation: Listenable.merge([_position, _idle, _finish]),
          builder: (context, _) {
            final progress = _position.value.clamp(0.0, 1.0);
            final finish = Curves.easeInOutCubic.transform(_finish.value);
            final offset = _position.value * maxOffset;

            // Knob grows with speed (to the left, like a tail) and, at the
            // end, fills the whole bar.
            final stretchWidth = 26 * _stretch;
            final knobLeft = (offset - stretchWidth) * (1 - finish);
            final knobWidth =
                _knobWidth +
                stretchWidth +
                (innerWidth - _knobWidth - stretchWidth) * finish;

            return SizedBox(
              height: _height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildTrack(progress),
                  Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildTrail(offset, maxOffset, progress),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ChevronsPainter(
                              phase: _idle.value,
                              visibleFrom: offset + _knobWidth + 8,
                              opacity: (1 - progress * 3).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                        _buildTargetArrow(progress),
                        Positioned(
                          left: knobLeft,
                          top: 0,
                          bottom: 0,
                          width: knobWidth,
                          child: _buildKnob(progress, finish, maxOffset),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BubblesPainter(_bubbles)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The white bar; its edge glows softly blue as the knob nears the end.
  Widget _buildTrack(double progress) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _trackColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35 * progress),
              blurRadius: 18 * progress,
              spreadRadius: 2 * progress,
            ),
          ],
        ),
      ),
    );
  }

  /// Soft trail behind the knob, darkening towards its rounded end; it
  /// deepens in color while dragging.
  Widget _buildTrail(double offset, double maxOffset, double progress) {
    final color = Color.lerp(
      _trailColor,
      AppColors.primary.withValues(alpha: 0.35),
      progress,
    )!;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: (_knobWidth + offset + 110).clamp(0.0, maxOffset + _knobWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0), color],
            stops: const [0.45, 1],
          ),
        ),
      ),
    );
  }

  /// The arrow at the end: nudges when idle; grows and glows as the knob
  /// approaches.
  Widget _buildTargetArrow(double progress) {
    final nudge = _dragging || _completed
        ? 0.0
        : math.sin(_idle.value * 2 * math.pi * 2) * 3;
    final pull = Curves.easeIn.transform(progress);
    // Hide it as the knob slides over it.
    final covered = ((progress - 0.8) / 0.15).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Opacity(
          opacity: 1 - covered,
          child: Transform.translate(
            offset: Offset(nudge, 0),
            child: Transform.scale(
              scale: 1 + 0.4 * pull,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35 * pull),
                      blurRadius: 14 * pull,
                      spreadRadius: 2 * pull,
                    ),
                  ],
                ),
                child: const StartArrowIcon(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKnob(double progress, double finish, double maxOffset) {
    final lift = _dragging ? 1.0 : 0.0;
    final labelOpacity = (1 - progress * 5).clamp(0.0, 1.0) * (1 - finish);
    final arrowOpacity = ((progress - 0.12) * 4).clamp(0.0, 1.0) * (1 - finish);
    final check = Curves.elasticOut.transform(
      ((_finish.value - 0.35) / 0.65).clamp(0.0, 1.0),
    );

    return GestureDetector(
      onTap: _complete,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxOffset),
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedScale(
        scale: _dragging ? 1.04 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 + 0.2 * lift),
                blurRadius: 6 + 10 * lift,
                offset: Offset(0, 2 + 4 * lift),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: labelOpacity,
                child: _Shimmer(
                  phase: _idle.value,
                  enabled: !_dragging && !_completed,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: arrowOpacity,
                child: const StartArrowIcon(color: Colors.white),
              ),
              if (check > 0)
                Transform.scale(
                  scale: check,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light band sweeping across the label while idle.
class _Shimmer extends StatelessWidget {
  const _Shimmer({
    required this.phase,
    required this.enabled,
    required this.child,
  });

  final double phase;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    // Sweep during the first 60% of each loop, then rest.
    final t = (phase / 0.6).clamp(0.0, 1.0);
    final pos = -0.3 + 1.6 * t;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Color(0xB3FFFFFF), Colors.white, Color(0xB3FFFFFF)],
        stops: [
          (pos - 0.2).clamp(0.0, 1.0),
          pos.clamp(0.0, 1.0),
          (pos + 0.2).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Three chevrons in the free part of the track, pulsing one after another
/// towards the arrow.
class _ChevronsPainter extends CustomPainter {
  _ChevronsPainter({
    required this.phase,
    required this.visibleFrom,
    required this.opacity,
  });

  final double phase;
  final double visibleFrom;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final cy = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.56 + i * 0.07);
      if (x < visibleFrom) continue;
      // A wave of brightness travelling left to right.
      final wave = (math.sin((phase - i * 0.12) * 2 * math.pi * 2) + 1) / 2;
      paint.color = AppColors.primary.withValues(
        alpha: (0.15 + 0.55 * wave) * opacity,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - 3, cy - 6)
          ..lineTo(x + 3, cy)
          ..lineTo(x - 3, cy + 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChevronsPainter old) =>
      old.phase != phase ||
      old.visibleFrom != visibleFrom ||
      old.opacity != opacity;
}

class _Bubble {
  _Bubble({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.life,
    this.light = false,
  });

  Offset position;
  Offset velocity;
  final double radius;
  final double life;
  double age = 0;

  /// Burst bubbles are white-filled so they show on blue and on white.
  final bool light;
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.bubbles);

  final List<_Bubble> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final t = b.age / b.life;
      final fade = 1 - t * t;
      final radius = b.radius * (0.6 + 0.6 * t);
      canvas.drawCircle(
        b.position,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.primary.withValues(alpha: 0.6 * fade),
      );
      if (b.light) {
        canvas.drawCircle(
          b.position,
          radius - 0.6,
          Paint()..color = Colors.white.withValues(alpha: 0.55 * fade),
        );
      }
      canvas.drawCircle(
        b.position - Offset(radius * 0.35, radius * 0.35),
        radius * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => true;
}
