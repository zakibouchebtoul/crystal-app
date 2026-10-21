import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/bookings.dart';
import '../../data/service_catalog.dart';
import '../../data/weather.dart';
import '../../data/favourites.dart';
import '../booking/booking_details_screen.dart';
import '../service/companies_screen.dart';
import '../service/company_screen.dart';

const _ink = AppColors.ink;
const _muted = Color(0xFF6A7B89);
const _border = AppColors.border;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _dayLabel(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

// ---------------------------------------------------------------------------
// Upcoming booking

/// Where a booking stands.
enum _Status { confirmed, onTheWay, inProgress }

_Status _statusOf(Booking b, DateTime now) {
  if (!now.isBefore(b.start)) return _Status.inProgress;
  if (b.start.difference(now).inMinutes <= 60) return _Status.onTheWay;
  return _Status.confirmed;
}

/// Upcoming bookings as a stacked deck: the next one in front, the others
/// peeking out underneath. Swipe to flick through them; the front card
/// flies off and the next rises up. Each card has the company's photo
/// slowly drifting, a live rolling countdown and a tracker
/// (confirmed → on the way → in progress). Hidden when nothing is coming.
class UpcomingBookingCard extends StatefulWidget {
  const UpcomingBookingCard({
    super.key,
    required this.onOpen,
    required this.header,
  });

  /// Opens the calendar on the tapped booking.
  final ValueChanged<Booking> onOpen;

  /// Section title (built by home so it matches the other sections),
  /// given each upcoming booking's service colour and the position dots.
  final Widget Function(List<Color> colors, Widget dots) header;

  @override
  State<UpcomingBookingCard> createState() => _UpcomingBookingCardState();
}

class _UpcomingBookingCardState extends State<UpcomingBookingCard>
    with TickerProviderStateMixin {
  DateTime _now = DateTime.now();
  Timer? _tick;
  int _index = 0;

  /// +1 when flicking forward, -1 back (sets the fly-off direction).
  int _direction = 1;
  double _drag = 0;

  /// Breathing dots, flowing tracker line.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  /// Slow zoom and pan on the photo.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    bookingStore.addListener(_refresh);
    _restartTimer();
  }

  /// Every second when a booking is less than an hour away, otherwise
  /// every 30 seconds.
  void _restartTimer() {
    _tick?.cancel();
    final list = bookingStore.upcoming(_now);
    final soon =
        list.isNotEmpty && list.first.start.difference(_now).inMinutes < 60;
    _tick = Timer.periodic(Duration(seconds: soon ? 1 : 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
  }

  @override
  void dispose() {
    bookingStore.removeListener(_refresh);
    _tick?.cancel();
    _pulse.dispose();
    _drift.dispose();
    super.dispose();
  }

  void _flick(int delta, int count) {
    final next = _index + delta;
    if (next < 0 || next >= count) {
      setState(() => _drag = 0);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _direction = delta;
      _index = next;
      _drag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = bookingStore.upcoming(_now);
    if (_index >= list.length) _index = math.max(0, list.length - 1);
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: list.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              // Room below for the cards peeking out of the stack.
              padding: const EdgeInsets.only(top: 6, bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.header([
                    for (final b in list) b.type.color,
                  ], _dots(list.length)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _deck(list),
                  ),
                ],
              ),
            ),
    );
  }

  /// Position dots; the current one stretches.
  Widget _dots(int count) {
    if (count < 2) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < math.min(count, 5); i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(left: 4),
            width: i == math.min(_index, 4) ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == math.min(_index, 4)
                  ? AppColors.primary
                  : const Color(0xFFD9E6F7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }

  Widget _deck(List<Booking> list) {
    final behind = math.min(list.length - 1 - _index, 2);
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
      onHorizontalDragEnd: (d) {
        final v = d.velocity.pixelsPerSecond.dx;
        if (_drag < -60 || v < -400) {
          _flick(1, list.length);
        } else if (_drag > 60 || v > 400) {
          _flick(-1, list.length);
        } else {
          setState(() => _drag = 0);
        }
      },
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onOpen(list[_index]);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cards waiting underneath, peeking out at the bottom.
          for (var i = behind; i >= 1; i--)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translateByDouble(0, 10.0 * i, 0, 1)
                  ..scaleByDouble(1 - 0.05 * i, 1 - 0.05 * i, 1, 1),
                transformAlignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white,
                    const Color(0xFFEFF5FE),
                    i / 2,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE3ECF8)),
                ),
              ),
            ),
          // Front card follows the finger with a slight tilt.
          Transform.translate(
            offset: Offset(_drag * 0.6, 0),
            child: Transform.rotate(
              angle: _drag * 0.0006,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) =>
                    Stack(children: [...previous, ?current]),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_index);
                  return AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) {
                      final t = animation.value;
                      if (incoming) {
                        // Rises from the stack.
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - t)),
                            child: Transform.scale(
                              scale: 0.94 + 0.06 * t,
                              child: child,
                            ),
                          ),
                        );
                      }
                      // Flies off sideways.
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(-_direction * 260 * (1 - t), 0),
                          child: Transform.rotate(
                            angle: -_direction * 0.12 * (1 - t),
                            child: child,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: _UpcomingCard(
                    booking: list[_index],
                    now: _now,
                    pulse: _pulse,
                    drift: _drift,
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

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.booking,
    required this.now,
    required this.pulse,
    required this.drift,
  });

  final Booking booking;
  final DateTime now;
  final Animation<double> pulse;
  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = _statusOf(b, now);
    final company = b.companyId == null ? null : companyById(b.companyId!);
    final target = status == _Status.inProgress ? b.end : b.start;
    final left = target.difference(now);
    final statusLabel = switch (status) {
      _Status.confirmed => 'Confirmed',
      _Status.onTheWay => 'Pro on the way',
      _Status.inProgress => 'In progress',
    };
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo header.
          ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              height: 128,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: drift,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(drift.value);
                      return Transform.scale(
                        scale: 1.06 + 0.06 * t,
                        alignment: Alignment(-0.6 + 1.2 * t, 0),
                        child: child,
                      );
                    },
                    child: _Photo(booking: b, company: company),
                  ),
                  // Darkens the bottom for the countdown.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x14000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Glass(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_dayLabel(b.start, now)} · ${_clock(b.start)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _Glass(
                      tint: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LiveDot(pulse: pulse),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            status == _Status.inProgress
                                ? 'Ends in'
                                : 'Starts in',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        _Countdown(left: left),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _BookingLogo(booking: b, size: 40),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  b.provider,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              if (company?.verified ?? false) ...[
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b.price} QAR',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _StatusStrip(booking: b, now: now, pulse: pulse),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The company's cover, or a blue backdrop with the service picture.
class _Photo extends StatelessWidget {
  const _Photo({required this.booking, required this.company});

  final Booking booking;
  final Company? company;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D8BFF), Color(0xFF0B3E8F)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.75, -0.1),
        child: Image.asset(booking.type.image, width: 96, height: 96),
      ),
    );
    final photo = booking.image ?? company?.cover;
    if (photo == null) return fallback;
    return Image.asset(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Frosted pill over the photo.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.tint = false});

  final Widget child;

  /// Crystal blue instead of frosted white.
  final bool tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: tint
                ? AppColors.primary.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return SizedBox.square(
          dimension: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6 + 6 * t,
                height: 6 + 6 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45 * (1 - t)),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "02d 14h 05m" in frosted tiles; each digit rolls up when it changes.
/// Seconds show in the last hour.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final d = left.isNegative ? Duration.zero : left;
    final parts = <(int, String)>[
      if (d.inDays > 0) (d.inDays, 'd'),
      if (d.inDays > 0 || d.inHours > 0) (d.inHours % 24, 'h'),
      (d.inMinutes % 60, 'm'),
      if (d.inHours == 0) (d.inSeconds % 60, 's'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (value, unit)) in parts.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          _Glass(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final ch in value.toString().padLeft(2, '0').split(''))
                  _RollingDigit(ch),
                const SizedBox(width: 1),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RollingDigit extends StatelessWidget {
  const _RollingDigit(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 11,
        height: 22,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, a) {
            final incoming = child.key == ValueKey(digit);
            return SlideTransition(
              position: Tween(
                begin: Offset(0, incoming ? 1 : -1),
                end: Offset.zero,
              ).animate(a),
              child: child,
            );
          },
          child: Text(
            digit,
            key: ValueKey(digit),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the booking stands, compactly: three slim segments (confirmed,
/// on the way, in progress) — reached ones solid blue, the current one
/// with light flowing through it — and one line saying what happens next,
/// with a button to the booking's details.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.booking,
    required this.now,
    required this.pulse,
  });

  final Booking booking;
  final DateTime now;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = _statusOf(b, now);
    final step = status.index;
    final (icon, title, hint) = switch (status) {
      _Status.confirmed => (
        Icons.check_circle_rounded,
        'Confirmed',
        'Pro sets off around ${_clock(b.start.subtract(const Duration(hours: 1)))}',
      ),
      _Status.onTheWay => (
        Icons.delivery_dining_rounded,
        'On the way',
        'Arriving around ${_clock(b.start)}',
      ),
      _Status.inProgress => (
        Icons.cleaning_services_rounded,
        'In progress',
        'Done around ${_clock(b.end)}',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _Segment(
                    filled: i < step,
                    current: i == step,
                    flow: pulse.value,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    TextSpan(text: ' · $hint'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(BookingDetailsScreen.route(b));
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                decoration: BoxDecoration(
                  color: AppColors.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One slim segment of the strip.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.filled,
    required this.current,
    required this.flow,
  });

  final bool filled;
  final bool current;
  final double flow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : current
              ? const Color(0xFFCFE3FC)
              : const Color(0xFFE9EFF7),
          gradient: current
              // A band of blue sweeping along, over and over.
              ? LinearGradient(
                  begin: Alignment(-3 + 4 * flow, 0),
                  end: Alignment(-1 + 9 * flow, 0),
                  colors: const [
                    Color(0xFFCFE3FC),
                    AppColors.primary,
                    Color(0xFFCFE3FC),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Book again

/// Past bookings to repeat in one tap: opens the same company with the
/// same package chosen, at today's price.
class BookAgainRow extends StatefulWidget {
  const BookAgainRow({super.key, required this.header});

  /// Section title (built by home so it matches the other sections).
  final Widget header;

  @override
  State<BookAgainRow> createState() => _BookAgainRowState();
}

class _BookAgainRowState extends State<BookAgainRow> {
  @override
  void initState() {
    super.initState();
    bookingStore.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    bookingStore.removeListener(_refresh);
    super.dispose();
  }

  /// The service, company and current package for [b], if all still exist.
  (ServiceDetail, CompanyOffer, ServicePackage)? _resolve(Booking b) {
    final service = serviceById(b.serviceId!);
    if (service == null) return null;
    for (final o in service.companies) {
      if (o.company.id != b.companyId) continue;
      final p = packageIn(o, b.package!);
      return p == null ? null : (service, o, p);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = [
      for (final b in bookingStore.bookAgain(now))
        if (_resolve(b) case final r?) (b, r),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        widget.header,
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (b, (service, offer, package)) = items[i];
              return _AgainCard(
                booking: b,
                price: package.price,
                ago: _ago(now.difference(b.start)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    CompanyServiceScreen.compareRoute(
                      service,
                      offer,
                      package.name,
                      compare: false,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _ago(Duration d) {
    final days = d.inDays;
    if (days <= 0) return 'Earlier today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    final weeks = days ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
}

class _AgainCard extends StatefulWidget {
  const _AgainCard({
    required this.booking,
    required this.price,
    required this.ago,
    required this.onTap,
  });

  final Booking booking;
  final int price;
  final String ago;
  final VoidCallback onTap;

  @override
  State<_AgainCard> createState() => _AgainCardState();
}

class _AgainCardState extends State<_AgainCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 200),
        child: Container(
          width: 236,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _BookingLogo(booking: b, size: 44),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.package!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.provider} · ${widget.ago}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Book again',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.price} QAR',
                      style: const TextStyle(
                        fontSize: 13,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Weather-aware tip

/// The week's weather in one card: dust drifting across a sandy sky, the
/// next five days with the first clear one picked out, and a shortcut to
/// book a car wash for it.
class WeatherTipCard extends StatefulWidget {
  const WeatherTipCard({super.key});

  @override
  State<WeatherTipCard> createState() => _WeatherTipCardState();
}

class _WeatherTipCardState extends State<WeatherTipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clear = firstClearDay;
    final now = DateTime.now();
    final dusty = forecast.first.sky == Sky.dust;
    if (clear == null) return const SizedBox.shrink();
    final clearDate = now.add(Duration(days: clear.dayOffset));
    final clearName = clear.dayOffset == 1
        ? 'tomorrow'
        : _weekdays[clearDate.weekday - 1];
    var dustDays = 0;
    for (final d in forecast) {
      if (d.sky == Sky.clear) break;
      dustDays++;
    }
    final service = serviceCatalog['Car wash'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFBF1E3), Color(0xFFEDF4FD)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => CustomPaint(
                    painter: _DustPainter(_drift.value, dusty ? 1 : 0.3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.air_rounded,
                          size: 18,
                          color: Color(0xFFB07A2A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dusty
                                ? 'Dusty for the next $dustDays days'
                                : 'Hazy skies ahead',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Skies clear $clearName. Book your car wash then '
                      'so it stays clean longer.',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final d in forecast)
                          Expanded(
                            child: _ForecastDay(
                              day: d,
                              label: d.dayOffset == 0
                                  ? 'Today'
                                  : _weekdays[now
                                            .add(Duration(days: d.dayOffset))
                                            .weekday -
                                        1],
                              best: d == clear,
                              drift: _drift,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (service != null)
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(
                              context,
                            ).push(CompaniesScreen.route(service));
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: const StadiumBorder(),
                            textStyle: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          child: Text(
                            'Book a car wash for '
                            '${clear.dayOffset == 1 ? 'tomorrow' : clearName}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastDay extends StatelessWidget {
  const _ForecastDay({
    required this.day,
    required this.label,
    required this.best,
    required this.drift,
  });

  final DayForecast day;
  final String label;
  final bool best;
  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (day.sky) {
      Sky.dust => (Icons.air_rounded, const Color(0xFFC98A1E)),
      Sky.hazy => (Icons.wb_cloudy_rounded, const Color(0xFF9AA7B6)),
      Sky.clear => (Icons.wb_sunny_rounded, const Color(0xFFFFB020)),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: best ? Colors.white : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: best ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: best ? FontWeight.w700 : FontWeight.w500,
              color: best ? AppColors.primary : _muted,
            ),
          ),
          const SizedBox(height: 4),
          // The sun turns, cloud and wind sway.
          AnimatedBuilder(
            animation: drift,
            builder: (context, child) {
              final t = drift.value * 2 * math.pi;
              return switch (day.sky) {
                Sky.clear => Transform.rotate(angle: t, child: child),
                _ => Transform.translate(
                  offset: Offset(2 * math.sin(t * 2), 0),
                  child: child,
                ),
              };
            },
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.high}°',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fine sand grains streaming across the card.
class _DustPainter extends CustomPainter {
  const _DustPainter(this.t, this.strength);

  final double t;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 40; i++) {
      final speed = 0.6 + rnd.nextDouble();
      final y = rnd.nextDouble() * size.height;
      final x = ((rnd.nextDouble() + t * speed) % 1.0) * (size.width + 40) - 20;
      final r = 0.8 + rnd.nextDouble() * 1.6;
      paint.color = const Color(
        0xFFC98A1E,
      ).withValues(alpha: (0.12 + rnd.nextDouble() * 0.2) * strength);
      canvas.drawCircle(
        Offset(x, y + 3 * math.sin((t * 2 + i) * math.pi)),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

/// The company's logo for a booking; the service picture while the logo
/// hasn't been added.
class _BookingLogo extends StatelessWidget {
  const _BookingLogo({required this.booking, required this.size});

  final Booking booking;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      booking.type.image,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final company = booking.companyId == null
        ? null
        : companyById(booking.companyId!);
    if (company == null) return fallback;
    return Image.asset(
      company.logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

// ---------------------------------------------------------------------------
// Favourites

/// Heart on a photo: tap to save or remove; it pops and bursts when saved.
class FavouriteHeart extends StatefulWidget {
  const FavouriteHeart({super.key, required this.favourite});

  final Favourite favourite;

  @override
  State<FavouriteHeart> createState() => _FavouriteHeartState();
}

class _FavouriteHeartState extends State<FavouriteHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favourites,
      builder: (context, _) {
        final on = favourites.contains(widget.favourite);
        return GestureDetector(
          onTap: () {
            final added = favourites.toggle(widget.favourite);
            HapticFeedback.lightImpact();
            if (added) _pop.forward(from: 0);
          },
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, _) {
              final t = _pop.value;
              final scale = _pop.isAnimating
                  ? 1 + 0.35 * math.sin(t * math.pi) * (1 - t)
                  : 1.0;
              return SizedBox.square(
                dimension: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Little burst of dots when saved.
                    if (_pop.isAnimating)
                      for (var i = 0; i < 6; i++)
                        Transform.translate(
                          offset: Offset.fromDirection(
                            i * math.pi / 3 - math.pi / 2,
                            12 + 12 * Curves.easeOut.transform(t),
                          ),
                          child: Opacity(
                            opacity: 1 - t,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 34,
                          height: 34,
                          color: Colors.white.withValues(alpha: 0.25),
                          child: Transform.scale(
                            scale: scale,
                            child: Icon(
                              on
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: on
                                  ? const Color(0xFFFF4D5E)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// "Your favourites": hearted packages, each opening the best-rated
/// company for it. Hidden until something is saved; cards slide in and
/// out as hearts change.
class FavouritesRow extends StatelessWidget {
  const FavouritesRow({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favourites,
      builder: (context, _) {
        final items = [
          for (final f in favourites.all)
            if (serviceById(f.serviceId) case final s?)
              if (offersWithPackage(s, f.package).isNotEmpty) (f, s),
        ];
        return AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: items.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    header,
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final (f, s) = items[i];
                          return _FavouriteCard(
                            key: ValueKey(f),
                            favourite: f,
                            service: s,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({
    super.key,
    required this.favourite,
    required this.service,
  });

  final Favourite favourite;
  final ServiceDetail service;

  @override
  Widget build(BuildContext context) {
    final f = favourite;
    final price = lowestPrice(service, f.package);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            CompanyServiceScreen.compareRoute(
              service,
              offersWithPackage(service, f.package).first,
              f.package,
            ),
          );
        },
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  service.tileImage,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.package,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${service.title} · from '),
                          TextSpan(
                            text: '$price QAR',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: Color(0xFFFF4D5E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rate your last service

/// "How was Wash & fold?" with five stars. Tapping a star fills them one
/// after another, says thanks, then the card folds away. The × skips it.
class RateLastCard extends StatefulWidget {
  const RateLastCard({super.key});

  @override
  State<RateLastCard> createState() => _RateLastCardState();
}

class _RateLastCardState extends State<RateLastCard> {
  Booking? _thanking;
  int _stars = 0;

  Future<void> _rate(Booking b, int stars) async {
    if (_thanking != null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _thanking = b;
      _stars = stars;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    bookingStore.rate(b, stars);
    setState(() => _thanking = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bookingStore,
      builder: (context, _) {
        final b = _thanking ?? bookingStore.toRate(DateTime.now());
        return AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: b == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _card(b),
                ),
        );
      },
    );
  }

  Widget _card(Booking b) {
    final thanked = _thanking != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _BookingLogo(booking: b, size: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(thanked),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thanked
                            ? 'Thanks for rating!'
                            : 'How was ${b.package ?? b.title}?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thanked
                            ? 'It helps others choose ${b.provider}'
                            : 'Rate ${b.provider}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (!thanked)
                IconButton(
                  onPressed: () => bookingStore.rate(b, 0),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFFB3BCC3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => _rate(b, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _Star(
                      on: i <= _stars && thanked,
                      // Fill one after another.
                      delay: Duration(milliseconds: 70 * i),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.on, required this.delay});

  final bool on;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1 : 0),
      duration: Duration(milliseconds: on ? 420 + delay.inMilliseconds : 200),
      curve: on
          ? Interval(
              delay.inMilliseconds / (420 + delay.inMilliseconds),
              1,
              curve: Curves.elasticOut,
            )
          : Curves.easeOut,
      builder: (context, t, _) => Transform.scale(
        // The elastic curve overshoots, so each star pops as it fills.
        scale: 0.85 + 0.15 * t,
        child: Icon(
          t > 0.5 ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 34,
          color: Color.lerp(
            const Color(0xFFD5DDE6),
            const Color(0xFFFFB020),
            t.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pull to refresh

/// Crystal's diamond as a pull-to-refresh spinner: it grows and turns as
/// the page is pulled, then spins while refreshing.
class DiamondRefresh extends StatefulWidget {
  const DiamondRefresh({
    super.key,
    required this.pulled,
    required this.refreshing,
  });

  /// 0 → 1 as the pull reaches the trigger point.
  final double pulled;
  final bool refreshing;

  @override
  State<DiamondRefresh> createState() => _DiamondRefreshState();
}

class _DiamondRefreshState extends State<DiamondRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(DiamondRefresh old) {
    super.didUpdateWidget(old);
    if (widget.refreshing && !_spin.isAnimating) _spin.repeat();
    if (!widget.refreshing && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pulled.clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, _) => Opacity(
        opacity: p,
        child: Transform(
          alignment: Alignment.center,
          // Turns like a gem on its axis.
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY((p + _spin.value) * math.pi * 2)
            ..scaleByDouble(0.6 + 0.4 * p, 0.6 + 0.4 * p, 1, 1),
          child: const SizedBox(
            width: 30,
            height: 26,
            child: CustomPaint(painter: _DiamondPainter()),
          ),
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final crown = h * 0.34;
    final top = Path()
      ..moveTo(w * 0.22, 0)
      ..lineTo(w * 0.78, 0)
      ..lineTo(w, crown)
      ..lineTo(0, crown)
      ..close();
    final body = Path()
      ..moveTo(0, crown)
      ..lineTo(w, crown)
      ..lineTo(w / 2, h)
      ..close();
    canvas
      ..drawPath(top, Paint()..color = const Color(0xFF5FA8FF))
      ..drawPath(body, Paint()..color = AppColors.primary)
      // Facet lines.
      ..drawPath(
        Path()
          ..moveTo(w * 0.22, 0)
          ..lineTo(w * 0.36, crown)
          ..lineTo(w / 2, h)
          ..lineTo(w * 0.64, crown)
          ..lineTo(w * 0.78, 0)
          ..moveTo(w / 2, 0)
          ..lineTo(w * 0.36, crown)
          ..moveTo(w / 2, 0)
          ..lineTo(w * 0.64, crown),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.55),
      );
  }

  @override
  bool shouldRepaint(_DiamondPainter oldDelegate) => false;
}
