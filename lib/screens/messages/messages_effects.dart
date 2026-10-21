import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Plays a one-shot entrance after [delay]: [builder] gets progress 0 → 1
/// (shaped by [curve], may overshoot). With [enabled] off it shows the end
/// state at once.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.builder,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
  });

  final Widget Function(double t, Widget child) builder;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + duration;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: curve),
      builder: (context, t, child) => builder(t, child!),
      child: child,
    );
  }
}

/// Glides in from the right with a slight 3D tilt.
Widget tiltIn(double t, Widget child) {
  return Opacity(
    opacity: t.clamp(0.0, 1.0),
    child: Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..translateByDouble(60 * (1 - t), 0, 0, 1)
        ..rotateY(-0.5 * (1 - t)),
      child: child,
    ),
  );
}

/// Pops in from nothing.
Widget popIn(double t, Widget child) =>
    Transform.scale(scale: math.max(t, 0), child: child);

/// Slides in from the left or right side, rising a little.
Widget sideIn(double t, Widget child, {required bool fromRight}) {
  return Opacity(
    opacity: t.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset((fromRight ? 40 : -40) * (1 - t), 12 * (1 - t)),
      child: child,
    ),
  );
}

/// Online dot with a soft ring breathing out of it.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: size * (1 + 1.2 * t),
                height: size * (1 + 1.2 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folds [child] away (width or height) and fades it when [visible] turns
/// off; unfolds it again when it turns back on.
class Collapse extends StatelessWidget {
  const Collapse({
    super.key,
    required this.visible,
    required this.child,
    this.axis = Axis.vertical,
  });

  final bool visible;
  final Widget child;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: axis == Axis.vertical
              ? Alignment.topCenter
              : Alignment.centerLeft,
          heightFactor: axis == Axis.vertical ? t : null,
          widthFactor: axis == Axis.horizontal ? t : null,
          child: Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        ),
      ),
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}

/// A diagonal light sweep across [child], once, after [delay].
class ShineOnce extends StatelessWidget {
  const ShineOnce({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 500),
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const sweep = Duration(milliseconds: 900);
    final total = delay + sweep;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeInOut,
      ),
      builder: (context, t, child) {
        if (t <= 0 || t >= 1) return child!;
        final center = -0.3 + 1.6 * t;
        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: [
                        (center - 0.15).clamp(0.0, 1.0),
                        center.clamp(0.0, 1.0),
                        (center + 0.15).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
