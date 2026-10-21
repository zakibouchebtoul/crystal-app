import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Soft blobs of light drifting slowly behind the content.
class Aurora extends StatefulWidget {
  const Aurora({super.key});

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  static const _blobs = [
    (Color(0xFFDDEBFF), 0.0, 170.0),
    (Color(0xFFEDE5FF), 0.33, 150.0),
    (Color(0xFFDDF6FF), 0.66, 140.0),
  ];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => CustomPaint(
            painter: _AuroraPainter(_clock.value),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, phase, radius) in _AuroraState._blobs) {
      final a = (t + phase) * 2 * math.pi;
      final center = Offset(
        size.width * (0.5 + 0.32 * math.sin(a)),
        size.height * (0.38 + 0.18 * math.cos(a * 1.3 + phase)),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Little four-point sparkles orbiting (and twinkling) around a circle of
/// [radius], driven by [time] (seconds).
class OrbitSparkles extends StatelessWidget {
  const OrbitSparkles({super.key, required this.radius, required this.time});

  final double radius;
  final double time;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(radius * 2.6),
        painter: _SparklesPainter(radius: radius, time: time),
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter({required this.radius, required this.time});

  final double radius;
  final double time;

  static const _count = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < _count; i++) {
      final phase = i / _count;
      final angle = (time * 0.12 + phase) * 2 * math.pi;
      // Slightly elliptical, tilted orbit.
      final p =
          center +
          Offset(
            math.cos(angle) * radius * 1.12,
            math.sin(angle) * radius * 0.92,
          );
      final twinkle = (math.sin(time * 3 + i * 1.7) + 1) / 2;
      final r = 2.5 + 4.5 * twinkle;
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFF9CCBFF),
          Colors.white,
          twinkle,
        )!.withValues(alpha: 0.35 + 0.6 * twinkle);
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(time + i)
        ..drawPath(_star(r), paint)
        ..restore();
    }
  }

  static Path _star(double r) {
    final w = r * 0.22;
    return Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(w, -w, r, 0)
      ..quadraticBezierTo(w, w, 0, r)
      ..quadraticBezierTo(-w, w, -r, 0)
      ..quadraticBezierTo(-w, -w, 0, -r)
      ..close();
  }

  @override
  bool shouldRepaint(_SparklesPainter old) =>
      old.time != time || old.radius != radius;
}

/// A living waveform ring around a circle: a closed, wobbling line whose
/// amplitude follows [level] (0–1).
class WaveformRing extends StatelessWidget {
  const WaveformRing({
    super.key,
    required this.radius,
    required this.time,
    required this.level,
  });

  final double radius;
  final double time;
  final double level;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(radius * 2.8),
        painter: _WaveformPainter(radius: radius, time: time, level: level),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.radius,
    required this.time,
    required this.level,
  });

  final double radius;
  final double time;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final (i, color) in const [
      (0, Color(0xFF3B8CFF)),
      (1, Color(0xFF9B6BFF)),
      (2, Color(0xFF39D0FF)),
    ]) {
      final path = Path();
      const steps = 120;
      for (var s = 0; s <= steps; s++) {
        final a = s / steps * 2 * math.pi;
        final wobble =
            math.sin(a * 5 + time * (2.2 + i * 0.4) + i) * 0.55 +
            math.sin(a * 9 - time * (3.1 + i * 0.3)) * 0.3 +
            math.sin(a * 3 + time * 1.3 + i * 2) * 0.15;
        final r = radius * (1.06 + i * 0.03) + wobble * (4 + 22 * level);
        final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
        s == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.35 + 0.35 * level),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.time != time || old.level != level || old.radius != radius;
}

/// Text revealed word by word: each word rises out of a blur. Wraps like
/// normal text.
class WordReveal extends StatefulWidget {
  const WordReveal(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.delay = Duration.zero,
    this.perWord = const Duration(milliseconds: 90),
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Duration delay;
  final Duration perWord;

  @override
  State<WordReveal> createState() => _WordRevealState();
}

class _WordRevealState extends State<WordReveal>
    with SingleTickerProviderStateMixin {
  static const _wordDuration = Duration(milliseconds: 420);

  late final List<String> _words = widget.text.split(' ');
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        widget.delay + widget.perWord * (_words.length - 1) + _wordDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      MediaQuery.disableAnimationsOf(context)
          ? _controller.value = 1
          : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _controller.duration!.inMicroseconds;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final now = _controller.value * total;
        return Text.rich(
          TextSpan(
            children: [
              for (final (i, word) in _words.indexed) ...[
                if (i > 0) TextSpan(text: ' ', style: widget.style),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _word(
                    word,
                    ((now -
                                (widget.delay + widget.perWord * i)
                                    .inMicroseconds) /
                            _wordDuration.inMicroseconds)
                        .clamp(0.0, 1.0),
                  ),
                ),
              ],
            ],
          ),
          textAlign: widget.textAlign,
        );
      },
    );
  }

  Widget _word(String word, double t) {
    final eased = Curves.easeOutCubic.transform(t);
    Widget child = Text(word, style: widget.style);
    if (eased < 1) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 6 * (1 - eased),
          sigmaY: 6 * (1 - eased),
        ),
        child: child,
      );
    }
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - eased)),
        child: child,
      ),
    );
  }
}

/// Rounded-rect border with a slowly rotating iridescent gradient, faded in
/// while [active] (e.g. while the assistant is thinking).
class IridescentBorder extends StatefulWidget {
  const IridescentBorder({
    super.key,
    required this.active,
    required this.radius,
    required this.child,
  });

  final bool active;
  final double radius;
  final Widget child;

  @override
  State<IridescentBorder> createState() => _IridescentBorderState();
}

class _IridescentBorderState extends State<IridescentBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _spin.repeat();
  }

  @override
  void didUpdateWidget(IridescentBorder old) {
    super.didUpdateWidget(old);
    if (widget.active && !_spin.isAnimating) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.active ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      onEnd: () {
        if (!widget.active) _spin.stop();
      },
      builder: (context, strength, child) => AnimatedBuilder(
        animation: _spin,
        builder: (context, child) => CustomPaint(
          foregroundPainter: strength <= 0
              ? null
              : _BorderPainter(
                  rotation: _spin.value * 2 * math.pi,
                  radius: widget.radius,
                  strength: strength,
                ),
          child: child,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _BorderPainter extends CustomPainter {
  const _BorderPainter({
    required this.rotation,
    required this.radius,
    required this.strength,
  });

  final double rotation;
  final double radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final gradient = SweepGradient(
      transform: GradientRotation(rotation),
      colors: const [
        Color(0xFF3B8CFF),
        Color(0xFF9B6BFF),
        Color(0xFFFF7AC6),
        Color(0xFF39D0FF),
        Color(0xFF3B8CFF),
      ],
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);
    canvas
      ..drawRRect(
        rrect,
        paint
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = Colors.white.withValues(alpha: 0.5 * strength),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..shader = gradient.createShader(rect)
          ..color = Colors.white.withValues(alpha: strength),
      );
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.rotation != rotation || old.strength != strength;
}

/// Shrinks [child] slightly while pressed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.95});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// "Book Now" button that morphs: a short spinner, then a green
/// "Booked ✓".
class BookButton extends StatefulWidget {
  const BookButton({super.key, required this.onBooked});

  final VoidCallback onBooked;

  @override
  State<BookButton> createState() => _BookButtonState();
}

enum _BookState { idle, booking, booked }

class _BookButtonState extends State<BookButton> {
  _BookState _state = _BookState.idle;

  Future<void> _book() async {
    if (_state != _BookState.idle) return;
    setState(() => _state = _BookState.booking);
    // TODO: call the booking backend.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _state = _BookState.booked);
    widget.onBooked();
  }

  @override
  Widget build(BuildContext context) {
    final booked = _state == _BookState.booked;
    return PressScale(
      scale: 0.97,
      child: GestureDetector(
        onTap: _book,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: booked ? const Color(0xFF34C759) : AppColors.primary,
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: (booked ? const Color(0xFF34C759) : AppColors.primary)
                    .withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: switch (_state) {
              _BookState.idle => const Text(
                'Book Now',
                key: ValueKey('idle'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _BookState.booking => const SizedBox.square(
                key: ValueKey('booking'),
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              _BookState.booked => const Row(
                key: ValueKey('booked'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Booked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Assistant text that streams in word by word (newest words fading in),
/// like a live AI reply. With [animate] off it shows at once.
class StreamingText extends StatefulWidget {
  const StreamingText({
    super.key,
    required this.lead,
    required this.text,
    required this.style,
    this.animate = true,
  });

  final String? lead;
  final String text;
  final TextStyle style;
  final bool animate;

  /// Time to stream [text] (with [lead]) at the standard pace.
  static Duration durationFor(String? lead, String text) =>
      _perWord * ('${lead ?? ''} $text'.trim().split(' ').length + 2);

  static const _perWord = Duration(milliseconds: 38);

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with SingleTickerProviderStateMixin {
  late final List<(String, bool)> _words = [
    if (widget.lead case final lead?)
      for (final w in lead.split(' ')) (w, true),
    for (final w in widget.text.split(' ')) (w, false),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StreamingText.durationFor(widget.lead, widget.text),
    value: widget.animate ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      MediaQuery.disableAnimationsOf(context)
          ? _controller.value = 1
          : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Words revealed so far (fractional: the last ones fade in).
        final shown = _controller.value * (_words.length + 2);
        return AnimatedSize(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.topLeft,
          child: Text.rich(
            TextSpan(
              style: widget.style,
              children: [
                for (final (i, (word, bold)) in _words.indexed)
                  if (i < shown.ceil())
                    TextSpan(
                      text: i == 0 ? word : ' $word',
                      style: TextStyle(
                        fontWeight: bold ? FontWeight.w700 : null,
                        color: widget.style.color!.withValues(
                          alpha: ((shown - i) / 2.5).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
