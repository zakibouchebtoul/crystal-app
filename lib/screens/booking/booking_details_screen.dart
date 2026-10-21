import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/addresses.dart';
import '../../data/bookings.dart';
import '../../data/messages.dart';
import '../../data/service_catalog.dart';
import '../../widgets/app_toast.dart';
import '../messages/chat_screen.dart';
import '../service/company_screen.dart';

const _muted = Color(0xFF6A7B89);
const _danger = Color(0xFFE5484D);

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

String _date(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

String _duration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  return m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
}

/// Where a booking stands.
enum BookingStage { confirmed, onTheWay, inProgress, done }

BookingStage stageOf(Booking b, DateTime now) {
  if (b.isCompleted(now)) return BookingStage.done;
  if (!now.isBefore(b.start)) return BookingStage.inProgress;
  if (b.start.difference(now).inMinutes <= 60) return BookingStage.onTheWay;
  return BookingStage.confirmed;
}

/// Everything about one booking: the photo, who's coming (message or
/// call them), a live status timeline, when / where / how much, and
/// actions to reschedule or cancel (or book again once it's done).
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.booking});

  final Booking booking;

  static Route<void> route(Booking booking) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => BookingDetailsScreen(booking: booking),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with TickerProviderStateMixin {
  /// Entrance: photo settles, type rises, cards follow, the route draws,
  /// the receipt prints.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  /// Slow drift on the cover photo.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat(reverse: true);

  late Booking _b = widget.booking;
  DateTime _now = DateTime.now();
  Timer? _tick;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  Company? get _company =>
      _b.companyId == null ? null : companyById(_b.companyId!);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _intro.dispose();
    _drift.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _message() {
    HapticFeedback.selectionClick();
    final name = _b.provider;
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    Navigator.of(context).push(
      ChatScreen.route(
        Conversation(
          name: name,
          subtitle: 'Your pro for ${_b.title}',
          time: 'now',
          avatar: AvatarKind.initials,
          initials: initials,
          avatarColor: AppColors.tint,
          initialsColor: AppColors.primary,
          online: true,
          history: [
            ChatText(
              'Hi Bo! This is $name. We\'re all set for ${_b.title} on '
              '${_date(_b.start)} at ${_clock(_b.start)}. Anything we should '
              'know before we come?',
            ),
          ],
          quickReplies: const [
            'Please call when you arrive',
            'Gate code is 1234',
            'Thank you!',
          ],
        ),
      ),
    );
  }

  Future<void> _call() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _CallSheet(
        name: _b.provider,
        onCopy: () {
          Navigator.of(sheet).pop();
          showAppToast(
            context,
            icon: Icons.content_copy_rounded,
            title: 'Number copied',
            message: 'Paste it in your phone app to call',
            color: AppColors.primary,
          );
        },
      ),
    );
  }

  Future<void> _reschedule() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RescheduleSheet(current: _b.start),
    );
    if (picked == null || !mounted) return;
    setState(() => _b = bookingStore.reschedule(_b, picked));
    showAppToast(
      context,
      icon: Icons.event_available_rounded,
      title: 'Booking moved',
      message: '${_date(picked)} at ${_clock(picked)}',
      color: AppColors.primary,
    );
  }

  Future<void> _cancel() async {
    HapticFeedback.selectionClick();
    final sure = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CancelSheet(booking: _b),
    );
    if (sure != true || !mounted) return;
    bookingStore.cancel(_b);
    HapticFeedback.mediumImpact();
    showAppToast(
      context,
      icon: Icons.event_busy_rounded,
      title: 'Booking cancelled',
      message: '${_b.title} with ${_b.provider}',
      color: _danger,
    );
    Navigator.of(context).pop();
  }

  void _bookAgain() {
    final service = _b.serviceId == null ? null : serviceById(_b.serviceId!);
    if (service == null) return;
    for (final o in service.companies) {
      if (o.company.id == _b.companyId) {
        Navigator.of(context).push(
          CompanyServiceScreen.compareRoute(
            service,
            o,
            _b.package ?? '',
            compare: false,
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = stageOf(_b, _now);
    final done = stage == BookingStage.done;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) => CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CoverDelegate(
                      booking: _b,
                      stage: stage,
                      top: top,
                      intro: _intro.value,
                      drift: _drift,
                      pulse: _pulse,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                    sliver: SliverList.list(
                      children: [
                        _rise(
                          0.25,
                          _Countdown(booking: _b, now: _now, stage: stage),
                        ),
                        const SizedBox(height: 22),
                        _rise(
                          0.35,
                          _RouteCard(
                            booking: _b,
                            now: _now,
                            stage: stage,
                            draw: _phase(0.45, 0.85, Curves.easeInOutCubic),
                            loop: _pulse,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _rise(0.45, const _Label('Your day')),
                        const SizedBox(height: 10),
                        _rise(
                          0.5,
                          _DayRibbon(
                            booking: _b,
                            now: _now,
                            grow: _phase(0.55, 0.9, Curves.easeOutCubic),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _rise(0.55, const _Label('Your pro')),
                        const SizedBox(height: 10),
                        _flipIn(
                          0.6,
                          _BusinessCard(
                            booking: _b,
                            company: _company,
                            onMessage: _message,
                            onCall: _call,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _rise(0.65, const _Label('Receipt')),
                        const SizedBox(height: 10),
                        _Receipt(
                          booking: _b,
                          print: _phase(0.7, 1, Curves.easeOutCubic),
                        ),
                        const SizedBox(height: 18),
                        _rise(
                          0.8,
                          Center(
                            child: TextButton.icon(
                              onPressed: _message,
                              icon: const Icon(
                                Icons.support_agent_rounded,
                                size: 18,
                              ),
                              label: const Text('Something not right?'),
                              style: TextButton.styleFrom(
                                foregroundColor: _muted,
                              ),
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
          // Actions rise in last.
          AnimatedBuilder(
            animation: _intro,
            builder: (context, child) {
              final t = _phase(0.6, 1, Curves.easeOutCubic);
              return Transform.translate(
                offset: Offset(0, 40 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              );
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: done
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _bookAgain,
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('Book again'),
                        style: _filled(context),
                      ),
                    )
                  : Row(
                      children: [
                        TextButton(
                          onPressed: _cancel,
                          style: TextButton.styleFrom(
                            foregroundColor: _danger,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            minimumSize: const Size(0, 52),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: stage == BookingStage.inProgress
                                  ? null
                                  : _reschedule,
                              icon: const Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                              ),
                              label: const Text('Reschedule'),
                              style: _filled(context),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  double _phase(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));

  /// Fades and lifts [child] in from [from] (fraction of the entrance).
  Widget _rise(double from, Widget child) {
    final t = _phase(from, from + 0.3, Curves.easeOutCubic);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 22 * (1 - t)), child: child),
    );
  }

  /// Swings [child] in like a card turned over onto the table.
  Widget _flipIn(double from, Widget child) {
    final t = _phase(from, from + 0.3, Curves.easeOutBack);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(-0.9 * (1 - t)),
        child: child,
      ),
    );
  }

  ButtonStyle _filled(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    disabledBackgroundColor: const Color(0xFFB9D6FC),
    disabledForegroundColor: Colors.white,
    shape: const StadiumBorder(),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w700,
      color: Color(0xFFA9B6C6),
    ),
  );
}

// ---------------------------------------------------------------------------
// Cover

/// The photo, set like a magazine cover: a big day number with the month
/// and weekday beside it, the title under it. The photo drifts slowly,
/// stretches when pulled, and as the page scrolls it folds into a frosted
/// bar with the title.
class _CoverDelegate extends SliverPersistentHeaderDelegate {
  _CoverDelegate({
    required this.booking,
    required this.stage,
    required this.top,
    required this.intro,
    required this.drift,
    required this.pulse,
  });

  final Booking booking;
  final BookingStage stage;
  final double top;
  final double intro;
  final Animation<double> drift;
  final Animation<double> pulse;

  static const _expanded = 360.0;

  @override
  double get maxExtent => _expanded + top;

  @override
  double get minExtent => top + 58;

  @override
  bool shouldRebuild(_CoverDelegate old) =>
      old.booking != booking ||
      old.stage != stage ||
      old.intro != intro ||
      old.top != top;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final b = booking;
    final range = maxExtent - minExtent;
    final c = (shrink / range).clamp(0.0, 1.0); // 0 open → 1 collapsed
    final company = b.companyId == null ? null : companyById(b.companyId!);
    final photo = b.image ?? company?.cover;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D8BFF), Color(0xFF0B3E8F)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.7, -0.1),
        child: Image.asset(b.type.image, width: 150, height: 150),
      ),
    );
    // Entrance: photo settles from a slight zoom; type rises.
    final settle = Curves.easeOutCubic.transform((intro / 0.5).clamp(0.0, 1.0));
    final type = Curves.easeOutCubic.transform(
      ((intro - 0.12) / 0.4).clamp(0.0, 1.0),
    );
    final radius = 30 * (1 - c);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: drift,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(drift.value);
                  return Transform.translate(
                    // Parallax: the photo moves slower than the page.
                    offset: Offset(0, shrink * 0.45),
                    child: Transform.scale(
                      scale: 1.04 + 0.06 * t + 0.12 * (1 - settle),
                      child: child,
                    ),
                  );
                },
                child: photo == null
                    ? fallback
                    : Image.asset(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0, 0.3, 1],
                  ),
                ),
              ),
              // Frosted bar it folds into.
              if (c > 0)
                Opacity(
                  opacity: c,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Magazine-style date and title, fading as it folds.
        Positioned(
          left: 24,
          right: 24,
          bottom: 22,
          child: Opacity(
            opacity: (type * (1 - c * 1.6)).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 26 * (1 - type) - shrink * 0.25),
              child: _CoverType(booking: b, stage: stage, pulse: pulse),
            ),
          ),
        ),
        // Collapsed title.
        Positioned(
          left: 72,
          right: 24,
          top: top + 18,
          child: Opacity(
            opacity: ((c - 0.6) / 0.4).clamp(0.0, 1.0),
            child: Text(
              b.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: top + 7,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 44,
                  height: 44,
                  color: Color.lerp(
                    Colors.white.withValues(alpha: 0.22),
                    const Color(0xFFF1F3F6),
                    c,
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color.lerp(Colors.white, AppColors.ink, c),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverType extends StatelessWidget {
  const _CoverType({
    required this.booking,
    required this.stage,
    required this.pulse,
  });

  final Booking booking;
  final BookingStage stage;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final label = switch (stage) {
      BookingStage.confirmed => 'Confirmed',
      BookingStage.onTheWay => 'Pro on the way',
      BookingStage.inProgress => 'In progress',
      BookingStage.done => 'Completed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${b.start.day}',
              style: const TextStyle(
                fontSize: 64,
                height: 0.9,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_months[b.start.month - 1].toUpperCase()} · '
                      '${_weekdays[b.start.weekday - 1].toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_clock(b.start)} – ${_clock(b.end)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Status: a soft pill with a breathing dot.
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  color: Colors.white.withValues(alpha: 0.2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (context, _) => Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stage == BookingStage.done
                                ? const Color(0xFF5EE38A)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: 0.6 * (1 - pulse.value),
                                ),
                                blurRadius: 2,
                                spreadRadius: 5 * pulse.value,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          b.title,
          style: const TextStyle(
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown

/// How long until it starts (or ends), set big.
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.booking,
    required this.now,
    required this.stage,
  });

  final Booking booking;
  final DateTime now;
  final BookingStage stage;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    if (stage == BookingStage.done) {
      return Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Completed\n'),
            TextSpan(
              text: '${_date(b.start)} at ${_clock(b.end)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );
    }
    final target = stage == BookingStage.inProgress ? b.end : b.start;
    final left = target.difference(now);
    final parts = <(int, String)>[
      if (left.inDays > 0) (left.inDays, left.inDays == 1 ? 'day' : 'days'),
      if (left.inDays > 0 || left.inHours > 0) (left.inHours % 24, 'hrs'),
      if (left.inDays == 0) (left.inMinutes % 60, 'min'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stage == BookingStage.inProgress ? 'Done in' : 'Starts in',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 14,
          children: [
            for (final (v, unit) in parts)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$v'),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: Color(0xFFA9B6C6),
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 40,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Route

/// A little hand-drawn street map: the company's pin, your home, and the
/// route between them drawing itself in. The van waits at the company,
/// drives along while the pro is on the way, and parks at your door once
/// the job starts.
class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.booking,
    required this.now,
    required this.stage,
    required this.draw,
    required this.loop,
  });

  final Booking booking;
  final DateTime now;
  final BookingStage stage;

  /// 0 → 1 as the route draws in.
  final double draw;
  final Animation<double> loop;

  /// Where the van is along the route.
  double get _van => switch (stage) {
    BookingStage.confirmed => 0,
    BookingStage.onTheWay =>
      (1 - booking.start.difference(now).inMinutes / 60).clamp(0.05, 0.95),
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final a = addressBook.selected;
    final (headline, sub) = switch (stage) {
      BookingStage.confirmed => (
        '${b.provider} sets off around '
            '${_clock(b.start.subtract(const Duration(hours: 1)))}',
        'We\'ll let you know when they\'re on the way',
      ),
      BookingStage.onTheWay => (
        '${b.provider} is on the way',
        'Arriving around ${_clock(b.start)}',
      ),
      BookingStage.inProgress => (
        '${b.provider} is at your door',
        'Working until about ${_clock(b.end)}',
      ),
      BookingStage.done => ('All done', 'Finished at ${_clock(b.end)}'),
    };
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              height: 150,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) => CustomPaint(
                  painter: _MapPainter(
                    draw: draw,
                    van: _van * draw,
                    bob: loop.value,
                    moving: stage == BookingStage.onTheWay,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${a.label} · ${a.line}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.draw,
    required this.van,
    required this.bob,
    required this.moving,
  });

  final double draw;
  final double van;
  final double bob;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEEF3F9),
    );
    // Blocks and a park.
    final block = Paint()..color = const Color(0xFFE2EAF4);
    for (final r in [
      Rect.fromLTWH(w * 0.02, h * 0.05, w * 0.18, h * 0.32),
      Rect.fromLTWH(w * 0.27, h * 0.05, w * 0.22, h * 0.3),
      Rect.fromLTWH(w * 0.27, h * 0.6, w * 0.24, h * 0.36),
      Rect.fromLTWH(w * 0.62, h * 0.4, w * 0.2, h * 0.24),
      Rect.fromLTWH(w * 0.88, h * 0.4, w * 0.12, h * 0.56),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        block,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.72, w * 0.2, h * 0.24),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFD9EFDD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.55, h * 0.03, w * 0.43, h * 0.24),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFDCEBFA),
    );
    // Streets.
    final road = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    for (final (a, b) in [
      (Offset(w * 0.23, 0), Offset(w * 0.23, h)),
      (Offset(0, h * 0.48), Offset(w, h * 0.48)),
      (Offset(w * 0.56, h * 0.3), Offset(w * 0.56, h)),
      (Offset(w * 0.56, h * 0.33), Offset(w, h * 0.33)),
      (Offset(w * 0.85, h * 0.33), Offset(w * 0.85, h)),
    ]) {
      canvas.drawLine(a, b, road);
    }

    // The route: company (bottom left) → home (top right).
    final route = Path()
      ..moveTo(w * 0.23, h * 0.86)
      ..lineTo(w * 0.23, h * 0.48)
      ..lineTo(w * 0.56, h * 0.48)
      ..lineTo(w * 0.56, h * 0.33)
      ..lineTo(w * 0.85, h * 0.33)
      ..lineTo(w * 0.85, h * 0.2);
    final metric = route.computeMetrics().first;
    final len = metric.length;
    // Faint full route, dashed.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary.withValues(alpha: 0.35);
    for (var d = 0.0; d < len * draw; d += 10) {
      canvas.drawPath(metric.extractPath(d, math.min(d + 5, len * draw)), dash);
    }
    // Travelled part, solid.
    if (van > 0) {
      canvas.drawPath(
        metric.extractPath(0, len * van),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );
    }

    // Pins.
    final start = metric.getTangentForOffset(0)!.position;
    final end = metric.getTangentForOffset(len)!.position;
    _pin(canvas, start, AppColors.accent, draw);
    _pin(canvas, end, AppColors.primary, ((draw - 0.8) / 0.2).clamp(0.0, 1.0));

    // The van, with a soft halo; bobs a little while driving.
    if (draw > 0.2) {
      final at = metric.getTangentForOffset(len * van)!.position;
      final lift = moving ? 1.5 * math.sin(bob * math.pi * 2) : 0.0;
      final p = at.translate(0, -lift);
      canvas
        ..drawCircle(
          p,
          15,
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawCircle(p, 11, Paint()..color = Colors.white)
        ..drawCircle(
          p,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.primary,
        );
      // A tiny van: body, window, wheels.
      final body = Paint()..color = AppColors.primary;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p.translate(0, -0.5), width: 12, height: 7),
            const Radius.circular(2),
          ),
          body,
        )
        ..drawRect(
          Rect.fromLTWH(p.dx + 1.5, p.dy - 3, 3, 2.5),
          Paint()..color = Colors.white,
        )
        ..drawCircle(p.translate(-3.5, 3.5), 1.6, body)
        ..drawCircle(p.translate(3.5, 3.5), 1.6, body);
    }
  }

  void _pin(Canvas canvas, Offset at, Color color, double t) {
    if (t <= 0) return;
    final s = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    canvas
      ..drawCircle(at, 10 * s, Paint()..color = color.withValues(alpha: 0.2))
      ..drawCircle(at, 6 * s, Paint()..color = Colors.white)
      ..drawCircle(at, 4 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.draw != draw || old.van != van || old.bob != bob;
}

// ---------------------------------------------------------------------------
// Your day

/// The day from 7 AM to 9 PM with this booking placed on it, other
/// bookings that day faint, and a needle at the current time.
class _DayRibbon extends StatelessWidget {
  const _DayRibbon({
    required this.booking,
    required this.now,
    required this.grow,
  });

  final Booking booking;
  final DateTime now;
  final double grow;

  static const _from = 7;
  static const _to = 21;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final day = DateTime(b.start.year, b.start.month, b.start.day);
    double x(DateTime t, double w) {
      final h = t.difference(day).inMinutes / 60;
      return ((h - _from) / (_to - _from)).clamp(0.0, 1.0) * w;
    }

    final others = bookingStore.all.where(
      (o) =>
          o != b &&
          o.start.year == day.year &&
          o.start.month == day.month &&
          o.start.day == day.day,
    );
    final today =
        now.year == day.year && now.month == day.month && now.day == day.day;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track.
              Positioned(
                left: 0,
                right: 0,
                top: 14,
                height: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              for (final o in others)
                Positioned(
                  left: x(o.start, w),
                  width: math.max(x(o.end, w) - x(o.start, w), 6),
                  top: 20,
                  height: 26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              // This booking, growing in from its start.
              Positioned(
                left: x(b.start, w),
                top: 17,
                height: 32,
                child: Container(
                  width: math.max(x(b.end, w) - x(b.start, w), 10) * grow,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D9BFF), AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              if (today)
                Positioned(
                  left: x(now, w) - 1,
                  top: 8,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _danger,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              // Hour marks.
              for (var hr = _from; hr <= _to; hr += 2)
                Positioned(
                  left: (hr - _from) / (_to - _from) * w - 14,
                  top: 58,
                  width: 28,
                  child: Text(
                    hr == 12
                        ? '12p'
                        : hr < 12
                        ? '${hr}a'
                        : '${hr - 12}p',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA9B6C6),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Business card

/// The pro's business card. Drag it and it tilts towards your finger,
/// catching the light; let go and it springs back flat.
class _BusinessCard extends StatefulWidget {
  const _BusinessCard({
    required this.booking,
    required this.company,
    required this.onMessage,
    required this.onCall,
  });

  final Booking booking;
  final Company? company;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard>
    with SingleTickerProviderStateMixin {
  Offset _tilt = Offset.zero;
  Offset _from = Offset.zero;
  late final AnimationController _back;

  @override
  void initState() {
    super.initState();
    // Created up front: a lazy controller would first be built in
    // dispose, after the card has left the tree.
    _back =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addListener(() {
          setState(() {
            _tilt = Offset.lerp(
              _from,
              Offset.zero,
              Curves.elasticOut.transform(_back.value),
            )!;
          });
        });
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final company = widget.company;
    final fallback = Image.asset(
      b.type.image,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
    );
    // Light catches the card on the side tilted towards you.
    final shine = Alignment(-_tilt.dx * 3, -_tilt.dy * 3);
    return GestureDetector(
      onPanStart: (_) => _back.stop(),
      onPanUpdate: (d) => setState(() {
        _tilt = Offset(
          (_tilt.dx + d.delta.dx / 300).clamp(-0.25, 0.25),
          (_tilt.dy + d.delta.dy / 300).clamp(-0.25, 0.25),
        );
      }),
      onPanEnd: (_) {
        _from = _tilt;
        _back.forward(from: 0);
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(_tilt.dx)
          ..rotateX(-_tilt.dy),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: Offset(_tilt.dx * 30, 8 + _tilt.dy * 30),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: RadialGradient(
              center: shine,
              radius: 1.2,
              colors: [
                Colors.white.withValues(alpha: 0.35 * _tilt.distance * 4),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: company == null
                    ? fallback
                    : Image.asset(
                        company.logo,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (company?.verified ?? false) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        '★ ${b.rating} (${b.reviews})',
                        if (company != null) company.area,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              _RoundAction(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: widget.onMessage,
              ),
              const SizedBox(width: 8),
              _RoundAction(icon: Icons.call_outlined, onTap: widget.onCall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tint,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt

/// The receipt, printing out of a slot: paper slides down line by line,
/// with a torn zigzag edge at the bottom.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.booking, required this.print});

  final Booking booking;

  /// 0 → 1 as it prints.
  final double print;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final a = addressBook.selected;
    Widget line(String l, String r, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? AppColors.ink : _muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            r,
            style: TextStyle(
              fontSize: bold ? 20 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        // The slot it prints from.
        Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE3E8EF),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: print,
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipPath(
                  clipper: const _TornEdge(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    color: const Color(0xFFF7F8FA),
                    child: Column(
                      children: [
                        Text(
                          'CRYSTAL · ${_date(b.start).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA9B6C6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        line(b.title, '${b.price} QAR'),
                        line('Duration', _duration(b.duration)),
                        line(a.label, a.area),
                        line('Payment', 'After the service'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: _Dashes(),
                        ),
                        line('Total', '${b.price} QAR', bold: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      children: [
        for (var i = 0; i < (c.maxWidth / 8).floor(); i++)
          Container(
            width: 4,
            height: 1.2,
            margin: const EdgeInsets.only(right: 4),
            color: const Color(0xFFCBD3DD),
          ),
      ],
    ),
  );
}

/// Paper with a torn zigzag along the bottom.
class _TornEdge extends CustomClipper<Path> {
  const _TornEdge();

  @override
  Path getClip(Size size) {
    const tooth = 9.0;
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    var x = size.width;
    var down = true;
    while (x > 0) {
      x -= tooth;
      p.lineTo(math.max(x, 0), down ? size.height : size.height - tooth);
      down = !down;
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TornEdge oldClipper) => false;
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E3E7),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _CallSheet extends StatelessWidget {
  const _CallSheet({required this.name, required this.onCopy});

  final String name;
  final VoidCallback onCopy;

  /// Sample until companies have real numbers.
  static const _number = '+974 4400 1234';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Handle(),
          const SizedBox(height: 18),
          Text(
            'Call $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.call_rounded, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  _number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _number));
                onCopy();
              },
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Copy number'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick a new day and time for the booking.
class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.current});

  final DateTime current;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  static const _hours = [8, 10, 12, 14, 16, 18];
  late final DateTime _today = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  int _day = 1;
  int? _hour;

  DateTime get _picked =>
      DateTime(_today.year, _today.month, _today.day + _day, _hour ?? 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Handle(),
          const SizedBox(height: 18),
          const Text(
            'Pick a new time',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Now: ${_date(widget.current)} · ${_clock(widget.current)}',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _day = i);
                    },
                    child: Builder(
                      builder: (context) {
                        final d = _today.add(Duration(days: i));
                        final on = i == _day;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: on ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _weekdays[d.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: on ? Colors.white70 : _muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: on ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _hours)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _hour = h);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (MediaQuery.sizeOf(context).width - 48 - 16) / 3,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: h == _hour
                          ? AppColors.primary
                          : const Color(0xFFF7F8F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: h == _hour ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _hour == null
                  ? null
                  : () => Navigator.of(context).pop(_picked),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: const Color(0xFFB9D6FC),
                disabledForegroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                _hour == null
                    ? 'Pick a time'
                    : 'Move to ${_date(_picked)} · ${_clock(_picked)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final hours = booking.start.difference(DateTime.now()).inHours;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Handle(),
          const SizedBox(height: 22),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Transform.rotate(
              angle: -math.pi / 30,
              child: const Icon(
                Icons.event_busy_rounded,
                color: _danger,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cancel this booking?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hours >= 24
                ? '${booking.provider} will be told straight away.'
                : 'It\'s less than a day away, so ${booking.provider} may '
                      'already be getting ready.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: _danger,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancel booking'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Keep it'),
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
