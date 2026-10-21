import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/doodle_background.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

/// Shown to new users after sign-in: pick a family or personal account,
/// then the account is created and they land on the home screen.
class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountType _type = AccountType.family;
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      await authService.createAccount(
        phoneNumber: widget.phoneNumber,
        type: _type,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: DoodleBackground.accountType()),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Choose your account type',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.6,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tell us how you’ll use the app',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _AccountCard(
                            label: 'Family account',
                            icon: _AccountIcon.family,
                            entranceDelay: const Duration(milliseconds: 120),
                            selected: _type == AccountType.family,
                            onTap: () =>
                                setState(() => _type = AccountType.family),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AccountCard(
                            label: 'Personal account',
                            icon: _AccountIcon.personal,
                            entranceDelay: const Duration(milliseconds: 240),
                            selected: _type == AccountType.personal,
                            onTap: () =>
                                setState(() => _type = AccountType.personal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 23),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 420),
                        child: PrimaryButton(
                          label: 'Continue',
                          loading: _loading,
                          onPressed: _continue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountIcon { family, personal }

/// Big rounded account card.
///
/// - Entrance: flips up into place, then its line icon draws itself.
/// - Press: tilts in 3D towards the finger.
/// - Select: blue floods out from the tap point like liquid (and drains
///   away when deselected), the icon redraws in white, bubbles rise inside.
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.label,
    required this.icon,
    required this.entranceDelay,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _AccountIcon icon;
  final Duration entranceDelay;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard>
    with TickerProviderStateMixin {
  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(110)),
  );

  // Entrance flip; the delay is an idle lead-in (no timers).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: widget.entranceDelay + const Duration(milliseconds: 700),
  )..forward();

  // Icon stroke drawing; replays every time the card gets selected.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Liquid fill: 0 = gray, 1 = fully blue.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.selected ? 1 : 0,
  );

  // Rising bubbles inside the selected card.
  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  /// Where the fill starts, as a fraction of the card (center by default).
  Offset _fillOrigin = const Offset(0.5, 0.5);

  /// Current 3D tilt while pressed (-1…1 on each axis).
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Draw the icon once the card has flipped in.
    _enter.addStatusListener((status) {
      if (status == AnimationStatus.completed) _draw.forward();
    });
  }

  @override
  void didUpdateWidget(_AccountCard old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    if (widget.selected) {
      _fill.forward();
      _draw.forward(from: 0);
    } else {
      _fill.reverse();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _draw.dispose();
    _fill.dispose();
    _bubbles.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details, Size size) {
    final fraction = Offset(
      details.localPosition.dx / size.width,
      details.localPosition.dy / size.height,
    );
    setState(() {
      _tilt = Offset(fraction.dx * 2 - 1, fraction.dy * 2 - 1);
      if (!widget.selected) _fillOrigin = fraction;
    });
  }

  void _release() => setState(() => _tilt = Offset.zero);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 185 / 203,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            onTapDown: (d) => _onTapDown(d, size),
            onTapUp: (_) {
              _release();
              if (!widget.selected) HapticFeedback.selectionClick();
              widget.onTap();
            },
            onTapCancel: _release,
            child: AnimatedBuilder(
              animation: Listenable.merge([_enter, _draw, _fill, _bubbles]),
              builder: (context, _) => _buildCard(size),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(Size size) {
    final delay =
        widget.entranceDelay.inMicroseconds / _enter.duration!.inMicroseconds;
    final enter = Curves.easeOutBack.transform(
      ((_enter.value - delay) / (1 - delay)).clamp(0.0, 1.0),
    );
    final fill = Curves.easeInOutCubic.transform(_fill.value);
    final foreground = Color.lerp(AppColors.iconMuted, Colors.white, fill)!;

    // Flip up from below on entrance.
    final entrance = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(0, 60 * (1 - enter), 0, 1)
      ..rotateX(-0.9 * (1 - enter));

    // Tilt towards the finger while pressed (smoothed).
    final tilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(_tilt.dy * 0.12)
      ..rotateY(-_tilt.dx * 0.12);

    return Opacity(
      opacity: enter.clamp(0.0, 1.0),
      child: Transform(
        transform: entrance,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: tilt,
          transformAlignment: Alignment.center,
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: _shape),
            child: CustomPaint(
              painter: _LiquidFillPainter(
                progress: fill,
                origin: Offset(
                  _fillOrigin.dx * size.width,
                  _fillOrigin.dy * size.height,
                ),
                bubbleTime: _bubbles.value,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  CustomPaint(
                    size: const Size.square(90),
                    painter: _IconPainter(
                      paths: widget.icon == _AccountIcon.family
                          ? _familyIcon
                          : _personalIcon,
                      color: foreground,
                      progress: Curves.easeInOutCubic.transform(_draw.value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gray card with a blue circle flooding out from [origin]; a soft lighter
/// rim makes it read as liquid. Bubbles rise inside the blue.
class _LiquidFillPainter extends CustomPainter {
  _LiquidFillPainter({
    required this.progress,
    required this.origin,
    required this.bubbleTime,
  });

  final double progress;
  final Offset origin;
  final double bubbleTime;

  static final List<({double x, double radius, int speed, double phase})>
  _bubbles = () {
    final random = math.Random(11);
    return [
      for (var i = 0; i < 10; i++)
        (
          x: 0.12 + random.nextDouble() * 0.76,
          radius: 2 + random.nextDouble() * 4,
          speed: 1 + random.nextInt(2),
          phase: random.nextDouble(),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface.withValues(alpha: 0.3),
    );
    if (progress <= 0) return;

    // Radius that reaches the farthest corner from the origin.
    final maxRadius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);
    final radius = maxRadius * progress;

    canvas
      ..drawCircle(
        origin,
        radius + 10 * (1 - progress),
        Paint()..color = AppColors.primary.withValues(alpha: 0.35),
      )
      ..drawCircle(origin, radius, Paint()..color = AppColors.primary);

    // Bubbles, only once the card is mostly blue.
    final bubbleOpacity = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    if (bubbleOpacity == 0) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.35 * bubbleOpacity);
    for (final b in _bubbles) {
      final travel = (bubbleTime * b.speed + b.phase) % 1;
      final y = size.height + b.radius - travel * (size.height + b.radius * 2);
      final sway = math.sin((travel * 3 + b.phase) * 2 * math.pi) * 6;
      canvas.drawCircle(Offset(b.x * size.width + sway, y), b.radius, ring);
    }
  }

  @override
  bool shouldRepaint(_LiquidFillPainter old) =>
      old.progress != progress ||
      old.origin != origin ||
      old.bubbleTime != bubbleTime;
}

/// Thin-line icon drawn progressively, stroke by stroke (all strokes in
/// parallel), in a 90 × 90 box.
class _IconPainter extends CustomPainter {
  const _IconPainter({
    required this.paths,
    required this.color,
    required this.progress,
  });

  final List<Path> paths;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.scale(size.width / 90);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.progress != progress || old.paths != paths;
}

/// Two people (adult and child).
final _familyIcon = [
  Path()..addOval(Rect.fromCircle(center: const Offset(32, 20), radius: 20)),
  Path()..addOval(Rect.fromCircle(center: const Offset(70, 43), radius: 13)),
  // Child's body, tucked behind the adult.
  Path()
    ..moveTo(62, 63)
    ..cubicTo(78, 60, 92, 67, 92, 78)
    ..cubicTo(92, 87, 82, 91, 66, 92),
  // Adult's body.
  Path()
    ..moveTo(12, 92)
    ..cubicTo(0, 90, -1, 80, 2, 73)
    ..cubicTo(8, 59, 22, 52, 36, 52)
    ..cubicTo(50, 52, 62, 62, 66, 76)
    ..cubicTo(68, 83, 67, 89, 66, 92)
    ..cubicTo(48, 94, 28, 94, 12, 92)
    ..close(),
];

/// One person inside a circle.
final _personalIcon = [
  Path()..addOval(Rect.fromCircle(center: const Offset(45, 45), radius: 44)),
  Path()..addOval(Rect.fromCircle(center: const Offset(45, 30), radius: 11)),
  Path()
    ..moveTo(14, 77)
    ..cubicTo(17, 63, 27, 56, 37, 56)
    ..lineTo(53, 56)
    ..cubicTo(63, 56, 73, 63, 76, 77),
];
