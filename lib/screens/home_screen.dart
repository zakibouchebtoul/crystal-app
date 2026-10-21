import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../data/bookings.dart';
import '../widgets/glass_tab_bar.dart';
import '../widgets/tab_icons.dart';
import 'calendar/calendar_tab.dart';
import 'concierge/concierge_screen.dart';
import 'home/home_tab.dart';
import 'messages/messages_tab.dart';
import 'profile/profile_tab.dart';

/// Main app shell: the bottom bar switches between the tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _tabs = [
  GlassTabItem('Home', TabGlyph.home),
  GlassTabItem('Calendar', TabGlyph.calendar),
  GlassTabItem('AI Concierge', TabGlyph.concierge),
  GlassTabItem('Messages', TabGlyph.messages),
  GlassTabItem('Profile', TabGlyph.profile),
];

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Booking the calendar should show and spotlight; [_focusRun] changes
  /// each time so the same booking can be spotlit again.
  Booking? _calendarFocus;
  int _focusRun = 0;

  // Bottom bar entrance: rises from below, then its items pop in.
  late final AnimationController _barIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _barIn.value = 1;
    } else {
      _barIn.forward();
    }
  }

  @override
  void dispose() {
    _barIn.dispose();
    super.dispose();
  }

  static const _conciergeTab = 2;

  Future<void> _onTabSelected(int index) async {
    if (index != _conciergeTab) {
      setState(() => _index = index);
      return;
    }
    // The concierge is a full-screen page, not a tab.
    final result = await Navigator.of(context).push(ConciergeScreen.route());
    if (result == conciergeOpenCalendar && mounted) {
      setState(() => _index = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white, // Matches the glass bar's background.
        // Content runs under the bar (the home tab pads for it).
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            for (final (i, tab) in _tabViews.indexed)
              // Hidden tabs stay alive but their animations pause.
              TickerMode(enabled: i == _index, child: tab),
          ],
        ),
        bottomNavigationBar: GlassTabBar(
          items: _tabs,
          index: _index,
          entrance: _barIn,
          onSelected: _onTabSelected,
        ),
      ),
    );
  }

  List<Widget> get _tabViews => [
    HomeTab(
      active: _index == 0,
      onOpenProfile: () => setState(() => _index = 4),
      onOpenCalendar: (booking) => setState(() {
        _calendarFocus = booking;
        _focusRun++;
        _index = 1;
      }),
    ),
    CalendarTab(
      active: _index == 1,
      onBack: () => setState(() => _index = 0),
      focus: _calendarFocus,
      focusRun: _focusRun,
    ),
    // The concierge (index 2) opens as its own page.
    _ComingSoon(title: _tabs[2].label),
    MessagesTab(active: _index == 3, onBack: () => setState(() => _index = 0)),
    ProfileTab(active: _index == 4, onBack: () => setState(() => _index = 0)),
  ];
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title\ncoming soon',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
      ),
    );
  }
}
