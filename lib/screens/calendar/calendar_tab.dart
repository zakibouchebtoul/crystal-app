import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/bookings.dart';
import '../../widgets/arrow_icon.dart';
import '../booking/booking_details_screen.dart';
import '../../widgets/centered_search.dart';
import '../../widgets/entrance.dart';
import '../../widgets/rating_chip.dart';
import '../../widgets/svg_path.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFFB3BCC3);
const _chipGray = Color(0xFFA4A4A4);
const _lineGray = Color(0xFFD9D9D9);
const _cardBorder = Color(0xFFF1F2F4);
const _upcoming = Color(0xFFFFB956);
const _completed = Color(0xFF34C759);

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// Calendar tab: month grid with booking dots, filters and a timeline of the
/// selected day's bookings.
///
/// Each time the tab becomes [active] the screen assembles itself: header
/// pops in, search stretches open, arrows slide in, days ripple in as a
/// diagonal wave, chips slide in and the timeline draws itself. Selecting a
/// day glides the blue highlight across the grid; changing day or filter
/// redraws the timeline.
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    required this.onBack,
    this.active = true,
    this.focus,
    this.focusRun = 0,
  });

  /// Booking to jump to and spotlight (e.g. tapped on home).
  final Booking? focus;

  /// Changes each time [focus] should be shown again.
  final int focusRun;

  /// Called by the back button (returns to the home tab).
  final VoidCallback onBack;

  /// Whether the tab is on screen; the entrance plays when it becomes so.
  final bool active;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

/// Filter chips: status filters, then one per service type.
sealed class _Filter {
  const _Filter();
  String get label;
}

class _AllFilter extends _Filter {
  const _AllFilter();
  @override
  String get label => 'All';
}

class _StatusFilter extends _Filter {
  const _StatusFilter({required this.completed});
  final bool completed;
  @override
  String get label => completed ? 'Completed' : 'Upcoming';
}

class _TypeFilter extends _Filter {
  const _TypeFilter(this.type);
  final ServiceType type;
  @override
  String get label => type.label;
}

final _filters = <_Filter>[
  const _AllFilter(),
  const _StatusFilter(completed: false),
  const _StatusFilter(completed: true),
  for (final type in ServiceType.values) _TypeFilter(type),
];

class _CalendarTabState extends State<CalendarTab>
    with SingleTickerProviderStateMixin {
  final DateTime _now = DateTime.now();
  List<Booking> get _bookings => bookingStore.all;
  late DateTime _selected = DateTime(_now.year, _now.month, _now.day);
  late DateTime _month = DateTime(_now.year, _now.month);
  _Filter _filter = _filters.first;
  final _search = TextEditingController();
  final _scroll = ScrollController();

  /// -1 when moving to an earlier month/day, 1 for a later one.
  int _direction = 1;

  /// Bumped on every entrance so the timeline replays its own animation.
  int _entranceRun = 0;

  /// Booking to spotlight once its day's timeline has built in.
  Booking? _spotlight;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _entranceRun == 0) _playEntrance();
  }

  @override
  void didUpdateWidget(CalendarTab old) {
    super.didUpdateWidget(old);
    if (widget.focusRun != old.focusRun && widget.focus != null) {
      _focusOn(widget.focus!);
    }
    if (widget.active && !old.active) _playEntrance();
  }

  /// Opens [booking]'s day with nothing filtered out, so it's in the list.
  void _focusOn(Booking booking) {
    final day = DateTime(
      booking.start.year,
      booking.start.month,
      booking.start.day,
    );
    _direction = day.isAfter(_selected) ? 1 : -1;
    _selected = day;
    _month = DateTime(day.year, day.month);
    _filter = _filters.first;
    _search.clear();
    _spotlight = booking;
  }

  void _playEntrance() {
    _entranceRun++;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    bookingStore.addListener(_onBookings);
  }

  /// New bookings (e.g. just confirmed) show up right away.
  void _onBookings() => setState(() {});

  @override
  void dispose() {
    bookingStore.removeListener(_onBookings);
    _intro.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = delta;
      _month = DateTime(_month.year, _month.month + delta);
      // Keep the same day number, clamped to the new month's length.
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      _selected = DateTime(
        _month.year,
        _month.month,
        _selected.day.clamp(1, lastDay),
      );
    });
  }

  void _selectDay(DateTime day) {
    if (_sameDay(day, _selected)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = day.isAfter(_selected) ? 1 : -1;
      _selected = day;
    });
  }

  bool _matchesFilter(Booking b) => switch (_filter) {
    _AllFilter() => true,
    _StatusFilter(:final completed) => b.isCompleted(_now) == completed,
    _TypeFilter(:final type) => b.type == type,
  };

  /// The selected day's bookings; while searching, matches from any day.
  List<Booking> get _visibleBookings {
    final query = _search.text.trim().toLowerCase();
    return _bookings.where((b) {
      if (!_matchesFilter(b)) return false;
      if (query.isEmpty) return _sameDay(b.start, _selected);
      return b.title.toLowerCase().contains(query) ||
          b.provider.toLowerCase().contains(query) ||
          b.type.label.toLowerCase().contains(query);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Widget build(BuildContext context) {
    final bookings = _visibleBookings;
    final searching = _search.text.trim().isNotEmpty;

    return EntranceScope(
      animation: _intro,
      scroll: _scroll,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: _Header(onBack: widget.onBack),
                ),
              ),
              // Once the title row has scrolled away, the search, month,
              // grid and filters stay put; only the timeline keeps
              // scrolling (with a soft shadow under the pinned block).
              PinnedHeaderSliver(child: _buildPinnedBlock()),
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 4,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(
                  // Hidden at the start of the entrance; the new timeline
                  // then builds itself in once the calendar has assembled.
                  child: Stage(
                    from: 0.3,
                    to: 0.31,
                    builder: (context, t, child) =>
                        Opacity(opacity: t, child: child),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(
                          // A new focus rebuilds the timeline so it spotlights.
                          '$_entranceRun|${widget.focusRun}|$_selected|'
                          '${_filter.label}|'
                          '${_search.text}',
                        ),
                        child: bookings.isEmpty
                            ? _EmptyDay(searching: searching)
                            : _Timeline(
                                bookings: bookings,
                                now: _now,
                                showDates: searching,
                                spotlight: _spotlight,
                                onSpotlightDone: () => _spotlight = null,
                                // On entrance, wait for the calendar first.
                                delay: _intro.isAnimating
                                    ? const Duration(milliseconds: 700)
                                    : Duration.zero,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedBlock() {
    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, child) {
        final shadow = _scroll.hasClients
            ? (_scroll.offset / 60).clamp(0.0, 1.0)
            : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06 * shadow),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _CenteredSearch(
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _MonthNavigator(
              title:
                  '${_weekdays[_selected.weekday - 1]}, '
                  '${_months[_month.month - 1]} ${_month.year}',
              direction: _direction,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(_month) ? 1.0 : -1.0;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(0.3 * _direction * incoming, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: _MonthGrid(
                key: ValueKey(_month),
                month: _month,
                selected: _selected,
                bookings: _bookings,
                onSelect: _selectDay,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FilterChips(
            selected: _filter,
            onSelect: (filter) {
              if (filter.label == _filter.label) return;
              HapticFeedback.selectionClick();
              setState(() => _filter = filter);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header, search and month navigation

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stage(
          from: 0,
          to: 0.3,
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
          ),
          child: _CircleButton(onTap: onBack),
        ),
        Expanded(
          child: Stage(
            from: 0.05,
            to: 0.35,
            builder: (context, t, child) =>
                fadeSlide(t, child, offset: const Offset(0, -12)),
            child: const Column(
              children: [
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UTC+3',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 13,
                      color: _muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // "+" pops in with a quarter spin.
        Stage(
          from: 0.08,
          to: 0.42,
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + 0.5 * t,
              child: Transform.rotate(
                angle: (1 - t) * math.pi / 2,
                child: child,
              ),
            ),
          ),
          child: Material(
            color: AppColors.primary,
            shape: const StadiumBorder(),
            child: InkWell(
              onTap: () {}, // TODO: open "book a service".
              customBorder: const StadiumBorder(),
              child: const SizedBox(
                width: 49,
                height: 34,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Light gray rounded button holding an arrow icon.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.onTap,
    this.forward = false,
    this.width = 40,
  });

  /// Arrow points right instead of left.
  final bool forward;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: width,
          height: 40,
          child: Center(child: ArrowIcon(forward: forward)),
        ),
      ),
    );
  }
}

/// Calendar search box; stretches open from the center on entrance.
class _CenteredSearch extends StatelessWidget {
  const _CenteredSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stage(
      from: 0.1,
      to: 0.4,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(0.3 + 0.7 * t, 1, 1),
          child: child,
        ),
      ),
      child: CenteredSearch(
        controller: controller,
        onChanged: onChanged,
        hint: 'Search for Upcoming services',
      ),
    );
  }
}

/// Month bar: the arrows slide in from the sides on entrance; the title
/// rolls up or down (with the travel [direction]) when it changes.
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.title,
    required this.direction,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final int direction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stage(
          from: 0.16,
          to: 0.44,
          builder: (context, t, child) =>
              fadeSlide(t, child, offset: const Offset(-40, 0)),
          child: _CircleButton(onTap: onPrevious, width: 59),
        ),
        Expanded(
          child: Stage(
            from: 0.2,
            to: 0.46,
            builder: (context, t, child) =>
                Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(title) ? 1.0 : -1.0;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(0, 0.8 * direction * incoming),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: FittedBox(
                  key: ValueKey(title),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Stage(
          from: 0.16,
          to: 0.44,
          builder: (context, t, child) =>
              fadeSlide(t, child, offset: const Offset(40, 0)),
          child: _CircleButton(onTap: onNext, forward: true, width: 59),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.bookings,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<Booking> bookings;
  final ValueChanged<DateTime> onSelect;

  static const _rowHeight = 48.0;
  static const _highlight = Size(36, 34);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first: blank cells before the 1st.
    final leading = DateTime(month.year, month.month).weekday - 1;
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Stage(
          from: 0.22,
          to: 0.45,
          builder: (context, t, child) =>
              fadeSlide(t, child, offset: const Offset(0, -8)),
          child: Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(fontSize: 13, color: _muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / 7;
            final inMonth =
                selected.year == month.year && selected.month == month.month;
            final index = leading + selected.day - 1;

            return SizedBox(
              height: rows * _rowHeight,
              child: Stack(
                children: [
                  // The blue highlight moves to the selected day: a liquid
                  // stretch to neighbouring days, a shrink-and-ripple jump
                  // for anything further.
                  Positioned.fill(
                    child: Stage(
                      from: 0.5,
                      to: 0.75,
                      curve: Curves.easeOutBack,
                      builder: (context, appear, _) => _SelectionHighlight(
                        target: inMonth
                            ? Rect.fromLTWH(
                                (index % 7) * cellWidth +
                                    (cellWidth - _highlight.width) / 2,
                                (index ~/ 7) * _rowHeight + 3,
                                _highlight.width,
                                _highlight.height,
                              )
                            : null,
                        cell: Size(cellWidth, _rowHeight),
                        appear: appear,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (var row = 0; row < rows; row++)
                        Row(
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(
                                child: _buildCell(
                                  row * 7 + col - leading + 1,
                                  row,
                                  col,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCell(int dayNumber, int row, int col) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: _rowHeight);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final isSelected = _CalendarTabState._sameDay(day, selected);
    // One dot per service type booked that day.
    final types = {
      for (final b in bookings)
        if (_CalendarTabState._sameDay(b.start, day)) b.type,
    };
    // Days ripple in as a diagonal wave from the top-left.
    final start = 0.26 + (row + col) * 0.022;

    return _PressDip(
      onTap: () => onSelect(day),
      child: Stage(
        from: start,
        to: start + 0.24,
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
        ),
        child: SizedBox(
          height: _rowHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _highlight.width,
                height: _highlight.height,
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isSelected ? Colors.white : _ink,
                    ),
                    child: Text('$dayNumber'),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, type) in types.indexed)
                      Stage(
                        from: start + 0.14 + i * 0.03,
                        to: math.min(start + 0.3 + i * 0.03, 1),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) => Transform.scale(
                          scale: math.max(t, 0),
                          child: child,
                        ),
                        child: Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: type.color,
                            shape: BoxShape.circle,
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

/// The selection highlight. Its motion depends on the distance:
///
/// - Neighbouring day (including diagonals): a liquid stretch. The edges
///   facing the new day lead, the trailing edges follow with a soft
///   wobble, and the blob thins slightly while stretched.
/// - Further away: the old highlight shrinks and fades while the new one
///   springs open on the new day with a ripple ring.
class _SelectionHighlight extends StatefulWidget {
  const _SelectionHighlight({
    required this.target,
    required this.cell,
    required this.appear,
  });

  /// Where the highlight should rest; null when the selected day isn't in
  /// this month.
  final Rect? target;
  final Size cell;

  /// Entrance scale (0–1, may overshoot).
  final double appear;

  @override
  State<_SelectionHighlight> createState() => _SelectionHighlightState();
}

class _SelectionHighlightState extends State<_SelectionHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  Rect? _from;
  bool _jump = false;

  @override
  void didUpdateWidget(_SelectionHighlight old) {
    super.didUpdateWidget(old);
    final from = old.target;
    final to = widget.target;
    if (from == null || to == null || from == to) return;
    // Start from wherever the highlight is right now (mid-move too).
    _from = _currentTowards(from);
    final dx = ((to.center.dx - _from!.center.dx) / widget.cell.width).abs();
    final dy = ((to.center.dy - _from!.center.dy) / widget.cell.height).abs();
    _jump = dx > 1.5 || dy > 1.5;
    _move
      ..duration = Duration(milliseconds: _jump ? 560 : 520)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  /// Where the highlight is now, while heading to [target].
  Rect _currentTowards(Rect target) {
    final from = _from;
    if (from == null || _jump || _move.value >= 1) return target;
    return _liquid(from, target, _move.value);
  }

  /// Liquid stretch from [from] to [to]: leading edges move first (fast),
  /// trailing edges follow (later, with a slight overshoot).
  static Rect _liquid(Rect from, Rect to, double t) {
    final lead = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
    final trail = Curves.easeOutBack.transform(
      ((t - 0.22) / 0.78).clamp(0.0, 1.0),
    );
    double edge(double a, double b, bool leading) =>
        a + (b - a) * (leading ? lead : trail);

    final right = to.center.dx > from.center.dx;
    final down = to.center.dy > from.center.dy;
    var rect = Rect.fromLTRB(
      edge(from.left, to.left, !right),
      edge(from.top, to.top, !down),
      edge(from.right, to.right, right),
      edge(from.bottom, to.bottom, down),
    );

    // Thin out across the stretch, like a drop being pulled.
    final stretchX = (rect.width / to.width - 1).clamp(0.0, 3.0);
    final stretchY = (rect.height / to.height - 1).clamp(0.0, 3.0);
    rect = Rect.fromCenter(
      center: rect.center,
      width: rect.width * (1 - 0.12 * math.min(stretchY, 1)),
      height: rect.height * (1 - 0.12 * math.min(stretchX, 1)),
    );
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _move,
      builder: (context, _) => CustomPaint(
        painter: _HighlightPainter(
          from: _from,
          to: widget.target,
          t: _move.value,
          jump: _jump,
          appear: widget.appear,
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.jump,
    required this.appear,
  });

  final Rect? from;
  final Rect? to;
  final double t;
  final bool jump;
  final double appear;

  static const _radius = Radius.circular(14);

  @override
  void paint(Canvas canvas, Size size) {
    final to = this.to;
    if (to == null || appear <= 0) return;
    final fill = Paint()..color = AppColors.primary;

    void blob(Rect rect, {double scale = 1, double opacity = 1}) {
      if (scale <= 0 || opacity <= 0) return;
      final r = Rect.fromCenter(
        center: rect.center,
        width: rect.width * scale * appear,
        height: rect.height * scale * appear,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, _radius),
        fill..color = AppColors.primary.withValues(alpha: opacity),
      );
    }

    final from = this.from;
    if (from == null || t >= 1) {
      blob(to);
      return;
    }

    if (!jump) {
      blob(_SelectionHighlightState._liquid(from, to, t));
      return;
    }

    // Jump: old one shrinks away, new one springs open with a ripple.
    final out = Curves.easeInCubic.transform((t / 0.4).clamp(0.0, 1.0));
    blob(from, scale: 1 - out, opacity: 1 - out);

    final grow = Curves.easeOutBack.transform(
      ((t - 0.18) / 0.82).clamp(0.0, 1.0),
    );
    blob(to, scale: grow);

    final ripple = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    if (ripple > 0 && ripple < 1) {
      final eased = Curves.easeOutCubic.transform(ripple);
      final ring = Rect.fromCenter(
        center: to.center,
        width: to.width * (1 + 0.9 * eased),
        height: to.height * (1 + 0.9 * eased),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - ripple) + 0.5
          ..color = AppColors.primary.withValues(alpha: 0.45 * (1 - ripple)),
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.t != t ||
      old.from != from ||
      old.to != to ||
      old.jump != jump ||
      old.appear != appear;
}

/// Tap target that dips its content slightly while pressed.
class _PressDip extends StatefulWidget {
  const _PressDip({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressDip> createState() => _PressDipState();
}

class _PressDipState extends State<_PressDip> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1,
        duration: Duration(milliseconds: _pressed ? 80 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filters

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  static const _border = Color(0xFFD1D1D1);
  static const _fontSize = 14.0;
  static const _height = 42.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter.label == selected.label;
          final start = 0.42 + index * 0.04;
          return Stage(
            // Chips slide in from the right, one after another.
            from: start,
            to: math.min(start + 0.26, 1),
            builder: (context, t, child) =>
                fadeSlide(t, child, offset: const Offset(48, 0)),
            child: GestureDetector(
              onTap: () => onSelect(filter),
              child: TweenAnimationBuilder<double>(
                // Pops when it becomes the selected chip.
                key: ValueKey(isSelected),
                tween: Tween(begin: isSelected ? 0.86 : 1, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  // Fixed height; text centered vertically.
                  height: _height,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(_height / 2),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : _border,
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w400,
                      color: isSelected ? Colors.white : _chipGray,
                    ),
                    child: Text(filter.label),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline

/// The day's bookings on a vertical rail. Builds itself in: the rail draws
/// downward, each dot pops as the rail reaches it, then the time fades in
/// and the card glides in from the right.
class _Timeline extends StatefulWidget {
  const _Timeline({
    required this.bookings,
    required this.now,
    required this.showDates,
    this.delay = Duration.zero,
    this.spotlight,
    this.onSpotlightDone,
  });

  /// Booking to bring into view and spotlight once built in.
  final Booking? spotlight;
  final VoidCallback? onSpotlightDone;

  final List<Booking> bookings;
  final DateTime now;

  /// Show the date above each time (when listing search results).
  final bool showDates;

  /// Wait before building in (e.g. while the rest of the screen enters).
  final Duration delay;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> with TickerProviderStateMixin {
  /// The spotlight: others dim, a blue line traces the card's border, a
  /// glow breathes twice, then everything returns to normal.
  late final AnimationController _spot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  final _spotKey = GlobalKey();

  Booking? get _spotlit =>
      widget.spotlight != null && widget.bookings.contains(widget.spotlight)
      ? widget.spotlight
      : null;

  @override
  void initState() {
    super.initState();
    if (_spotlit != null) {
      _controller.addStatusListener((s) {
        if (s == AnimationStatus.completed) _startSpotlight();
      });
    }
  }

  Future<void> _startSpotlight() async {
    final target = _spotKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.35,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _spot.forward();
    widget.onSpotlightDone?.call();
  }

  static const _timeWidth = 36.0;
  static const _railWidth = 18.0;
  static const _gap = 10.0;

  // Per row: start offset and length (fractions of the build-in time).
  static const _stagger = 0.16;
  static const _rowSpan = 0.45;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        widget.delay +
        Duration(
          milliseconds: (500 + 260 * math.max(widget.bookings.length - 1, 0))
              .toInt(),
        ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spot.dispose();
    super.dispose();
  }

  /// Progress of row [i]'s build-in, after the initial delay.
  double _row(int i, double from, double to, [Curve curve = Curves.linear]) {
    final total = _controller.duration!.inMicroseconds;
    final delay = widget.delay.inMicroseconds / total;
    final t = ((_controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    final count = widget.bookings.length;
    final span = math.min(1.0, _rowSpan + _stagger * (count - 1));
    final rowStart = (i * _stagger) / span;
    final rowLength = _rowSpan / span;
    final local = ((t - rowStart) / rowLength).clamp(0.0, 1.0);
    return curve.transform(((local - from) / (to - from)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final bookings = widget.bookings;
    // The next booking still to come is highlighted in blue.
    final next = bookings.where((b) => !b.isCompleted(widget.now)).firstOrNull;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _spot]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 24),
        child: Column(
          children: [
            for (final (i, booking) in bookings.indexed)
              _buildRow(i, booking, highlighted: booking == next),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int i, Booking booking, {required bool highlighted}) {
    final last = i == widget.bookings.length - 1;
    final bottomGap = EdgeInsets.only(bottom: last ? 0 : _gap);
    final rail = _row(i, 0, 0.6, Curves.easeInOut);
    final dot = _row(i, 0.25, 0.6, Curves.easeOutBack);
    final label = _row(i, 0.35, 0.7);
    final card = _row(i, 0.2, 1, Curves.easeOutCubic);
    final spotlit = booking == _spotlit;
    // Spotlight: rises, holds, fades (others dim meanwhile).
    final s = _spot.value;
    final focus = s == 0 || s == 1
        ? 0.0
        : (s < 0.12 ? s / 0.12 : (s > 0.85 ? (1 - s) / 0.15 : 1.0));
    final dimmed = _spotlit != null && !spotlit ? 1 - 0.55 * focus : 1.0;

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: _timeWidth,
            child: Padding(
              // Keep the label level with the dot (the row includes the
              // gap below the card).
              padding: bottomGap,
              child: Center(
                child: Opacity(
                  opacity: label,
                  child: _TimeLabel(
                    time: booking.start,
                    highlighted: highlighted,
                    showDate: widget.showDates,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _railWidth,
            child: CustomPaint(
              // The rail starts at the first booking's dot and draws down.
              painter: _RailPainter(
                fromDot: i == 0,
                dotY: last ? 0 : -_gap / 2,
                progress: rail,
              ),
              child: Padding(
                padding: bottomGap,
                child: Center(
                  child: Transform.scale(
                    scale: math.max(dot, 0),
                    child: spotlit && s > 0 && s < 1
                        ? _SpotDot(t: s)
                        : Opacity(
                            opacity: dimmed,
                            child: _RailDot(highlighted: highlighted),
                          ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: bottomGap,
              child: Opacity(
                opacity: card,
                child: Transform.translate(
                  offset: Offset(48 * (1 - card), 0),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * card,
                    child: Opacity(
                      opacity: dimmed,
                      child: _PressScale(
                        onTap: () => Navigator.of(
                          context,
                        ).push(BookingDetailsScreen.route(booking)),
                        child: spotlit
                            ? _Spotlight(
                                key: _spotKey,
                                t: s,
                                child: _BookingCard(
                                  booking: booking,
                                  now: widget.now,
                                ),
                              )
                            : _BookingCard(booking: booking, now: widget.now),
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

/// One row's piece of the vertical rail: full height, or from the dot down
/// for the first row; drawn [progress] of the way.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.fromDot,
    required this.dotY,
    required this.progress,
  });

  final bool fromDot;

  /// Dot's offset from the row's vertical center.
  final double dotY;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final x = size.width / 2;
    final top = fromDot ? size.height / 2 + dotY : 0.0;
    canvas.drawLine(
      Offset(x, top),
      Offset(x, top + (size.height - top) * progress),
      Paint()
        ..strokeWidth = 1.5
        ..color = _lineGray,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.fromDot != fromDot || old.dotY != dotY || old.progress != progress;
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.time,
    required this.highlighted,
    required this.showDate,
  });

  final DateTime time;
  final bool highlighted;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minutes = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    final date = '${time.day} ${_months[time.month - 1].substring(0, 3)}\n';
    return Text(
      '${showDate ? date : ''}$hour:$minutes\n$period',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10.5,
        height: 1.2,
        color: highlighted ? AppColors.primary : _lineGray,
        fontWeight: highlighted ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }
}

/// Spotlight on a booking card: a blue line traces round its border from
/// the top left, the card lifts a touch, and a soft blue glow breathes
/// twice before it all fades away.
class _Spotlight extends StatelessWidget {
  const _Spotlight({super.key, required this.t, required this.child});

  /// 0 → 1 over the whole spotlight.
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return child;
    final trace = Curves.easeInOutCubic.transform((t / 0.4).clamp(0.0, 1.0));
    final fade = t > 0.82 ? (1 - t) / 0.18 : 1.0;
    final lift = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
    // Two breaths once the line has closed.
    final breathe = t < 0.4
        ? 0.0
        : math.sin(((t - 0.4) / 0.45).clamp(0.0, 1.0) * math.pi * 2).abs();
    return Transform.scale(
      scale: 1 + 0.025 * lift * fade,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: (0.12 + 0.18 * breathe) * fade,
              ),
              blurRadius: 14 + 10 * breathe,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: _TracePainter(progress: trace, opacity: fade),
          child: child,
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  const _TracePainter({required this.progress, required this.opacity});

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      const Radius.circular(24),
    );
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary.withValues(alpha: opacity);
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    // A bright head on the line while it travels.
    if (progress > 0 && progress < 1) {
      final head = metric.getTangentForOffset(metric.length * progress);
      if (head != null) {
        canvas.drawCircle(
          head.position,
          4,
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.35 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(head.position, 2.2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.progress != progress || old.opacity != opacity;
}

/// The spotlit booking's rail dot: blue, with rings rippling out.
class _SpotDot extends StatelessWidget {
  const _SpotDot({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (final offset in const [0.0, 0.5])
            Builder(
              builder: (context) {
                final r = ((t * 3 + offset) % 1.0);
                return Container(
                  width: 16 + 18 * r,
                  height: 16 + 18 * r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.25 * (1 - r)),
                  ),
                );
              },
            ),
          const _RailDot(highlighted: true),
        ],
      ),
    );
  }
}

class _RailDot extends StatelessWidget {
  const _RailDot({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: highlighted ? 16 : 10,
      height: highlighted ? 16 : 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? const Color(0xFFDFEEFE) : _lineGray,
      ),
      child: highlighted
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

/// Presses [child] in slightly under the finger.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.now});

  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final completed = booking.isCompleted(now);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  booking.type.image,
                  width: 52,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.title,
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
                        '${booking.type.label} - '
                        '${booking.duration.inMinutes}mins',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _chipGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusChip(completed: completed),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              RatingChip(
                rating: booking.rating,
                reviews: booking.reviews,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '${booking.price}QAR',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? _completed : _upcoming;
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          completed ? 'Completed' : 'Upcoming',
          style: TextStyle(fontSize: 10, color: color),
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomPaint(
                size: Size.square(52),
                painter: _EmptyCalendarPainter(),
              ),
              const SizedBox(height: 10),
              Text(
                searching ? 'No matching services' : 'No services on this day',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _lineGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calendar page with a "24" (arcticons calendar-google-24), drawn in code.
class _EmptyCalendarPainter extends CustomPainter {
  const _EmptyCalendarPainter();

  static final _frame = parseSvgPath(
    'M44.2707 34.8959L34.8957 44.2709H9.89567C8.7906 44.2709 7.73079 '
    '43.8319 6.94939 43.0505C6.16799 42.2691 5.729 41.2093 5.729 '
    '40.1042V9.89585C5.729 8.79079 6.16799 7.73098 6.94939 6.94958C7.73079 '
    '6.16817 8.7906 5.72919 9.89567 5.72919H40.104C41.2091 5.72919 42.2689 '
    '6.16817 43.0503 6.94958C43.8317 7.73098 44.2707 8.79079 44.2707 '
    '9.89585V34.8959ZM34.8957 44.2709V5.72919M44.2707 34.8959H5.729M15.104 '
    '44.2709V15.1042H44.2707',
  );
  static final _digits = parseSvgPath(
    'M18.1187 23.4375C18.1187 21.701 19.5073 20.3125 21.1281 20.3125C22.7489 '
    '20.3125 24.2531 21.701 24.2531 23.4375C24.2531 24.2479 23.9052 25.0583 '
    '23.326 25.6365C22.0531 26.6781 18.1177 29.6875 18.1177 '
    '29.6875H24.2531M30.7093 29.6875V20.3125L25.6708 26.6406H31.8812',
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 50);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _lineGray;
    canvas
      ..drawPath(_frame, stroke..strokeWidth = 1)
      ..drawPath(_digits, stroke..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(_EmptyCalendarPainter old) => false;
}
