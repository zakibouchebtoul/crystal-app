import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../core/app_colors.dart';
import '../../data/home_content.dart';
import '../../data/service_catalog.dart';
import '../../widgets/crystal_logo.dart';
import '../../widgets/rating_chip.dart';
import '../../widgets/search_icon.dart';
import '../../data/addresses.dart';
import '../../data/bookings.dart';
import '../../data/favourites.dart';
import '../address/address_sheet.dart';
import '../offers/offers_screen.dart';
import '../popular/popular_screen.dart';
import '../search/search_screen.dart';
import '../service/companies_screen.dart';
import 'home_extras.dart';
import '../service/company_screen.dart';
import '../../widgets/entrance.dart';

/// Home tab: logo, address and search, promo carousel, service grid and
/// the "Most Booked Services" row.
///
/// On first display everything assembles itself in a cascade (see the
/// [Stage]s in each section); while scrolling, the logo drifts away and
/// the banner image shifts slightly for depth.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.active = true,
    this.onOpenProfile,
    this.onOpenCalendar,
  });

  /// Whether the tab is on screen; the entrance replays each time it
  /// becomes so.
  final bool active;

  /// Switch to the profile tab.
  final VoidCallback? onOpenProfile;

  /// Switch to the calendar, focused on a booking.
  final ValueChanged<Booking>? onOpenCalendar;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  static const _padding = 24.0;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  final _scroll = ScrollController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.active) return;
    _started = true;
    _playEntrance();
  }

  @override
  void didUpdateWidget(HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _playEntrance();
  }

  void _playEntrance() {
    // Respect the system "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntranceScope(
      animation: _entrance,
      scroll: _scroll,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          // Bounces everywhere so the page can be pulled to refresh.
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              refreshTriggerPullDistance: 90,
              refreshIndicatorExtent: 56,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                // TODO: reload bookings and offers from the backend.
                await Future<void>.delayed(const Duration(milliseconds: 1200));
                bookingStore.refresh();
              },
              builder: (context, mode, pulled, trigger, extent) => Center(
                child: DiamondRefresh(
                  pulled: pulled / trigger,
                  refreshing:
                      mode == RefreshIndicatorMode.refresh ||
                      mode == RefreshIndicatorMode.armed,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScrollAway(
                      child: Center(
                        child: Stage(
                          from: 0,
                          to: 0.4,
                          curve: Curves.linear,
                          builder: (context, t, _) =>
                              CrystalLogo(width: 80, reveal: t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _padding),
                      child: _Address(onAvatar: widget.onOpenProfile),
                    ),
                  ],
                ),
              ),
            ),
            // Scrolls up with the page, then sticks to the top while the
            // rest of the content passes underneath.
            const SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedSearchDelegate(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                // Leave room for the bottom bar, which floats over the
                // content.
                padding: EdgeInsets.only(
                  top: 4,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stage(
                      from: 0.3,
                      to: 0.6,
                      builder: (context, t, child) => fadeSlide(t, child),
                      child: UpcomingBookingCard(
                        onOpen: widget.onOpenCalendar ?? (_) {},
                        // The notification pill says it all.
                        header: (colors, dots) => _SectionHeader(
                          title: '',
                          decor: false,
                          badge: colors,
                          trailing: Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: dots,
                          ),
                        ),
                      ),
                    ),
                    const _PromoCarousel(),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: _padding),
                      child: _ServiceGrid(),
                    ),
                    const SizedBox(height: 16),
                    Stage(
                      from: 0.62,
                      to: 0.9,
                      builder: (context, t, child) => fadeSlide(t, child),
                      child: const WeatherTipCard(),
                    ),
                    const BookAgainRow(
                      header: _SectionHeader(title: 'Book again'),
                    ),
                    const RateLastCard(),
                    const FavouritesRow(
                      header: _SectionHeader(title: 'Your favourites'),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Most Booked Services',
                      onSeeAll: () =>
                          Navigator.of(context).push(PopularScreen.route()),
                    ),
                    const SizedBox(height: 12),
                    const _MostBookedList(),
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

/// The search field as a pinned header. Once it reaches the top it stays
/// there on a frosted backing (with a soft shadow) so content scrolling
/// underneath stays readable.
class _PinnedSearchDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedSearchDelegate();

  static const _top = 6.0;
  static const _bottom = 10.0;

  @override
  double get minExtent => _top + _SearchField.height + _bottom;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: overlapsContent ? 1 : 0),
      duration: const Duration(milliseconds: 200),
      builder: (context, pinned, child) => DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05 * pinned),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: pinned < 0.01
            ? ColoredBox(color: Colors.white, child: child)
            : ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 16 * pinned,
                    sigmaY: 16 * pinned,
                  ),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 1 - 0.12 * pinned),
                    child: child,
                  ),
                ),
              ),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(24, _top, 24, _bottom),
        child: _SearchField(),
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedSearchDelegate oldDelegate) => false;
}

/// Moves [child] up at half the scroll speed and fades it out, so the logo
/// drifts away behind the content.
class _ScrollAway extends StatelessWidget {
  const _ScrollAway({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scroll = EntranceScope.of(context).scroll;
    return AnimatedBuilder(
      animation: scroll,
      child: child,
      builder: (context, child) {
        final offset = scroll.hasClients
            ? scroll.offset.clamp(0.0, 200.0)
            : 0.0;
        return Opacity(
          opacity: (1 - offset / 120).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset * 0.5),
            child: Transform.scale(scale: 1 - offset / 1000, child: child),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Address and search

class _Address extends StatelessWidget {
  const _Address({this.onAvatar});

  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Address" label slides in from the left.
                    Stage(
                      from: 0.12,
                      to: 0.38,
                      builder: (context, t, child) =>
                          fadeSlide(t, child, offset: const Offset(-24, 0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Address',
                          style: TextStyle(fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Address wipes in from the left.
                    Stage(
                      from: 0.18,
                      to: 0.46,
                      builder: (context, t, child) =>
                          _Wipe(progress: t, child: child!),
                      child: _PressFade(
                        onTap: () => showAddressSheet(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              // Follows the address picked in the sheet;
                              // the new one slides in.
                              child: ListenableBuilder(
                                listenable: addressBook,
                                builder: (context, _) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [...previous, ?current],
                                  ),
                                  transitionBuilder: (child, a) =>
                                      FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(
                                            begin: const Offset(0, 0.5),
                                            end: Offset.zero,
                                          ).animate(a),
                                          child: child,
                                        ),
                                      ),
                                  child: Text(
                                    addressBook.selected.full,
                                    key: ValueKey(addressBook.selected.id),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 26,
                              color: AppColors.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            _Avatar(onTap: onAvatar),
          ],
        ),
      ],
    );
  }
}

/// Profile photo that pops in with a ring of light around it.
class _Avatar extends StatelessWidget {
  const _Avatar({this.onTap});

  /// Opens the profile.
  final VoidCallback? onTap;

  static const _radius = 22.0;

  @override
  Widget build(BuildContext context) {
    return _PressFade(onTap: onTap ?? () {}, child: _photo());
  }

  Widget _photo() {
    return SizedBox.square(
      dimension: _radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Stage(
            from: 0.32,
            to: 0.75,
            builder: (context, t, _) => t <= 0 || t >= 1
                ? const SizedBox.shrink()
                : CustomPaint(
                    size: const Size.square(_radius * 2),
                    painter: _RingPainter(
                      radius: _radius + 16 * t,
                      opacity: 0.6 * (1 - t),
                    ),
                  ),
          ),
          Stage(
            from: 0.22,
            to: 0.62,
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: math.max(t, 0), child: child),
            child: const CircleAvatar(
              radius: _radius,
              backgroundImage: AssetImage('assets/images/home/avatar.jpg'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.radius, required this.opacity});

  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.radius != radius || old.opacity != opacity;
}

/// Search box: stretches open from the center, then its icon and hint
/// slide in.
class _SearchField extends StatelessWidget {
  const _SearchField();

  static const height = 48.0;

  static const _hintColor = Color(0xFFB3BCC3);

  @override
  Widget build(BuildContext context) {
    return Stage(
      from: 0.28,
      to: 0.54,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(0.3 + 0.7 * t, 1, 1),
          child: child,
        ),
      ),
      // Opens the search page; the box flies up into its header.
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(SearchScreen.route()),
        child: Hero(
          tag: searchHeroTag,
          child: Material(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stage(
                from: 0.44,
                to: 0.64,
                builder: (context, t, child) =>
                    fadeSlide(t, child, offset: const Offset(-12, 0)),
                child: const Row(
                  children: [
                    SearchIcon(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search services, packages, companies',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: _hintColor),
                      ),
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

/// Reveals [child] from left to right with a soft edge.
class _Wipe extends StatelessWidget {
  const _Wipe({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    final edge = -0.15 + 1.3 * progress;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [
          Colors.white,
          Colors.white,
          Colors.transparent,
          Colors.transparent,
        ],
        stops: [0, edge.clamp(0.0, 1.0), (edge + 0.15).clamp(0.0, 1.0), 1],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Fades [child] while pressed (iOS-style), instead of a Material ink
/// highlight.
class _PressFade extends StatefulWidget {
  const _PressFade({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressFade> createState() => _PressFadeState();
}

class _PressFadeState extends State<_PressFade> {
  bool _pressed = false;

  void _set(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.45 : 1,
        duration: Duration(milliseconds: _pressed ? 60 : 180),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promo carousel

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

/// Endless carousel: pages are numbered without limit and map onto the
/// banners with `% count`, so after the last banner it simply moves on to
/// the first one (in auto-play and when swiping).
class _PromoCarouselState extends State<_PromoCarousel> {
  static int get _count => promoBanners.length;

  // Start far from 0 so it can also be swiped backwards from the first.
  late final _controller = PageController(
    initialPage: _count > 1 ? _count * 1000 : 0,
  );
  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  /// (Re)starts the 4-second timer; called again whenever the user swipes,
  /// so a banner never changes right after a manual swipe.
  void _startAutoPlay() {
    _autoPlay?.cancel();
    if (_count < 2) return;
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || !_controller.position.haveDimensions) {
        return;
      }
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// Current position in banners (0 ≤ value < count), fractional while
  /// moving.
  double get _position {
    final page = _controller.hasClients && _controller.position.haveDimensions
        ? _controller.page!
        : _controller.initialPage.toDouble();
    return _count == 0 ? 0 : page % _count;
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Makes a banner open its offer; the banner flies into the offers page.
  Widget _bannerLink(PromoBanner banner, Widget child) {
    final id = banner.offerId;
    if (id == null) return child;
    return GestureDetector(
      onTap: () {
        _autoPlay?.cancel();
        Navigator.of(
          context,
        ).push(OffersScreen.route(focusId: id)).then((_) => _startAutoPlay());
      },
      child: Hero(tag: offerHeroTag(id), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scroll = EntranceScope.of(context).scroll;
    return Column(
      children: [
        // Banner tilts up into place in 3D, then a gloss sweeps across it.
        Stage(
          from: 0.32,
          to: 0.7,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..translateByDouble(0, 36 * (1 - t), 0, 1)
                ..rotateX(0.6 * (1 - t))
                ..scaleByDouble(0.92 + 0.08 * t, 0.92 + 0.08 * t, 1, 1),
              child: child,
            ),
          ),
          child: AspectRatio(
            // Banners are 2:1 (354 × 177 on a 402-wide phone, after the
            // side padding).
            aspectRatio: 402 / 177,
            child: Stack(
              children: [
                NotificationListener<ScrollStartNotification>(
                  onNotification: (n) {
                    if (n.dragDetails != null) _startAutoPlay();
                    return false;
                  },
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _count > 1 ? null : _count,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _bannerLink(
                        promoBanners[index % _count],
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          // Slight parallax: the image shifts as the page
                          // scrolls.
                          child: AnimatedBuilder(
                            animation: scroll,
                            builder: (context, child) {
                              final offset = scroll.hasClients
                                  ? scroll.offset.clamp(0.0, 300.0)
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(0, offset * 0.02),
                                child: Transform.scale(
                                  scale: 1.04,
                                  child: child,
                                ),
                              );
                            },
                            child: Image.asset(
                              promoBanners[index % _count].image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Stage(
                          from: 0.66,
                          to: 0.92,
                          curve: Curves.easeInOut,
                          builder: (context, t, _) =>
                              CustomPaint(painter: _GlossPainter(t)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (promoBanners.length > 1) ...[
          const SizedBox(height: 8),
          // Track grows out from the center.
          Stage(
            from: 0.6,
            to: 0.82,
            builder: (context, t, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(t, 1, 1),
              child: child,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: const Size(176, 2),
                painter: _StepperPainter(count: _count, page: _position),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A diagonal band of light that crosses the banner once.
class _GlossPainter extends CustomPainter {
  const _GlossPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = -0.3 + 1.6 * progress;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ],
          stops: [
            (center - 0.12).clamp(0.0, 1.0),
            center.clamp(0.0, 1.0),
            (center + 0.12).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlossPainter old) => old.progress != progress;
}

/// Slim progress track under the carousel: a light line split into steps by
/// slightly darker joints, with a blue step that glides with the swipe.
class _StepperPainter extends CustomPainter {
  _StepperPainter({required this.count, required this.page});

  final int count;

  /// Current position in banners (0 ≤ page < count, e.g. 1.5 while
  /// swiping).
  final double page;

  static const _track = Color(0xFFE4F0FC);
  static const _joint = Color(0xFFD2E4F6);
  static const _jointWidth = 8.5;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final step = size.width / count;
    RRect pill(double left, double width) => RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, width, size.height),
      radius,
    );

    canvas.drawRRect(pill(0, size.width), Paint()..color = _track);
    final joint = Paint()..color = _joint;
    for (var i = 1; i < count; i++) {
      canvas.drawRRect(pill(step * i - _jointWidth / 2, _jointWidth), joint);
    }
    // The blue step; moving from the last banner to the first it slides
    // off the end and back in at the start.
    canvas
      ..save()
      ..clipRRect(pill(0, size.width));
    final active = Paint()..color = AppColors.primary;
    canvas.drawRRect(pill(step * page, step), active);
    if (page > count - 1) {
      canvas.drawRRect(pill(step * (page - count), step), active);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StepperPainter old) =>
      old.page != page || old.count != count;
}

// ---------------------------------------------------------------------------
// Service grid

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid();

  static const _columns = 4;
  static const _gap = 8.0;
  static const _labelSize = 14.0;

  /// One font size for every label: 14, or smaller if the longest label
  /// wouldn't fit its column (labels may use half the gap on each side).
  double _labelFontSize(BuildContext context, double maxWidth) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(const TextStyle(fontSize: _labelSize));
    var widest = 0.0;
    for (final service in serviceCategories) {
      final painter = TextPainter(
        text: TextSpan(text: service.name, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest <= maxWidth ? _labelSize : _labelSize * maxWidth / widest;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        final labelSize = _labelFontSize(context, tileWidth + _gap);
        return Wrap(
          spacing: _gap,
          runSpacing: 14,
          children: [
            for (final (i, service) in serviceCategories.indexed)
              SizedBox(
                width: tileWidth,
                child: _ServiceTile(
                  service: service,
                  labelSize: labelSize,
                  // Diagonal wave: tiles further right and down start later.
                  delay: (i ~/ _columns + i % _columns) * 0.045,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceTile extends StatefulWidget {
  const _ServiceTile({
    required this.service,
    required this.labelSize,
    required this.delay,
  });

  final ServiceCategory service;

  /// Shared by all tiles so every label is the same size.
  final double labelSize;

  /// Extra entrance delay (fraction of the timeline) for the wave.
  final double delay;

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final start = 0.42 + widget.delay;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        final detail = serviceCatalog[service.name];
        if (detail != null) {
          Navigator.of(context).push(CompaniesScreen.route(detail));
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Tile pops in with a little twist.
                Stage(
                  from: start,
                  to: start + 0.26,
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: -0.12 * (1 - t),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * t,
                        child: child,
                      ),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 83 / 79,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(service.image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                if (service.badge case final badge?)
                  Positioned(
                    top: -10,
                    left: -4,
                    right: -3,
                    child: _SwingIn(child: _Badge(label: badge)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Stage(
              from: start + 0.1,
              to: math.min(start + 0.3, 1),
              builder: (context, t, child) => fadeSlide(t, child),
              // Allowed to spill into the gaps between tiles.
              child: OverflowBox(
                maxWidth: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                child: Text(
                  service.name,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: widget.labelSize,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drops [child] in and lets it swing to rest like a hanging sign.
class _SwingIn extends StatelessWidget {
  const _SwingIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stage(
      from: 0.78,
      to: 1,
      curve: Curves.linear,
      child: child,
      builder: (context, t, child) {
        final drop = Curves.easeOutCubic.transform(math.min(1, t * 3));
        final swing = 0.35 * math.exp(-4 * t) * math.cos(16 * t);
        return Opacity(
          opacity: math.min(1, t * 4),
          child: Transform.translate(
            offset: Offset(0, -14 * (1 - drop)),
            child: Transform.rotate(
              angle: t >= 1 ? 0 : swing,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Small red tag, e.g. "School Offers" or "🔥 Most booked".
/// Orange "Most booked" pill on a photo: same shape as [RatingChip],
/// with a white flame.
class _HotChip extends StatelessWidget {
  const _HotChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(7, 0, 10, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA52E), AppColors.accentDeep],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            // Even line spacing so the text sits centred beside the icon.
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA52E), AppColors.accentDeep],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        widthFactor: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
// Most booked

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    /// Empty for none (e.g. when the badge says it all).
    required this.title,
    this.onSeeAll,
    this.badge,
    this.trailing,
    this.decor = true,
  });

  final String title;

  /// The faint house with the blue ring on the left.
  final bool decor;

  /// Count next to the title, one colour per item.
  final List<Color>? badge;

  /// Shown on the right (e.g. position dots).
  final Widget? trailing;

  /// Shows a "See all" button when set.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Without the decoration, lines up with the content below.
      padding: EdgeInsets.only(left: decor ? 3 : 24, right: 17),
      child: Row(
        children: [
          // A faint house drawing, cut off by the screen edge, whose round
          // window is the blue ring (drawn on top so it can animate).
          if (decor) ...[
            SizedBox(
              width: 19,
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    // The ring sits 3 × 30 pt into the house image.
                    left: -3,
                    top: -30,
                    width: 65,
                    height: 104,
                    child: Stage(
                      from: 0.6,
                      to: 0.85,
                      builder: (context, t, child) =>
                          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                      child: Image.asset(
                        'assets/images/decor/house_edge.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  // The ring sweeps into view around its center.
                  Stage(
                    from: 0.66,
                    to: 0.86,
                    curve: Curves.easeInOutCubic,
                    builder: (context, t, child) => t >= 1
                        ? child!
                        : ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (rect) => SweepGradient(
                              startAngle: 0,
                              endAngle: 2 * math.pi,
                              transform: const GradientRotation(-math.pi / 2),
                              colors: const [Colors.white, Colors.transparent],
                              stops: [t, t],
                            ).createShader(rect),
                            child: child,
                          ),
                    child: Image.asset(
                      'assets/images/decor/section_ring.png',
                      width: 19,
                      height: 14,
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Stage(
              from: 0.68,
              to: 0.88,
              builder: (context, t, child) =>
                  fadeSlide(t, child, offset: const Offset(-16, 0)),
              child: Row(
                children: [
                  if (title.isNotEmpty)
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  if (badge case final badge?) ...[
                    if (title.isNotEmpty) const SizedBox(width: 8),
                    _CountBadge(colors: badge),
                  ],
                ],
              ),
            ),
          ),
          ?trailing,
          if (onSeeAll != null)
            Stage(
              from: 0.74,
              to: 0.94,
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
              ),
              child: Material(
                color: AppColors.surface.withValues(alpha: 0.3),
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: onSeeAll,
                  customBorder: const StadiumBorder(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Text(
                      'See all',
                      style: TextStyle(fontSize: 13, color: Color(0xFF0D0D12)),
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

class _MostBookedList extends StatelessWidget {
  const _MostBookedList();

  @override
  Widget build(BuildContext context) {
    // Image + gap + up to two lines of title, following the text size
    // setting.
    final titleLine = MediaQuery.textScalerOf(context).scale(13) * 1.4;
    return SizedBox(
      height: _FeaturedCardState._imageHeight + 8 + titleLine * 2 + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: mostBookedServices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Cards glide in from the right, one after another.
          final start = math.min(0.7 + index * 0.07, 0.85);
          return Stage(
            from: start,
            to: math.min(start + 0.25, 1),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(90 * (1 - t), 0),
                child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
              ),
            ),
            child: _FeaturedCard(
              service: mostBookedServices[index],
              chipsFrom: math.min(start + 0.14, 0.9),
            ),
          );
        },
      ),
    );
  }
}

/// Companies offering a featured service's package, best rated first.
List<CompanyOffer> _offersFor(FeaturedService f) {
  final detail = serviceCatalog[f.category];
  if (detail == null || f.package == null) return const [];
  return [
    for (final o in detail.companies)
      if (o.packages.any((p) => p.name == f.package)) o,
  ]..sort((a, b) => b.company.rating.compareTo(a.company.rating));
}

/// Lowest price for a featured service across companies.
int? _priceFrom(FeaturedService f) {
  final prices = [
    for (final o in _offersFor(f))
      for (final p in o.packages)
        if (p.name == f.package) p.price,
  ];
  return prices.isEmpty ? f.priceFrom : prices.reduce(math.min);
}

class _FeaturedCard extends StatefulWidget {
  const _FeaturedCard({required this.service, required this.chipsFrom});

  final FeaturedService service;

  /// When the chips on the photo pop in (fraction of the timeline).
  final double chipsFrom;

  @override
  State<_FeaturedCard> createState() => _FeaturedCardState();
}

/// Presses in slightly, then grows into the top company's page with the
/// package already chosen.
class _FeaturedCardState extends State<_FeaturedCard> {
  final _photo = GlobalKey();
  bool _pressed = false;

  FeaturedService get service => widget.service;

  /// What the heart saves (null when the card isn't linked to a package).
  Favourite? get _favourite {
    final s = serviceCatalog[service.category];
    final p = service.package;
    return s == null || p == null ? null : (serviceId: s.id, package: p);
  }

  double get chipsFrom => widget.chipsFrom;

  void _open() {
    final detail = serviceCatalog[service.category];
    if (detail == null) return;
    final offers = _offersFor(service);
    if (offers.isEmpty) {
      Navigator.of(context).push(CompaniesScreen.route(detail));
      return;
    }
    final box = _photo.currentContext!.findRenderObject()! as RenderBox;
    final from = box.localToGlobal(Offset.zero) & box.size;
    Navigator.of(context).push(
      CompanyServiceScreen.routeFromCard(
        detail,
        offers.first,
        package: service.package!,
        from: from,
        image: service.image,
      ),
    );
  }

  static const _width = 276.0;
  static const _imageHeight = 147.0;

  /// Pops [child] in from nothing.
  Widget _pop(Widget child, {double delay = 0}) => Stage(
    from: chipsFrom + delay,
    to: math.min(chipsFrom + delay + 0.1, 1),
    curve: Curves.easeOutBack,
    builder: (context, t, child) =>
        Transform.scale(scale: math.max(t, 0), child: child),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final price = _priceFrom(service);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: _content(price),
      ),
    );
  }

  Widget _content(int? price) {
    return SizedBox(
      width: _width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: _photo,
            height: _imageHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: service.image != null
                        ? Image.asset(service.image!, fit: BoxFit.cover)
                        : const _ImagePlaceholder(),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _pop(
                    RatingChip(
                      rating: service.rating,
                      reviews: service.reviews,
                    ),
                  ),
                ),
                if (service.duration case final duration?)
                  Positioned.fill(
                    child: Center(
                      child: _pop(
                        delay: 0.03,
                        _GlassPill(
                          child: Text(
                            duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Inside the photo, level with the rating chip and the
                // same size, so the two read as a pair.
                if (service.badge case final badge?)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _pop(delay: 0.05, _HotChip(label: badge)),
                  ),
                if (_favourite case final fav?)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _pop(delay: 0.08, FavouriteHeart(favourite: fav)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  ),
                ),
                if (price != null)
                  // "from" quiet, the price stands out.
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'from '),
                        TextSpan(
                          text: '$price QAR',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.iconMuted,
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

/// Frosted-glass pill: blurs the photo behind it, with a translucent blue
/// tint, a light sheen at the top and a thin bright edge.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.55),
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Shown while a service has no photo yet.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.fill,
      child: Center(
        child: Icon(
          Icons.cleaning_services_outlined,
          color: AppColors.placeholder,
          size: 40,
        ),
      ),
    );
  }
}

/// Live count next to a section title, as a notification pill: a bell
/// sitting on the left edge of a soft blue pill that reads "You have 3
/// coming up". On arrival the bell pops in, the pill slides open behind
/// it, the number rolls up and the bell rings — swinging from its top
/// with the clapper lagging behind. It rings again every few seconds (the
/// glow brightening as it does) and when tapped.
class _CountBadge extends StatefulWidget {
  const _CountBadge({required this.colors});

  /// One per item (only the count is shown).
  final List<Color> colors;

  @override
  State<_CountBadge> createState() => _CountBadgeState();
}

class _CountBadgeState extends State<_CountBadge>
    with TickerProviderStateMixin {
  /// Arrival: waits for the section title (home's entrance), then bell,
  /// pill, number.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900),
  )..forward();

  /// One cycle: a ring in the first 1.3 s, then quiet.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  static const _ringSeconds = 1.3;

  int get _count => widget.colors.length;

  @override
  void initState() {
    super.initState();
    // Starts ringing once it has arrived.
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _cycle.repeat();
    });
  }

  @override
  void didUpdateWidget(_CountBadge old) {
    super.didUpdateWidget(old);
    if (old.colors.length != widget.colors.length) _ring();
  }

  void _ring() {
    if (!_intro.isCompleted) return;
    _cycle.value = 0;
    _cycle.repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _cycle.dispose();
    super.dispose();
  }

  double _phase(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));

  /// Bell swing [seconds] into a ring: a damped back-and-forth.
  static double _swing(double seconds) {
    if (seconds <= 0 || seconds >= _ringSeconds) return 0;
    return 0.5 *
        math.exp(-3.2 * seconds) *
        math.sin(seconds * 2 * math.pi * 3.2);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _ring();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _cycle]),
        builder: (context, _) {
          final pop = _phase(0.6, 0.72, Curves.elasticOut);
          final open = _phase(0.66, 0.84, Curves.easeOutCubic);
          final roll = _phase(0.72, 0.95, Curves.easeOutCubic);
          final shown = (_count * roll).round();
          final seconds = _intro.isCompleted
              ? _cycle.value * 5.2
              // The first ring overlaps the end of the arrival.
              : (_intro.value - 0.78) * 2.9;
          final bell = _swing(seconds);
          final clapper = _swing(seconds - 0.07) * 1.6;
          final energy = seconds > 0 && seconds < _ringSeconds
              ? math.exp(-2.5 * seconds)
              : 0.0;
          return SizedBox(
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Glow around the pill, brighter while ringing.
                Positioned(
                  left: 6,
                  top: 2,
                  bottom: 2,
                  right: 0,
                  child: Opacity(
                    opacity: open,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withValues(
                              alpha: 0.14 + 0.22 * energy,
                            ),
                            blurRadius: 10 + 8 * energy,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // The pill slides open from behind the bell.
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.12 + 0.88 * open,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.fromLTRB(23, 0, 12, 0),
                        // Same as the "School Offers" badge.
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFA52E), AppColors.accentDeep],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: open,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('You have ', style: _pillText),
                              _Rolling(value: _count, shown: shown),
                              const Text(' coming up', style: _pillText),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The bell, a little bigger than the pill, swinging from
                // its top.
                Positioned(
                  left: 0,
                  child: Transform.scale(
                    scale: pop,
                    child: Transform.rotate(
                      angle: -0.18 + bell,
                      alignment: const Alignment(0, -0.85),
                      child: SizedBox.square(
                        dimension: 24,
                        child: CustomPaint(
                          painter: _BellPainter(clapper: clapper - bell),
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
  }
}

const _orange = AppColors.accent;
const _orangeDeep = AppColors.accentDeep;

const _pillText = TextStyle(
  fontSize: 12,
  height: 1,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

/// A small shaded bell: lit from the left, darker on the right, with a
/// knob on top and a clapper hanging below that swings on its own.
class _BellPainter extends CustomPainter {
  const _BellPainter({required this.clapper});

  /// Clapper angle relative to the bell.
  final double clapper;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.2, h * 0.72)
      ..cubicTo(w * 0.2, h * 0.3, w * 0.32, h * 0.16, w * 0.5, h * 0.16)
      ..cubicTo(w * 0.68, h * 0.16, w * 0.8, h * 0.3, w * 0.8, h * 0.72)
      ..quadraticBezierTo(w * 0.9, h * 0.76, w * 0.92, h * 0.82)
      ..lineTo(w * 0.08, h * 0.82)
      ..quadraticBezierTo(w * 0.1, h * 0.76, w * 0.2, h * 0.72)
      ..close();

    // Clapper first, so the bell's lip covers its top.
    final pivot = Offset(w * 0.5, h * 0.7);
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(clapper)
      ..drawCircle(Offset(0, h * 0.18), w * 0.1, Paint()..color = _orangeDeep)
      ..drawCircle(
        Offset(-w * 0.02, h * 0.16),
        w * 0.045,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      )
      ..restore();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFC77D), _orange, _orangeDeep],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );
    // Soft highlight down the lit side.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.3, h * 0.68)
        ..cubicTo(w * 0.3, h * 0.36, w * 0.36, h * 0.24, w * 0.46, h * 0.22)
        ..cubicTo(w * 0.4, h * 0.3, w * 0.37, h * 0.42, w * 0.37, h * 0.68)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Rim along the lip.
    canvas.drawLine(
      Offset(w * 0.1, h * 0.82),
      Offset(w * 0.9, h * 0.82),
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = _orangeDeep,
    );
    // Knob on top.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.12),
      w * 0.07,
      Paint()..color = _orange,
    );
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.clapper != clapper;
}

/// The count, rolling like a counter: each new number slides up from
/// below while the old one leaves at the top.
class _Rolling extends StatelessWidget {
  const _Rolling({required this.value, required this.shown});

  /// Final value (sets the width so the tag doesn't jitter).
  final int value;
  final int shown;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      height: 1,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return ClipRect(
      child: SizedBox(
        height: 14,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, a) {
            final incoming = child.key == ValueKey(shown);
            return SlideTransition(
              position: Tween(
                begin: Offset(0, incoming ? 1 : -1),
                end: Offset.zero,
              ).animate(a),
              child: child,
            );
          },
          child: Text('$shown', key: ValueKey(shown), style: style),
        ),
      ),
    );
  }
}
