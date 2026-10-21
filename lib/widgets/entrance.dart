import 'package:flutter/widgets.dart';

/// Shares a screen's entrance timeline (0–1) and scroll position with the
/// widgets inside it, so each section can run its own part of the
/// choreography.
class EntranceScope extends InheritedWidget {
  const EntranceScope({
    super.key,
    required this.animation,
    required this.scroll,
    required super.child,
  });

  final Animation<double> animation;
  final ScrollController scroll;

  static EntranceScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EntranceScope>()!;

  @override
  bool updateShouldNotify(EntranceScope old) =>
      animation != old.animation || scroll != old.scroll;
}

/// Runs [builder] with this stage's progress: 0 before [from], 1 after
/// [to] (fractions of the entrance timeline), shaped by [curve]. Curves
/// such as [Curves.easeOutBack] may overshoot past 1.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.from,
    required this.to,
    this.curve = Curves.easeOutCubic,
    required this.builder,
    this.child,
  });

  final double from;
  final double to;
  final Curve curve;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final animation = EntranceScope.of(context).animation;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final linear = ((animation.value - from) / (to - from)).clamp(0.0, 1.0);
        return builder(context, curve.transform(linear), child);
      },
    );
  }
}

/// Fades and slides [child] in from [offset] as [t] goes 0 → 1.
Widget fadeSlide(
  double t,
  Widget? child, {
  Offset offset = const Offset(0, 16),
}) {
  return Opacity(
    opacity: t.clamp(0.0, 1.0),
    child: Transform.translate(offset: offset * (1 - t), child: child),
  );
}
