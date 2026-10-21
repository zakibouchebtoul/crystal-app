import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/offers.dart';
import '../../data/service_catalog.dart';
import '../../widgets/app_toast.dart';
import '../service/companies_screen.dart';

const _muted = Color(0xFF6A7B89);
const _green = Color(0xFF1F9E44);

/// Hero tag shared by a banner in the home carousel and its offer card.
String offerHeroTag(String id) => 'offer-banner-$id';

/// Each offer's own colour, used for the glow behind the deck.
Color _tone(Offer o) => switch (o.serviceId) {
  'pet_grooming' => const Color(0xFFFF9A62),
  'laundry' => const Color(0xFFB57BFF),
  'car_wash' => const Color(0xFF2FD6A8),
  'glass_cleaning' => const Color(0xFF3FA9F5),
  _ => AppColors.primary,
};

/// Offers as a deck. The banners sit on a 3D carousel: the one in focus
/// stands forward while its neighbours turn away and sink back. A soft
/// glow behind the deck takes each offer's colour, blending as you swipe.
/// Under it, the focused offer's details: a coupon with notched sides and
/// a perforated stub, a ring counting down the days left, the terms, and
/// the button to use it — which stamps the coupon "ACTIVE".
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, this.focusId});

  /// Offer to open on.
  final String? focusId;

  static Route<void> route({String? focusId}) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => OffersScreen(focusId: focusId),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with TickerProviderStateMixin {
  late final int _start = math.max(
    0,
    offers.indexWhere((o) => o.id == widget.focusId),
  );
  late final PageController _pages = PageController(
    viewportFraction: 0.82,
    initialPage: _start,
  );
  late int _index = _start;

  /// Entrance: glow fades up, cards swing in, details rise.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  /// Slow breathing of the glow.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pages.dispose();
    _intro.dispose();
    _breathe.dispose();
    super.dispose();
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? _pages.page!
      : _start.toDouble();

  double _phase(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));

  void _use(Offer offer) {
    HapticFeedback.mediumImpact();
    appliedOffer.value = offer;
    final service = serviceById(offer.serviceId);
    if (service == null) return;
    // Let the stamp land, go to the service, then confirm the offer is on
    // once the new page has slid in.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.of(context).push(CompaniesScreen.route(service));
      // This page stays underneath, so its context still reaches the
      // app's overlay.
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        showAppToast(
          context,
          icon: Icons.local_offer_rounded,
          title: '${offer.code} is active',
          badge: '−${offer.percent}%',
          message:
              '${offer.percent}% off applies when you book '
              '${service.title.toLowerCase()}',
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_pages, _intro, _breathe]),
        builder: (context, _) {
          final page = _page;
          final i = page.floor().clamp(0, offers.length - 1);
          final j = (i + 1).clamp(0, offers.length - 1);
          final tone = Color.lerp(
            _tone(offers[i]),
            _tone(offers[j]),
            page - page.floor(),
          )!;
          return Stack(
            children: [
              // Glow behind the deck in the focused offer's colour.
              Positioned(
                left: -80,
                right: -80,
                top: -120,
                height: 520,
                child: Opacity(
                  opacity: _phase(0, 0.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.3 + 0.6 * _breathe.value, 0.1),
                        radius: 0.75,
                        colors: [
                          tone.withValues(alpha: 0.28),
                          tone.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context),
                    const SizedBox(height: 8),
                    SizedBox(height: 230, child: _deck(page)),
                    const SizedBox(height: 4),
                    _progress(page),
                    Expanded(
                      child: ValueListenableBuilder<Offer?>(
                        valueListenable: appliedOffer,
                        builder: (context, applied, _) {
                          final o = offers[_index];
                          final t = _phase(0.45, 1, Curves.easeOutCubic);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - t)),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  18,
                                  24,
                                  24 + bottom,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeOutCubic,
                                  transitionBuilder: (child, a) =>
                                      FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(
                                            begin: const Offset(0.06, 0),
                                            end: Offset.zero,
                                          ).animate(a),
                                          child: child,
                                        ),
                                      ),
                                  child: _Details(
                                    key: ValueKey(o.id),
                                    offer: o,
                                    tone: _tone(o),
                                    applied: applied?.id == o.id,
                                    onUse: () => _use(o),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = _phase(0, 0.4, Curves.easeOutCubic);
    return Opacity(
      opacity: t,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 24, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Offers',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              '${_index + 1} / ${offers.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The 3D carousel of banners.
  Widget _deck(double page) {
    return PageView.builder(
      controller: _pages,
      itemCount: offers.length,
      clipBehavior: Clip.none,
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() => _index = i);
      },
      itemBuilder: (context, i) {
        final o = offers[i];
        final d = (i - page).clamp(-1.5, 1.5);
        final a = d.abs();
        // Cards swing in one after another on arrival.
        final enter = _phase(
          0.1 + 0.08 * (i - _start).abs().clamp(0, 3),
          0.6 + 0.08 * (i - _start).abs().clamp(0, 3),
          Curves.easeOutCubic,
        );
        return Transform(
          alignment: d < 0 ? Alignment.centerRight : Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..translateByDouble(60 * (1 - enter), 24 * a, 0, 1)
            ..rotateY(-0.55 * d)
            ..scaleByDouble(1 - 0.12 * a, 1 - 0.12 * a, 1, 1),
          child: Opacity(
            opacity: (enter * (1 - 0.35 * a)).clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () => _pages.animateToPage(
                i,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Banner(offer: o, focus: 1 - a.clamp(0.0, 1.0)),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Thin bars, one per offer; the current one fills.
  Widget _progress(double page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          for (var i = 0; i < offers.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFE3E8EF),
                    AppColors.ink,
                    (1 - (page - i).abs()).clamp(0.0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A banner card: the offer's image with a "−20%" sticker in the corner.
class _Banner extends StatelessWidget {
  const _Banner({required this.offer, required this.focus});

  final Offer offer;

  /// 1 when centred, 0 when off to the side.
  final double focus;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Hero(
            tag: offerHeroTag(offer.id),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _tone(offer).withValues(alpha: 0.35 * focus),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Image.asset(offer.image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          // Sticker, slapped on slightly crooked.
          Positioned(
            right: -6,
            top: -10,
            child: Transform.rotate(
              angle: 0.18,
              child: Transform.scale(
                scale: 0.7 + 0.3 * focus,
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFA52E), AppColors.accentDeep],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '−${offer.percent}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The focused offer: title, coupon, days-left ring, terms, button.
class _Details extends StatelessWidget {
  const _Details({
    super.key,
    required this.offer,
    required this.tone,
    required this.applied,
    required this.onUse,
  });

  final Offer offer;
  final Color tone;
  final bool applied;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    o.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _DaysRing(days: o.validDays, tone: tone),
          ],
        ),
        const SizedBox(height: 18),
        _Coupon(offer: o, applied: applied),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in o.terms)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 13, color: _muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: applied ? null : onUse,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              disabledBackgroundColor: const Color(0xFFE8F8EC),
              disabledForegroundColor: _green,
              shape: const StadiumBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: applied
                  ? const Row(
                      key: ValueKey('on'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Active on your next booking',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('use'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Use offer'),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A ring of the days left out of a month, with the number inside.
class _DaysRing extends StatelessWidget {
  const _DaysRing({required this.days, required this.tone});

  final int days;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 5;
    final color = urgent ? const Color(0xFFE5484D) : tone;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (days / 30).clamp(0.05, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox.square(
        dimension: 62,
        child: CustomPaint(
          painter: _RingPainter(value: v, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$days',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: urgent ? color : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'days left',
                  style: TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color.withValues(alpha: 0.14),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// A coupon: notched on both sides, the code on the left, a perforated
/// line, the discount on the stub. Tap the code to copy it. Once used it
/// gets an "ACTIVE" stamp.
class _Coupon extends StatefulWidget {
  const _Coupon({required this.offer, required this.applied});

  final Offer offer;
  final bool applied;

  @override
  State<_Coupon> createState() => _CouponState();
}

class _CouponState extends State<_Coupon> {
  bool _copied = false;

  Future<void> _copy() async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: widget.offer.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(
            clipper: const _CouponShape(stub: 0.3),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF5F9FF), Color(0xFFEAF3FF)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _copy,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROMO CODE',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA9B6C6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      o.code,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: _copied
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          key: ValueKey('ok'),
                                          size: 18,
                                          color: _green,
                                        )
                                      : const Icon(
                                          Icons.copy_rounded,
                                          key: ValueKey('copy'),
                                          size: 17,
                                          color: _muted,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _copied ? 'Copied' : 'Tap to copy',
                              style: TextStyle(
                                fontSize: 11,
                                color: _copied ? _green : _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Perforation.
                  const _Perforation(),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${o.percent}%',
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'OFF',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "ACTIVE" stamp, pressed on with a thud.
          if (widget.applied)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 520),
                  builder: (context, t, child) {
                    final fall = Curves.easeIn.transform(
                      (t / 0.6).clamp(0.0, 1.0),
                    );
                    final settle = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
                    final squash = math.sin(settle * math.pi) * 0.08;
                    return Opacity(
                      opacity: fall,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..rotateZ(-0.18)
                          ..scaleByDouble(
                            2 - fall + squash,
                            2 - fall - squash,
                            1,
                            1,
                          ),
                        child: child,
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.8),
                          width: 2.5,
                        ),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 20,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                          color: _green.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 8; i++)
          Container(
            width: 2,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFBFD3EC),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    ),
  );
}

/// Rounded ticket with half-circle notches on both sides at the
/// perforation ([stub] = fraction of the width taken by the right part).
class _CouponShape extends CustomClipper<Path> {
  const _CouponShape({required this.stub});

  final double stub;

  @override
  Path getClip(Size size) {
    const r = 18.0;
    const notch = 10.0;
    final cut = size.width * (1 - stub);
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)),
      );
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(cut, 0), radius: notch))
      ..addOval(
        Rect.fromCircle(center: Offset(cut, size.height), radius: notch),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(0, size.height / 2), radius: notch),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height / 2),
          radius: notch,
        ),
      );
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_CouponShape old) => old.stub != stub;
}
