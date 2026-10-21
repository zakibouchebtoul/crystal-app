import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/service_catalog.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/image_slot.dart';
import '../../widgets/rating_chip.dart';
import '../messages/messages_effects.dart' show StaggerIn;
import 'booking_sheet.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _soft = Color(0xFFB3BCC3);
const _card = Color(0xFFF7F8F9);

/// A company's page for one service: cover and logo, its services and
/// prices, options, date & time, before/after, how it works, its reviews,
/// FAQs and a sticky "Book" bar with the live total.
class CompanyServiceScreen extends StatefulWidget {
  const CompanyServiceScreen({
    super.key,
    required this.service,
    required this.offer,
    this.initialPackage,
    this.compare = false,
  });

  final ServiceDetail service;

  /// The chosen company and its services in this category.
  final CompanyOffer offer;

  /// Package to select first (by name); the most booked one otherwise.
  final String? initialPackage;

  /// Show which other companies offer the chosen package, to compare.
  final bool compare;

  static Route<void> route(ServiceDetail service, CompanyOffer offer) =>
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) =>
            CompanyServiceScreen(service: service, offer: offer),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  /// Opens the page by growing it out of a tapped card: the card's photo
  /// expands from [from] to full screen with its corners straightening,
  /// then dissolves into the page.
  static Route<void> routeFromCard(
    ServiceDetail service,
    CompanyOffer offer, {
    required String package,
    required Rect from,
    String? image,
  }) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => CompanyServiceScreen(
      service: service,
      offer: offer,
      initialPackage: package,
      compare: true,
    ),
    transitionsBuilder: (_, animation, _, child) => _CardExpand(
      animation: animation,
      from: from,
      image: image,
      child: child,
    ),
  );

  /// Opens a company's page with [package] chosen (also used to swap to
  /// another company's page for the same package).
  static Route<void> compareRoute(
    ServiceDetail service,
    CompanyOffer offer,
    String package, {
    bool compare = true,
  }) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, _, _) => CompanyServiceScreen(
      service: service,
      offer: offer,
      initialPackage: package,
      compare: compare,
    ),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<CompanyServiceScreen> createState() => _CompanyServiceScreenState();
}

/// Container transform for [CompanyServiceScreen.routeFromCard].
class _CardExpand extends StatelessWidget {
  const _CardExpand({
    required this.animation,
    required this.from,
    required this.image,
    required this.child,
  });

  final Animation<double> animation;
  final Rect from;
  final String? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value;
        final t = Curves.easeInOutCubic.transform(v);
        final rect = Rect.lerp(from, screen, t)!;
        final radius = 24 * (1 - t);
        // The card photo shows first, then hands over to the page.
        final photo = 1 - const Interval(0.45, 0.9).transform(v);
        return Stack(
          children: [
            // Home dims behind the growing card.
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.25 * t),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                clipper: _RectClipper(rect, radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    if (image != null && photo > 0)
                      Positioned.fromRect(
                        rect: rect,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: photo,
                            child: Image.asset(image!, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                  ],
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

class _RectClipper extends CustomClipper<RRect> {
  const _RectClipper(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RectClipper old) =>
      old.rect != rect || old.radius != radius;
}

class _CompanyServiceScreenState extends State<CompanyServiceScreen> {
  ServiceDetail get _s => widget.service;
  CompanyOffer get _offer => widget.offer;
  late final List<ServicePackage> _packages = _offer.packages;

  late int _package = math.max(
    0,
    widget.initialPackage != null
        ? _packages.indexWhere((p) => p.name == widget.initialPackage)
        : _packages.indexWhere((p) => p.mostBooked),
  );

  /// Selected choice index per ChoiceGroup.
  final _choices = <int, int>{};

  /// Count per CounterGroup.
  final _counts = <int, int>{};

  /// Selected add-ons per AddOnGroup.
  final _addOns = <int, Set<int>>{};

  int _day = 0;
  int? _slot;

  final _scroll = ScrollController();
  bool _favourite = false;

  void _toggleFavourite() {
    HapticFeedback.lightImpact();
    setState(() => _favourite = !_favourite);
  }

  static const _slots = [
    '8:00 AM',
    '10:00 AM',
    '12:00 PM',
    '2:00 PM',
    '4:00 PM',
    '6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    for (final (i, group) in _s.options.indexed) {
      switch (group) {
        case ChoiceGroup():
          _choices[i] = 0;
        case CounterGroup(:final initial):
          _counts[i] = initial;
        case AddOnGroup():
          _addOns[i] = {};
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Sample availability: a couple of slots taken each day.
  bool _slotTaken(int day, int slot) => (day * 3 + slot * 5) % 7 == 0;

  DateTime get _date {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + _day);
  }

  int get _total {
    var total = _packages[_package].price;
    for (final (i, group) in _s.options.indexed) {
      switch (group) {
        case ChoiceGroup(:final choices):
          total += choices[_choices[i]!].$2;
        case CounterGroup(:final included, :final pricePerExtra):
          total += math.max(0, _counts[i]! - included) * pricePerExtra;
        case AddOnGroup(:final addOns):
          for (final a in _addOns[i]!) {
            total += addOns[a].$2;
          }
      }
    }
    return total;
  }

  List<String> get _optionSummary => [
    for (final (i, group) in _s.options.indexed)
      switch (group) {
        ChoiceGroup(:final choices) => choices[_choices[i]!].$1,
        CounterGroup(:final unit) =>
          '${_counts[i]} $unit${_counts[i] == 1 ? '' : 's'}',
        AddOnGroup(:final addOns) =>
          _addOns[i]!.isEmpty
              ? ''
              : _addOns[i]!.map((a) => addOns[a].$1).join(', '),
      },
  ].where((s) => s.isNotEmpty).toList();

  void _tap(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
  }

  Future<void> _book() async {
    if (_slot == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pick a time for your booking')),
        );
      return;
    }
    await showBookingSheet(
      context,
      BookingSummary(
        service: _s,
        package: _packages[_package],
        options: _optionSummary,
        date: _date,
        time: _slots[_slot!],
        company: _offer.company,
        total: _total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var section = 0;
    // Staggered for the first screenful; capped so sections further down
    // are already there when you scroll to them.
    Widget enter(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: math.min(120 + 60 * section++, 300)),
      child: child,
    );

    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, child) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        final collapsed =
            offset >
            _Hero.coverHeight(context) - MediaQuery.paddingOf(context).top - 40;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: collapsed
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(
                    company: _offer.company,
                    scroll: _scroll,
                    favourite: _favourite,
                    onFavourite: _toggleFavourite,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    120 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      enter(_TitleBlock(service: _s, company: _offer.company)),
                      const SizedBox(height: 26),
                      enter(
                        _PackageCarousel(
                          service: _s,
                          company: _offer.company,
                          packages: _packages,
                          selected: _package,
                          onSelect: (i) => _tap(() => _package = i),
                        ),
                      ),
                      if (widget.compare)
                        _AlsoOffered(
                          service: _s,
                          offer: _offer,
                          package: _packages[_package].name,
                        ),
                      for (final (i, group) in _s.options.indexed) ...[
                        const SizedBox(height: 18),
                        enter(_SectionTitle(group.title)),
                        const SizedBox(height: 10),
                        enter(switch (group) {
                          ChoiceGroup(:final choices) => _Choices(
                            choices: choices,
                            selected: _choices[i]!,
                            onSelect: (c) => _tap(() => _choices[i] = c),
                          ),
                          CounterGroup() => _Counter(
                            group: group,
                            value: _counts[i]!,
                            onChanged: (v) => _tap(() => _counts[i] = v),
                          ),
                          AddOnGroup(:final addOns) => _AddOns(
                            addOns: addOns,
                            selected: _addOns[i]!,
                            onToggle: (a) => _tap(() {
                              final set = _addOns[i]!;
                              set.contains(a) ? set.remove(a) : set.add(a);
                            }),
                          ),
                        }),
                      ],
                      const SizedBox(height: 26),
                      enter(const _SectionTitle('Date & time')),
                      const SizedBox(height: 12),
                      enter(
                        _DateTimePicker(
                          day: _day,
                          slots: _slots,
                          slot: _slot,
                          taken: (s) => _slotTaken(_day, s),
                          onDay: (d) => _tap(() {
                            _day = d;
                            if (_slot != null && _slotTaken(d, _slot!)) {
                              _slot = null;
                            }
                          }),
                          onSlot: (s) => _tap(() => _slot = s),
                        ),
                      ),
                      const SizedBox(height: 26),
                      enter(const _SectionTitle('Before & after')),
                      const SizedBox(height: 12),
                      enter(_BeforeAfter(service: _s)),
                      const SizedBox(height: 26),
                      enter(const _HowItWorksButton()),
                      const SizedBox(height: 26),
                      enter(const _SectionTitle('Reviews')),
                      const SizedBox(height: 12),
                      enter(
                        _ReviewSummary(
                          rating: _offer.company.rating,
                          count: _offer.company.reviewCount,
                        ),
                      ),
                      for (final r in _offer.reviews) ...[
                        const Divider(height: 28, color: Color(0xFFF1F2F4)),
                        enter(_ReviewCard(review: r)),
                      ],
                      const SizedBox(height: 26),
                      const SizedBox(height: 16),
                      enter(const _SectionTitle('FAQs')),
                      const SizedBox(height: 6),
                      for (final (q, a) in _s.faqs)
                        enter(_Faq(question: q, answer: a)),
                    ],
                  ),
                ),
              ],
            ),
            // Appears once the cover has scrolled under the status bar.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  final start =
                      _Hero.coverHeight(context) -
                      MediaQuery.paddingOf(context).top -
                      70;
                  return _CollapsedBar(
                    company: _offer.company,
                    progress: ((offset - start) / 50).clamp(0.0, 1.0),
                    favourite: _favourite,
                    onFavourite: _toggleFavourite,
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BookBar(
                total: _total,
                ready: _slot != null,
                onBook: _book,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero

/// Cover from the very top of the screen (buttons float over it), with a
/// stretch-and-parallax on scroll and the logo overlapping its bottom edge.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.company,
    required this.scroll,
    required this.favourite,
    required this.onFavourite,
  });

  final Company company;
  final ScrollController scroll;
  final bool favourite;
  final VoidCallback onFavourite;

  /// Covers are 16:9 banners; the logo hangs 40 below.
  static double coverHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 9 / 16;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final cover = coverHeight(context);
    return SizedBox(
      height: cover + 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: cover,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              child: AnimatedBuilder(
                animation: scroll,
                builder: (context, child) {
                  final offset = scroll.hasClients ? scroll.offset : 0.0;
                  // Pull down: stretch. Scroll up: slower parallax + dim.
                  return Transform.translate(
                    offset: Offset(0, offset > 0 ? offset * 0.35 : 0),
                    child: Transform.scale(
                      scale: 1 + (offset < 0 ? -offset / 300 : 0),
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          child!,
                          ColoredBox(
                            color: Colors.black.withValues(
                              alpha: (offset / cover).clamp(0.0, 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageSlot(asset: company.cover, label: 'Company cover'),
                    // Darken under the status bar and buttons.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment(0, -0.2),
                          colors: [Color(0x88000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: top + 4,
            child: Row(
              children: [
                _GlassButton(
                  onTap: () => Navigator.of(context).pop(),
                  child: const ArrowIcon(color: Colors.white),
                ),
                const Spacer(),
                _GlassButton(
                  onTap: onFavourite,
                  child: _Heart(active: favourite, color: Colors.white),
                ),
              ],
            ),
          ),
          // Logo overlapping the cover's bottom edge; it pops in, then
          // shrinks away as the page scrolls.
          Positioned(
            left: 24,
            bottom: 0,
            child: AnimatedBuilder(
              animation: scroll,
              builder: (context, child) {
                final offset = scroll.hasClients ? scroll.offset : 0.0;
                final fade = (1 - offset / 120).clamp(0.0, 1.0);
                return Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * fade,
                    alignment: Alignment.bottomLeft,
                    child: child,
                  ),
                );
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: const Interval(0.25, 1, curve: Curves.elasticOut),
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: ImageSlot(
                      asset: company.logo,
                      label: 'Logo',
                      compact: true,
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

/// Heart that pops when toggled.
class _Heart extends StatelessWidget {
  const _Heart({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: active ? 0.5 : 1, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Icon(
        active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: active ? const Color(0xFFFF4D67) : color,
        size: 20,
      ),
    );
  }
}

/// Frosted bar that slides in at the top once the cover has scrolled
/// away: back, small logo, company name, heart.
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({
    required this.company,
    required this.progress,
    required this.favourite,
    required this.onFavourite,
  });

  final Company company;

  /// 0 = hidden, 1 = fully shown.
  final double progress;
  final bool favourite;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      ignoring: progress < 0.5,
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, -12 * (1 - progress)),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(24, top + 4, 24, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFF1F2F4)),
                  ),
                ),
                child: Row(
                  children: [
                    _PlainCircle(
                      onTap: () => Navigator.of(context).pop(),
                      child: const ArrowIcon(),
                    ),
                    const SizedBox(width: 10),
                    ClipOval(
                      child: SizedBox.square(
                        dimension: 30,
                        child: ImageSlot(
                          asset: company.logo,
                          label: '',
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                    _PlainCircle(
                      onTap: onFavourite,
                      child: _Heart(active: favourite, color: _ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlainCircle extends StatelessWidget {
  const _PlainCircle({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(dimension: 40, child: Center(child: child)),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(dimension: 44, child: Center(child: child)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.service, required this.company});

  final ServiceDetail service;
  final Company company;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                company.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            if (company.verified) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${service.title} · ${company.area} · ${company.distance}',
          style: const TextStyle(fontSize: 14, color: _muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RatingChip(
              rating: company.rating,
              reviews: company.reviewCount,
              compact: true,
            ),
            for (final tag in company.tags) _InfoTag(tag),
          ],
        ),
      ],
    );
  }
}

/// Small light-blue label, e.g. "Waterless".
class _InfoTag extends StatelessWidget {
  const _InfoTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
    );
  }
}

String _weekday(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

/// "Also at 2 other companies · from 67 QAR": other companies offering the
/// chosen package, with their logos stacked. Tapping opens a comparison.
class _AlsoOffered extends StatelessWidget {
  const _AlsoOffered({
    required this.service,
    required this.offer,
    required this.package,
  });

  final ServiceDetail service;
  final CompanyOffer offer;
  final String package;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final o in service.companies)
        if (o != offer && _priceOf(o, package) != null) o,
    ];
    final mine = _priceOf(offer, package);
    final cheapest = others.isEmpty
        ? null
        : others.map((o) => _priceOf(o, package)!).reduce(math.min);
    final saving = mine != null && cheapest != null ? mine - cheapest : 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: others.isEmpty
          ? const SizedBox(width: double.infinity)
          : StaggerIn(
              delay: const Duration(milliseconds: 650),
              builder: (t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - t)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Material(
                    key: ValueKey(package),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFF1F2F4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openCompare(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            _LogoStack(
                              companies: [for (final o in others) o.company],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Also at ${others.length} other '
                                    '${others.length == 1 ? 'company' : 'companies'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: 'from $cheapest QAR'),
                                        if (saving > 0)
                                          TextSpan(
                                            text: ' · save $saving QAR',
                                            style: const TextStyle(
                                              color: Color(0xFF1F9E44),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF5FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Compare',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _openCompare(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<CompanyOffer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          _CompareSheet(service: service, current: offer, package: package),
    );
    if (picked == null || picked == offer || !context.mounted) return;
    Navigator.of(context).pushReplacement(
      CompanyServiceScreen.compareRoute(service, picked, package),
    );
  }
}

/// Price of [package] at [offer], or null when it isn't offered there.
int? _priceOf(CompanyOffer offer, String package) {
  for (final p in offer.packages) {
    if (p.name == package) return p.price;
  }
  return null;
}

/// Overlapping round logos.
class _LogoStack extends StatelessWidget {
  const _LogoStack({required this.companies});

  final List<Company> companies;

  static const _size = 30.0;
  static const _step = 18.0;

  @override
  Widget build(BuildContext context) {
    final shown = companies.take(3).toList();
    return SizedBox(
      width: _size + _step * (shown.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (final (i, c) in shown.indexed)
            Positioned(
              left: i * _step,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: _Logo(company: c, size: _size),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A company's logo, or its initial while the logo is missing.
class _Logo extends StatelessWidget {
  const _Logo({required this.company, required this.size});

  final Company company;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      company.logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: const Color(0xFFEFF5FE),
        child: Text(
          company.name.characters.first,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Every company offering the package, cheapest first. The one being
/// viewed is marked; tapping another switches to its page.
class _CompareSheet extends StatelessWidget {
  const _CompareSheet({
    required this.service,
    required this.current,
    required this.package,
  });

  final ServiceDetail service;
  final CompanyOffer current;
  final String package;

  @override
  Widget build(BuildContext context) {
    final offers = [
      for (final o in service.companies)
        if (_priceOf(o, package) != null) o,
    ]..sort((a, b) => _priceOf(a, package)!.compareTo(_priceOf(b, package)!));
    final best = _priceOf(offers.first, package);
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E3E7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Compare companies',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(package, style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 14),
          for (final (i, o) in offers.indexed)
            StaggerIn(
              delay: Duration(milliseconds: 80 * i),
              builder: (t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(30 * (1 - t), 0),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CompareRow(
                  offer: o,
                  price: _priceOf(o, package)!,
                  viewing: o == current,
                  bestPrice: _priceOf(o, package) == best,
                  onTap: () => Navigator.of(context).pop(o),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.offer,
    required this.price,
    required this.viewing,
    required this.bestPrice,
    required this.onTap,
  });

  final CompanyOffer offer;
  final int price;
  final bool viewing;
  final bool bestPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = offer.company;
    return Material(
      color: viewing ? const Color(0xFFF5F9FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: viewing ? AppColors.primary : const Color(0xFFF1F2F4),
          width: viewing ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _Logo(company: c, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (c.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB020),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${c.rating} · ${c.distance}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$price',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const TextSpan(
                          text: ' QAR',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  if (viewing || bestPrice) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: viewing
                            ? const Color(0xFFEFF5FE)
                            : const Color(0xFFE8F8EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        viewing ? 'Viewing' : 'Best price',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: viewing
                              ? AppColors.primary
                              : const Color(0xFF1F9E44),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Services as a fanned card deck: the chosen card in front, neighbours
/// tilted behind it. Drag with a finger or use the arrows; cards spring
/// into place. What's included shows underneath.
class _PackageCarousel extends StatefulWidget {
  const _PackageCarousel({
    required this.service,
    required this.company,
    required this.packages,
    required this.selected,
    required this.onSelect,
  });

  final ServiceDetail service;
  final Company company;
  final List<ServicePackage> packages;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_PackageCarousel> createState() => _PackageCarouselState();
}

class _PackageCarouselState extends State<_PackageCarousel>
    with TickerProviderStateMixin {
  /// Deck position in cards (1.5 = halfway between card 1 and 2).
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.selected.toDouble(),
  );

  /// Deals the deck out on arrival: cards start stacked, then fan out.
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  double get _fan =>
      const Interval(0.3, 1, curve: Curves.easeOutBack).transform(_deal.value);

  static const _cardWidth = 262.0;
  static const _cardHeight = 350.0;
  static const _spread = 84.0;

  int get _last => widget.packages.length - 1;

  @override
  void dispose() {
    _pos.dispose();
    _deal.dispose();
    super.dispose();
  }

  void _settle(int target, {double velocity = 0}) {
    target = target.clamp(0, _last);
    _pos.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 220, damping: 24),
        _pos.value,
        target.toDouble(),
        velocity,
      ),
    );
    if (target != widget.selected) widget.onSelect(target);
  }

  void _step(int delta) => _settle(widget.selected + delta);

  @override
  Widget build(BuildContext context) {
    final packages = widget.packages;
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Services')),
            _ArrowButton(enabled: widget.selected > 0, onTap: () => _step(-1)),
            const SizedBox(width: 6),
            _ArrowButton(
              forward: true,
              enabled: widget.selected < _last,
              onTap: () => _step(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onHorizontalDragStart: (_) => _pos.stop(),
          onHorizontalDragUpdate: (d) => _pos.value =
              (_pos.value - d.delta.dx / _spread).clamp(-0.4, _last + 0.4),
          onHorizontalDragEnd: (d) {
            final v = -d.velocity.pixelsPerSecond.dx / _spread;
            _settle((_pos.value + v * 0.15).round(), velocity: v);
          },
          child: SizedBox(
            height: _cardHeight + 36,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pos, _deal]),
              builder: (context, _) {
                final p = _pos.value;
                // Farthest cards first so the front one paints on top.
                final order = [for (var i = 0; i < packages.length; i++) i]
                  ..sort((a, b) => (b - p).abs().compareTo((a - p).abs()));
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    for (final i in order)
                      if ((i - p).abs() < 2.2) _card(i, i - p),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _pos,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < packages.length; i++)
                Builder(
                  builder: (context) {
                    final f = (1 - (_pos.value - i).abs()).clamp(0.0, 1.0);
                    return Container(
                      width: 7 + 16 * f,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          const Color(0xFFD9E6F7),
                          AppColors.primary,
                          f,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // What the chosen service includes.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: _Includes(
            key: ValueKey(widget.selected),
            items: packages[widget.selected].includes,
          ),
        ),
      ],
    );
  }

  Widget _card(int i, double d) {
    final a = d.abs();
    final focus = (1 - a).clamp(0.0, 1.0);
    final package = widget.packages[i];
    final fan = _fan;
    return Transform.translate(
      offset: Offset(d * _spread * fan, 14 * a.clamp(0.0, 1.0) * fan),
      child: Transform.rotate(
        angle: d * 0.09 * fan,
        child: Transform.scale(
          scale: 1 - 0.12 * a.clamp(0.0, 1.5),
          child: Opacity(
            opacity: (1.6 - a * 0.6).clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () => _settle(i),
              child: _DeckCard(
                width: _cardWidth,
                height: _cardHeight,
                package: package,
                image: '${widget.service.id}_pkg_${i + 1}',
                companyImage: 'company_${widget.company.id}_pkg_${i + 1}',
                fallback: widget.company.cover,
                focus: focus,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A service card in the app's card style: photo inset on a white card,
/// name and price underneath.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.width,
    required this.height,
    required this.package,
    required this.image,
    required this.fallback,
    required this.companyImage,
    required this.focus,
  });

  final double width;
  final double height;
  final ServicePackage package;

  /// Image name (without folder/extension) for this service's photo.
  final String image;

  /// This company's own photo for the package, used first when added.
  final String companyImage;

  /// Shown until that photo is added.
  final String fallback;
  final double focus;

  @override
  Widget build(BuildContext context) {
    final p = package;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F2F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03 + 0.03 * focus),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The company's photo, else the service's, else the cover.
                  ImageSlot(
                    asset: 'assets/images/services/$companyImage.jpg',
                    label: '',
                    fallback: ImageSlot(
                      asset: 'assets/images/services/$image.jpg',
                      label: '',
                      fallback: Image.asset(
                        fallback,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.primary),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _FrostPill(
                      icon: Icons.schedule_rounded,
                      text: _duration(p.minutes),
                    ),
                  ),
                  if (p.mostBooked)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: _FrostPill(text: 'Most booked', tint: true),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.includes.length} things included',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${p.price}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const TextSpan(
                            text: ' QAR',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
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

class _FrostPill extends StatelessWidget {
  const _FrostPill({required this.text, this.icon, this.tint = false});

  final String text;
  final IconData? icon;

  /// Warm accent instead of frosted white (for "Most booked").
  final bool tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tint
                ? AppColors.accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                text,
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
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.enabled,
    required this.onTap,
    this.forward = false,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: enabled ? AppColors.primary : AppColors.fill,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 30,
            child: Center(
              child: ArrowIcon(
                size: 13,
                forward: forward,
                color: enabled ? Colors.white : _muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a service includes, as soft chips.
class _Includes extends StatelessWidget {
  const _Includes({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  item,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _duration(int minutes) => minutes < 60
    ? '$minutes min'
    : minutes % 60 == 0
    ? '${minutes ~/ 60} h'
    : '${minutes ~/ 60} h ${minutes % 60} min';

/// Pick one, as a segmented control: a white thumb slides behind the
/// chosen segment; price changes sit under each label.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, int)> choices;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final n = choices.length;
    final priced = choices.any((c) => c.$2 != 0);
    return Container(
      height: priced ? 60 : 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * selected / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F2F4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, (label, extra)) in choices.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: _Segment(
                      label: label,
                      extra: extra,
                      selected: i == selected,
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

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.extra,
    required this.selected,
  });

  final String label;
  final int extra;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: base.copyWith(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? _ink : _muted,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        ),
        if (extra != 0) ...[
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: base.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primary : _soft,
            ),
            child: Text('${extra > 0 ? '+' : ''}$extra QAR'),
          ),
        ],
      ],
    );
  }
}

/// Extras as rows in a white card; each toggles a round check.
class _AddOns extends StatelessWidget {
  const _AddOns({
    required this.addOns,
    required this.selected,
    required this.onToggle,
  });

  final List<(String, int)> addOns;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F2F4)),
      ),
      child: Column(
        children: [
          for (final (i, (label, price)) in addOns.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF1F2F4),
              ),
            _AddOnRow(
              label: label,
              price: price,
              selected: selected.contains(i),
              onTap: () => onToggle(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddOnRow extends StatelessWidget {
  const _AddOnRow({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '+$price QAR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.primary : _muted,
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFDDE1E5),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.group,
    required this.value,
    required this.onChanged,
  });

  final CounterGroup group;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final extra = group.pricePerExtra > 0
        ? '+${group.pricePerExtra} QAR per extra ${group.unit}'
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              extra ?? '${group.min}–${group.max} ${group.unit}s',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: value > group.min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: value < group.max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 38,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : const Color(0xFFD1D1D1),
          ),
        ),
      ),
    );
  }
}

/// One card: the next 7 days across the top, time slots underneath.
/// Full slots are greyed and crossed out.
class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({
    required this.day,
    required this.slots,
    required this.slot,
    required this.taken,
    required this.onDay,
    required this.onSlot,
  });

  final int day;
  final List<String> slots;
  final int? slot;
  final bool Function(int) taken;
  final ValueChanged<int> onDay;
  final ValueChanged<int> onSlot;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final chosen = DateTime(now.year, now.month, now.day + day);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F2F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '${_months[chosen.month - 1]} ${chosen.year}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    date: DateTime(now.year, now.month, now.day + i),
                    today: i == 0,
                    selected: i == day,
                    onTap: () => onDay(i),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F2F4)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final w = (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (i, label) in slots.indexed)
                    SizedBox(
                      width: w,
                      child: _TimeCell(
                        label: label.replaceAll(':00', ''),
                        selected: i == slot,
                        taken: taken(i),
                        onTap: () => onSlot(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              _weekday(date),
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white70 : _muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _ink,
              ),
            ),
            const SizedBox(height: 4),
            // Today's dot.
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !today
                    ? Colors.transparent
                    : selected
                    ? Colors.white
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: taken ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? Colors.white
                : taken
                ? _soft
                : _ink,
            decoration: taken ? TextDecoration.lineThrough : null,
            decorationColor: _soft,
          ),
        ),
      ),
    );
  }
}

class _BeforeAfter extends StatefulWidget {
  const _BeforeAfter({required this.service});

  final ServiceDetail service;

  @override
  State<_BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<_BeforeAfter> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: (d) => setState(
              () => _split = (_split + d.delta.dx / w).clamp(0.05, 0.95),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageSlot(
                    asset: widget.service.afterImage,
                    label: 'After photo',
                    placeholderAlignment: const Alignment(0.5, 0),
                  ),
                  ClipRect(
                    clipper: _LeftClip(_split),
                    child: ImageSlot(
                      asset: widget.service.beforeImage,
                      label: 'Before photo',
                      placeholderAlignment: const Alignment(-0.5, 0),
                    ),
                  ),
                  Positioned(
                    left: _split * w - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),
                  Positioned(
                    left: _split * w - 18,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.code_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(left: 10, top: 10, child: _Tag('Before')),
                  const Positioned(right: 10, top: 10, child: _Tag('After')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  const _LeftClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClip old) => old.fraction != fraction;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

/// A row that opens the "How it works" steps in a sheet.
class _HowItWorksButton extends StatelessWidget {
  const _HowItWorksButton();

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E3E7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'How it works',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            const _HowItWorks(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF1F2F4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Book, we come to you, pay after',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22, color: _soft),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three steps as a list in a white card, each icon joined to the
/// next by a short line.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.event_available_rounded,
      'Book',
      'Pick a package and a time that suits you',
    ),
    (
      Icons.home_repair_service_rounded,
      'Pro arrives',
      'A verified pro comes to your door',
    ),
    (
      Icons.payments_outlined,
      'Pay after',
      'Pay by card or cash once the job is done',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F2F4)),
      ),
      child: Column(
        children: [
          for (final (i, (icon, title, text)) in _steps.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF5FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 20, color: AppColors.primary),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3EDFB),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 2,
                        bottom: i < _steps.length - 1 ? 18 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '0${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _soft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Big score with stars on the left, how ratings split from 5 to 1 on
/// the right.
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.rating, required this.count});

  final double rating;
  final String count;

  /// Share of each star level, 5 → 1. Sample split until the backend
  /// sends real numbers; leans on 5 stars the higher the rating.
  List<double> get _split {
    final top = ((rating - 4) / 1).clamp(0.0, 1.0);
    return [0.55 + 0.35 * top, 0.3 - 0.2 * top, 0.1 - 0.06 * top, 0.03, 0.01];
  }

  @override
  Widget build(BuildContext context) {
    final split = _split;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              _Stars(rating: rating, size: 16),
              const SizedBox(height: 6),
              Text(
                '$count reviews',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (final (i, share) in split.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: share),
                          duration: Duration(milliseconds: 700 + 80 * i),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              color: AppColors.primary,
                              backgroundColor: const Color(0xFFF1F2F4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${5 - i}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFFFB020),
          ),
      ],
    );
  }
}

/// One review: avatar initials, name and when, stars, the text, and a
/// helpful count you can tap.
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review});

  final ServiceReview review;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final initials = r.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    final likes = r.likes + (_liked ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFF5FE),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.when,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz_rounded, size: 20, color: _soft),
          ],
        ),
        const SizedBox(height: 10),
        _Stars(rating: r.rating, size: 18),
        const SizedBox(height: 8),
        Text(
          r.text,
          style: const TextStyle(fontSize: 13, height: 1.45, color: _muted),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _liked = !_liked);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(_liked),
                  size: 18,
                  color: _liked ? AppColors.badge : _muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                likes > 0 ? '$likes' : 'Helpful',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Faq extends StatefulWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _muted,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.answer,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _muted,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky book bar

class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.total,
    required this.ready,
    required this.onBook,
  });

  final int total;
  final bool ready;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12, color: _soft)),
              // The total counts to its new value when options change.
              TweenAnimationBuilder<double>(
                tween: Tween(end: total.toDouble()),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  '${v.round()} QAR',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: ready
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.55),
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(ready ? 'Book · $total QAR' : 'Pick a time'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
