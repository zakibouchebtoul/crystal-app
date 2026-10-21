import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);

/// Shows a toast at the top of the screen, above every page, so it stays
/// put while pages change underneath.
///
/// It arrives as a small frosted capsule dropping from the top, which
/// stretches open into the card. The icon springs in inside a ring that
/// runs down the time left, the text slides in line by line, and an
/// optional [badge] (e.g. "−10%") lands on the right like a rubber stamp.
/// It leaves by folding back into the capsule and lifting away — on its
/// own, or when swiped up or tapped. Dragging down stretches it a little.
void showAppToast(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  String? badge,
  Color color = const Color(0xFF1F9E44),
  Duration duration = const Duration(milliseconds: 4000),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      icon: icon,
      title: title,
      message: message,
      badge: badge,
      color: color,
      duration: duration,
      onGone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.icon,
    required this.title,
    required this.message,
    required this.badge,
    required this.color,
    required this.duration,
    required this.onGone,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? badge;
  final Color color;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with TickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    reverseDuration: const Duration(milliseconds: 520),
  )..forward();

  /// Time left before it leaves on its own.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  double _drag = 0;
  bool _leaving = false;

  static const _capsuleWidth = 120.0;
  static const _capsuleHeight = 34.0;
  static const _height = 72.0;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _show.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_leaving) {
        _life.forward().whenComplete(_dismiss);
      }
    });
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _life.stop();
    await _show.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _show.dispose();
    _life.dispose();
    super.dispose();
  }

  double _phase(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_show.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 16,
      right: 16,
      top: top + 8,
      child: GestureDetector(
        onTap: _dismiss,
        onVerticalDragUpdate: (d) => setState(() {
          // Free upwards, stiff downwards (rubber band).
          final next = _drag + d.delta.dy;
          _drag = next > 0 ? next * 0.35 + _drag * 0.65 : next;
          _drag = math.min(_drag, 18);
        }),
        onVerticalDragEnd: (d) {
          if (_drag < -24 || d.velocity.pixelsPerSecond.dy < -300) {
            _dismiss();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: Listenable.merge([_show, _life]),
            // Gives the text the app's style (an overlay has none).
            builder: (context, _) => Material(
              type: MaterialType.transparency,
              child: _frame(constraints.maxWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame(double fullWidth) {
    final leaving = _show.status == AnimationStatus.reverse;
    // Capsule drops in, then stretches into the card.
    final drop = _phase(0, 0.32, leaving ? Curves.easeIn : Curves.easeOutBack);
    final stretch = _phase(
      0.22,
      0.62,
      leaving ? Curves.easeInCubic : Curves.easeOutBack,
    );
    final content = _phase(0.5, 0.8, Curves.easeOut);
    final iconPop = _phase(0.52, 0.85, Curves.elasticOut);
    final line1 = _phase(0.56, 0.82, Curves.easeOutCubic);
    final line2 = _phase(0.64, 0.9, Curves.easeOutCubic);
    final stamp = _phase(0.72, 0.96);

    final width = _capsuleWidth + (fullWidth - _capsuleWidth) * stretch;
    final height = _capsuleHeight + (_height - _capsuleHeight) * stretch;
    final pull = _drag > 0 ? _drag : 0.0;

    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(0, -70 * (1 - drop) + math.min(_drag, 0)),
        child: Opacity(
          opacity: drop.clamp(0.0, 1.0),
          child: SizedBox(
            width: width.clamp(0, fullWidth),
            // Pulled down, it stretches a little.
            height: math.max(height, 0) + pull,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                _capsuleHeight / 2 + (22 - _capsuleHeight / 2) * stretch,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: content,
                    child: OverflowBox(
                      // Lays out at full size while the shape grows, so
                      // nothing reflows mid-morph.
                      minWidth: fullWidth,
                      maxWidth: fullWidth,
                      minHeight: _height,
                      maxHeight: _height,
                      child: _content(iconPop, line1, line2, stamp),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(double iconPop, double line1, double line2, double stamp) {
    Widget slide(double t, Widget child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(14 * (1 - t), 0), child: child),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Transform.scale(
            scale: iconPop,
            child: SizedBox.square(
              dimension: 44,
              child: CustomPaint(
                painter: _CountdownRing(
                  left: 1 - _life.value,
                  color: widget.color,
                ),
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                slide(
                  line1,
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: 2),
                  slide(
                    line2,
                    Text(
                      widget.message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.badge != null) ...[
            const SizedBox(width: 8),
            _Stamp(text: widget.badge!, color: widget.color, t: stamp),
          ],
        ],
      ),
    );
  }
}

/// Thin ring around the icon that runs down the time left.
class _CountdownRing extends CustomPainter {
  const _CountdownRing({required this.left, required this.color});

  final double left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.12),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * left,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_CountdownRing old) =>
      old.left != left || old.color != color;
}

/// A badge that lands like a rubber stamp: comes down large and tilted,
/// hits with a small squash, and leaves a faint ring of ink.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color, required this.t});

  final String text;
  final Color color;
  final double t;

  @override
  Widget build(BuildContext context) {
    // 0 → 0.6: falls in; 0.6 → 1: settles after the hit.
    final fall = Curves.easeIn.transform((t / 0.6).clamp(0.0, 1.0));
    final settle = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    final squash = settle > 0 ? math.sin(settle * math.pi) * 0.12 : 0.0;
    final scale = 1.8 - 0.8 * fall;
    final ink = settle > 0 && settle < 1 ? settle : 0.0;
    return Opacity(
      opacity: fall,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (ink > 0)
            Transform.scale(
              scale: 1 + 0.5 * ink,
              child: Container(
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35 * (1 - ink)),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(scale + squash, scale - squash, 1, 1)
              ..rotateZ(-0.35 * (1 - fall) - 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
