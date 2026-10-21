import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/service_catalog.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/image_slot.dart';
import '../../widgets/search_icon.dart';
import '../messages/messages_effects.dart';
import 'company_screen.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _soft = Color(0xFFB3BCC3);

/// How a section is ordered; also the "Sort by" options in the filter.
enum _Sort {
  rating('Top rated', 'The most relevant'),
  price('Lowest price', 'Lowest price'),
  distance('Nearest', 'Nearest to you');

  const _Sort(this.label, this.section);
  final String label;

  /// Title of the section that uses this order.
  final String section;
}

/// Filters chosen in the filter sheet.
class _Filters {
  const _Filters({
    this.sort = _Sort.rating,
    this.maxPrice,
    this.minRating,
    this.maxKm,
  });

  /// Its section is shown first.
  final _Sort sort;
  final int? maxPrice;
  final double? minRating;
  final double? maxKm;

  /// Number of active filters (for the badge on the filter button).
  int get count =>
      (sort != _Sort.rating ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (maxKm != null ? 1 : 0);

  bool accepts(CompanyOffer o) =>
      (maxPrice == null || o.priceFrom <= maxPrice!) &&
      (minRating == null || o.company.rating >= minRating!) &&
      (maxKm == null || o.company.km <= maxKm!);
}

/// Every company offering a service: a photo header whose search bar stays
/// pinned on top while scrolling, then carousels — most relevant, lowest
/// price, nearest. The filter button narrows them down and picks which
/// comes first. Tapping a company opens its page.
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({
    super.key,
    required this.service,
    this.userName = 'Bo',
    this.location = 'West Bay, Doha',
  });

  final ServiceDetail service;
  final String userName;
  final String location;

  static Route<void> route(ServiceDetail service) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => CompaniesScreen(service: service),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  _Filters _filters = const _Filters();
  final _search = TextEditingController();
  final _favourites = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CompanyOffer> get _matching {
    final q = _search.text.trim().toLowerCase();
    return widget.service.companies.where((o) {
      if (!_filters.accepts(o)) return false;
      if (q.isEmpty) return true;
      final c = o.company;
      return c.name.toLowerCase().contains(q) ||
          c.area.toLowerCase().contains(q) ||
          c.tags.any((t) => t.toLowerCase().contains(q)) ||
          o.packages.any((p) => p.name.toLowerCase().contains(q));
    }).toList();
  }

  List<CompanyOffer> _sortedBy(_Sort sort, List<CompanyOffer> offers) {
    final list = [...offers];
    switch (sort) {
      case _Sort.rating:
        list.sort((a, b) => b.company.rating.compareTo(a.company.rating));
      case _Sort.price:
        list.sort((a, b) => a.priceFrom.compareTo(b.priceFrom));
      case _Sort.distance:
        list.sort((a, b) => a.company.km.compareTo(b.company.km));
    }
    return list;
  }

  void _open(CompanyOffer offer) => Navigator.of(
    context,
  ).push(CompanyServiceScreen.route(widget.service, offer));

  void _toggleFavourite(String id) {
    HapticFeedback.lightImpact();
    setState(
      () => _favourites.contains(id)
          ? _favourites.remove(id)
          : _favourites.add(id),
    );
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final prices = widget.service.companies.map((o) => o.priceFrom);
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FilterSheet(
        initial: _filters,
        minPrice: prices.reduce((a, b) => a < b ? a : b),
        maxPrice: prices.reduce((a, b) => a > b ? a : b),
      ),
    );
    if (result != null) setState(() => _filters = result);
  }

  Widget _section(_Sort sort, List<CompanyOffer> offers, int order) {
    final sorted = _sortedBy(sort, offers);
    final base = 220 + order * 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(sort.section),
        SizedBox(
          height: _CompanyCard.heightFor(context, 300),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final offer = sorted[i];
              return StaggerIn(
                key: ValueKey('${sort.name}-${offer.company.id}'),
                delay: Duration(milliseconds: base + i * 90),
                duration: const Duration(milliseconds: 620),
                curve: Curves.easeOutBack,
                builder: tiltIn,
                child: SizedBox(
                  width: 300,
                  child: _CompanyCard(
                    offer: offer,
                    favourite: _favourites.contains(offer.company.id),
                    onFavourite: () => _toggleFavourite(offer.company.id),
                    onTap: () => _open(offer),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final matching = _matching;
    // The section matching the chosen sort comes first.
    final sections = [
      _filters.sort,
      for (final sort in _Sort.values)
        if (sort != _filters.sort) sort,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: CustomScrollView(
            slivers: [
              // Collapses on scroll; the search bar stays pinned on top.
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  topPadding: MediaQuery.paddingOf(context).top,
                  service: s,
                  greeting:
                      'Hey, ${widget.userName}! Which '
                      '${s.title.toLowerCase()} today?',
                  location: widget.location,
                  search: _search,
                  onSearch: () => setState(() {}),
                  filterCount: _filters.count,
                  onFilter: _openFilters,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    if (s.weatherSensitive)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
                        child: StaggerIn(
                          delay: Duration(milliseconds: 160),
                          builder: _fadeUp,
                          child: _WeatherTip(),
                        ),
                      ),
                    if (matching.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text(
                            'No companies match your search',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD9D9D9),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final (i, sort) in sections.indexed)
                        _section(sort, matching, i),
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

Widget _fadeUp(double t, Widget child) => Opacity(
  opacity: t.clamp(0.0, 1.0),
  child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
);

// ---------------------------------------------------------------------------
// Header

/// Photo header with rounded bottom. Expanded: back + location, greeting,
/// search. Collapsed (scrolled): just back + search, pinned on top.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.topPadding,
    required this.service,
    required this.greeting,
    required this.location,
    required this.search,
    required this.onSearch,
    required this.filterCount,
    required this.onFilter,
  });

  final double topPadding;
  final ServiceDetail service;
  final String greeting;
  final String location;
  final TextEditingController search;
  final VoidCallback onSearch;
  final int filterCount;
  final VoidCallback onFilter;

  static const _searchHeight = 60.0;
  static const _bottomGap = 20.0;

  @override
  double get maxExtent => topPadding + 248;

  @override
  double get minExtent => topPadding + 10 + _searchHeight + 14;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final height = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final bottomGap = _bottomGap - 6 * t;
    final searchTop = height - bottomGap - _searchHeight;
    // The back button moves from the top row to beside the search bar.
    final expandedTop = topPadding + 8;
    final collapsedTop = searchTop + (_searchHeight - 44) / 2;
    final backTop = expandedTop + (collapsedTop - expandedTop) * t;
    final searchLeft = 24 + (44 + 10) * t;

    // Until a header photo is added: the top company's cover, blurred.
    final fallbackCover = service.companies.isEmpty
        ? null
        : service.companies.first.company.cover;
    final fallback = Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1E5C), AppColors.primary],
            ),
          ),
        ),
        if (fallbackCover != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Image.asset(
              fallbackCover,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
      child: Stack(
        children: [
          // Photo stays put (its top is cut off as the header shrinks).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: maxExtent,
            child: ImageSlot(
              asset: service.headerImage,
              label: '',
              fallback: fallback,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x99000000),
                    Color.lerp(
                      const Color(0x66000000),
                      const Color(0x99000000),
                      t,
                    )!,
                  ],
                ),
              ),
            ),
          ),
          // Location, icon and greeting fade and lift away.
          Positioned(
            left: 24 + 44 + 12,
            right: 24,
            top: topPadding + 8 - 20 * t,
            child: Opacity(
              opacity: (1 - t * 2.2).clamp(0.0, 1.0),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    StaggerIn(
                      curve: Curves.elasticOut,
                      duration: const Duration(milliseconds: 900),
                      builder: popIn,
                      child: Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            service.tileImage,
                            fit: BoxFit.cover,
                          ),
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
            top: topPadding + 8 + 44 + 22 - 30 * t,
            child: Opacity(
              opacity: (1 - t * 1.8).clamp(0.0, 1.0),
              child: StaggerIn(
                delay: const Duration(milliseconds: 80),
                builder: _fadeUp,
                child: Text(
                  greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: backTop,
            child: _GlassCircle(
              onTap: () => Navigator.of(context).pop(),
              child: const ArrowIcon(color: Colors.white),
            ),
          ),
          Positioned(
            left: searchLeft,
            right: 24,
            top: searchTop,
            height: _searchHeight,
            child: StaggerIn(
              delay: const Duration(milliseconds: 140),
              builder: _fadeUp,
              child: _GlassSearch(
                controller: search,
                onChanged: onSearch,
                compact: t > 0.6,
                filterCount: filterCount,
                onFilter: onFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.onTap,
    required this.child,
    this.size = 44,
  });

  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted search bar with a filter button. The placeholder fades away as
/// soon as the box is tapped; [compact] drops its second line.
class _GlassSearch extends StatefulWidget {
  const _GlassSearch({
    required this.controller,
    required this.onChanged,
    required this.filterCount,
    required this.onFilter,
    this.compact = false,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final int filterCount;
  final VoidCallback onFilter;
  final bool compact;

  @override
  State<_GlassSearch> createState() => _GlassSearchState();
}

class _GlassSearchState extends State<_GlassSearch> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const SearchIcon(color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final showHint = !_focus.hasFocus && value.text.isEmpty;
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: showHint ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: AnimatedSlide(
                                offset: Offset(showHint ? 0 : -0.05, 0),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Search companies',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: widget.compact
                                          ? const SizedBox(width: 0)
                                          : const Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Name · Area · Service',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xCCFFFFFF),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            onChanged: (_) => widget.onChanged(),
                            cursorColor: Colors.white,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration.collapsed(
                              hintText: '',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Filter button, with a badge counting active filters.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _GlassCircle(
                      size: 42,
                      onTap: widget.onFilter,
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    if (widget.filterCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(widget.filterCount),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              '${widget.filterCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter sheet

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.minPrice,
    required this.maxPrice,
  });

  final _Filters initial;
  final int minPrice;
  final int maxPrice;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Sort _sort = widget.initial.sort;
  late double _price = (widget.initial.maxPrice ?? widget.maxPrice).toDouble();
  late double? _rating = widget.initial.minRating;
  late double? _km = widget.initial.maxKm;

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final priceActive = _price.round() < widget.maxPrice;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 16 + bottom),
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
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pick(() {
                  _sort = _Sort.rating;
                  _price = widget.maxPrice.toDouble();
                  _rating = null;
                  _km = null;
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _SheetLabel('Sort by'),
          _ChoiceRow(
            labels: [for (final s in _Sort.values) s.label],
            selected: _Sort.values.indexOf(_sort),
            onSelect: (i) => _pick(() => _sort = _Sort.values[i]),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: _SheetLabel('Max starting price')),
              Text(
                priceActive ? '${_price.round()} QAR' : 'Any',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (widget.maxPrice > widget.minPrice)
            Slider(
              value: _price,
              min: widget.minPrice.toDouble(),
              max: widget.maxPrice.toDouble(),
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _price = v),
            ),
          const SizedBox(height: 6),
          const _SheetLabel('Rating'),
          _ChoiceRow(
            labels: const ['Any', '4.5+', '4.8+'],
            selected: switch (_rating) {
              4.5 => 1,
              4.8 => 2,
              _ => 0,
            },
            onSelect: (i) => _pick(() => _rating = [null, 4.5, 4.8][i]),
          ),
          const SizedBox(height: 18),
          const _SheetLabel('Distance'),
          _ChoiceRow(
            labels: const ['Any', 'Under 3 km', 'Under 5 km'],
            selected: switch (_km) {
              3 => 1,
              5 => 2,
              _ => 0,
            },
            onSelect: (i) => _pick(() => _km = [null, 3.0, 5.0][i]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _Filters(
                  sort: _sort,
                  maxPrice: priceActive ? _price.round() : null,
                  minRating: _rating,
                  maxKm: _km,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Show results'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, label) in labels.indexed)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: i == selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i == selected
                      ? AppColors.primary
                      : const Color(0xFFD1D1D1),
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: i == selected ? Colors.white : _muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sections

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}

/// Live weather card: a warm sandy sky with dust drifting across and wind
/// streaks, today's condition, and a 3-day strip where the best day for
/// outdoor work glows. (Sample forecast until a weather service is
/// connected.)
class _WeatherTip extends StatefulWidget {
  const _WeatherTip();

  @override
  State<_WeatherTip> createState() => _WeatherTipState();
}

enum _Sky { dust, hazy, clear }

class _WeatherTipState extends State<_WeatherTip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  static const _forecast = [
    (_Sky.dust, 31, 'Dusty'),
    (_Sky.hazy, 29, 'Hazy'),
    (_Sky.clear, 27, 'Clear'),
  ];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    String label(int i) =>
        i == 0 ? 'Today' : days[now.add(Duration(days: i)).weekday - 1];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) =>
            CustomPaint(painter: _DustSkyPainter(_clock.value), child: child),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Swaying wind icon in a frosted circle.
                  AnimatedBuilder(
                    animation: _clock,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        2 * math.sin(_clock.value * 2 * math.pi * 3),
                        0,
                      ),
                      child: child,
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.air_rounded,
                        color: Color(0xFFC98A1E),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dusty today · 31°',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B2A12),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sand blowing in from 4 PM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A6A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, (sky, temp, text)) in _forecast.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _DayChip(
                        day: label(i),
                        sky: sky,
                        temp: temp,
                        text: text,
                        best: sky == _Sky.clear,
                        clock: _clock,
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

/// One day of the strip; the best day glows and its sun pulses.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.sky,
    required this.temp,
    required this.text,
    required this.best,
    required this.clock,
  });

  final String day;
  final _Sky sky;
  final int temp;
  final String text;
  final bool best;
  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final pulse = (math.sin(clock.value * 2 * math.pi * 2) + 1) / 2;
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: best ? null : Colors.white.withValues(alpha: 0.55),
            gradient: best
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF3B9BFF)],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: best
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.15 + 0.15 * pulse,
                      ),
                      blurRadius: 8 + 6 * pulse,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _SkyIcon(sky: sky, pulse: pulse, onBlue: best),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: best ? Colors.white : const Color(0xFF3B2A12),
                      ),
                    ),
                    Text(
                      best ? '$temp° · Best day' : '$temp° $text',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: best
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF8A6A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkyIcon extends StatelessWidget {
  const _SkyIcon({
    required this.sky,
    required this.pulse,
    required this.onBlue,
  });

  final _Sky sky;
  final double pulse;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    return switch (sky) {
      _Sky.clear => Container(
        width: 18 + 2 * pulse,
        height: 18 + 2 * pulse,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFF3B0), Color(0xFFFFC21C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD34D).withValues(alpha: 0.9),
              blurRadius: 6 + 6 * pulse,
              spreadRadius: 1 + pulse,
            ),
          ],
        ),
      ),
      _Sky.hazy => const Icon(
        Icons.wb_cloudy_rounded,
        size: 20,
        color: Color(0xFFD9B57A),
      ),
      _Sky.dust => const Icon(
        Icons.air_rounded,
        size: 20,
        color: Color(0xFFC98A1E),
      ),
    };
  }
}

/// Warm sandy gradient with dust specks drifting sideways and faint wind
/// streaks sweeping across; [t] loops 0–1.
class _DustSkyPainter extends CustomPainter {
  _DustSkyPainter(this.t);

  final double t;

  static final _specks = () {
    final r = math.Random(5);
    return [
      for (var i = 0; i < 28; i++)
        (
          x: r.nextDouble(),
          y: r.nextDouble(),
          size: 0.8 + r.nextDouble() * 2,
          speed: 1 + r.nextInt(3),
          phase: r.nextDouble(),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF1DC), Color(0xFFF7E3C2), Color(0xFFEFF5FE)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    // Wind streaks.
    final streak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final p = (t * 2 + i / 3) % 1;
      final x = -80 + (size.width + 160) * p;
      final y = size.height * (0.22 + i * 0.22);
      streak.color = const Color(
        0xFFD9A85A,
      ).withValues(alpha: 0.35 * math.sin(math.pi * p));
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 30, y - 6, x + 60, y)
          ..quadraticBezierTo(x + 80, y + 4, x + 90, y - 2),
        streak,
      );
    }

    // Drifting dust.
    final dust = Paint();
    for (final s in _specks) {
      final p = (t * s.speed + s.phase) % 1;
      final x = (s.x + p) % 1 * size.width;
      final y =
          s.y * size.height + 4 * math.sin((p * 4 + s.phase) * 2 * math.pi);
      dust.color = const Color(
        0xFFC9965A,
      ).withValues(alpha: 0.25 + 0.25 * math.sin(math.pi * p));
      canvas.drawCircle(Offset(x, y), s.size, dust);
    }
  }

  @override
  bool shouldRepaint(_DustSkyPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Company card

/// Big image card: cover with a heart, then name & rating, services, and
/// price & distance.
class _CompanyCard extends StatefulWidget {
  const _CompanyCard({
    required this.offer,
    required this.favourite,
    required this.onFavourite,
    required this.onTap,
  });

  final CompanyOffer offer;
  final bool favourite;
  final VoidCallback onFavourite;
  final VoidCallback onTap;

  /// Total height for a card of [width] (16:9 cover + text block).
  static double heightFor(BuildContext context, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    // Cover (inset 6 on each side) + name, services and price lines.
    return (width - 12) * 9 / 16 + 12 + 100 * scale;
  }

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final c = offer.company;
    final services = offer.packages.map((p) => p.name).join(' · ');
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 240),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF1F2F4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageSlot(asset: c.cover, label: 'Company cover'),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: _HeartButton(
                            active: widget.favourite,
                            onTap: widget.onFavourite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox.square(
                        dimension: 24,
                        child: ImageSlot(
                          asset: c.logo,
                          label: '',
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The name takes all the room the rating doesn't need.
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                          if (c.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, size: 18, color: _ink),
                    const SizedBox(width: 2),
                    Text(
                      '${c.rating} (${c.reviewCount})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(
                  services,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _soft),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: _muted),
                    children: [
                      const TextSpan(text: 'from '),
                      TextSpan(
                        text: '${offer.priceFrom} QAR',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      TextSpan(text: '  ·  ${c.distance} · ${c.area}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted heart that pops when toggled.
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            color: Colors.black.withValues(alpha: 0.25),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(active),
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Icon(
                active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: active ? const Color(0xFFFF4D67) : Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
