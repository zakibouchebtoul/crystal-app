import 'package:flutter/material.dart';

/// Fades [child] in while sliding it up a little, after [delay]. Used to
/// stagger the entrance of a screen's sections.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    this.delay = Duration.zero,
    required this.child,
  });

  final Duration delay;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 500);

  // The delay is part of the animation (an idle lead-in) rather than a
  // timer, so nothing is left pending if the screen closes early.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + _duration,
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / (widget.delay + _duration).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
