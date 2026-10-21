import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import 'tab_icons.dart';

class GlassTabItem {
  const GlassTabItem(this.label, this.glyph);

  final String label;
  final TabGlyph glyph;
}

/// White bottom bar with an iOS-style selection lens.
///
/// At rest the selected tab sits on a soft gray pill. When switching (tap,
/// or drag along the bar) the pill lifts into a glass lens: it swells,
/// turns translucent with a bright edge, springs to the new tab while
/// stretching with its speed, then settles back into the solid pill. Icon
/// and label colors follow the lens continuously.
///
/// [entrance] (optional, 0–1) plays an intro: the bar rises, then its items
/// pop in.
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
    this.entrance,
  });

  final List<GlassTabItem> items;
  final int index;
  final ValueChanged<int> onSelected;
  final Animation<double>? entrance;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  static const _height = 60.0;
  static const _restPill = Color(0xFFF4F5F7);
  static const _iconIdle = Color(0xFFE8E8E8);
  static const _labelIdle = Color(0xFF6D7B88);
  static const _active = Color(0xFF3375EE);

  // Lens position in tabs (0 = first tab), driven by a spring.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  // 0 = solid resting pill, 1 = glass lens.
  late final AnimationController _glass = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 320),
  );

  bool _dragging = false;
  double _releaseVelocity = 0; // tabs per second, from a drag

  @override
  void didUpdateWidget(GlassTabBar old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index && !_dragging) {
      _springTo(widget.index, velocity: _releaseVelocity);
      _releaseVelocity = 0;
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _glass.dispose();
    super.dispose();
  }

  void _springTo(int target, {double velocity = 0}) {
    _glass.forward();
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 260, damping: 28),
      _position.value,
      target.toDouble(),
      velocity,
      tolerance: const Tolerance(distance: 0.005, velocity: 0.05),
    );
    _position.animateWith(simulation).whenCompleteOrCancel(() {
      if (mounted && !_dragging) _glass.reverse();
    });
  }

  void _select(int index) {
    if (index == widget.index) {
      // Snap back if a drag ended on the current tab.
      _springTo(index, velocity: _releaseVelocity);
      _releaseVelocity = 0;
      return;
    }
    HapticFeedback.selectionClick();
    widget.onSelected(index);
    // If the parent didn't switch tabs (e.g. the tab opens a page
    // instead), spring back to the current one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.index == index) return;
      _springTo(widget.index, velocity: _releaseVelocity);
      _releaseVelocity = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final entrance = widget.entrance ?? const AlwaysStoppedAnimation(1.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_position, _glass, entrance]),
      builder: (context, _) {
        double stage(double from, double to, Curve curve) => curve.transform(
          ((entrance.value - from) / (to - from)).clamp(0.0, 1.0),
        );
        final rise = stage(0, 0.4, Curves.easeOutCubic);

        return FractionalTranslation(
          translation: Offset(0, 1 - rise),
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                11,
                8,
                11,
                // Sits a little into the home-indicator area, but never
                // below 8 (the inset shrinks while the keyboard is open).
                math.max(bottomInset - 14, 8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildBar(constraints.maxWidth, stage),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBar(double width, double Function(double, double, Curve) stage) {
    final count = widget.items.length;
    final itemWidth = width / count;
    final position = _position.value;
    final glass = Curves.easeOut.transform(_glass.value);

    // Stretch along the direction of travel, from the spring's speed.
    final stretch = (_position.velocity.abs() * 0.035).clamp(0.0, 0.3);
    final lensWidth = itemWidth * (1 + 0.12 * glass + stretch);
    final lensHeight = _height * (1 + 0.1 * glass);
    final lensLeft = position * itemWidth - (lensWidth - itemWidth) / 2;
    final lensTop = -(lensHeight - _height) / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _select(
        (details.localPosition.dx / itemWidth).floor().clamp(0, count - 1),
      ),
      onHorizontalDragStart: (_) {
        _dragging = true;
        _position.stop();
        _glass.forward();
      },
      onHorizontalDragUpdate: (details) {
        _position.value = (_position.value + details.delta.dx / itemWidth)
            .clamp(0.0, count - 1.0);
      },
      onHorizontalDragEnd: (details) {
        _dragging = false;
        _releaseVelocity = details.velocity.pixelsPerSecond.dx / itemWidth;
        final target = (_position.value + _releaseVelocity * 0.12)
            .round()
            .clamp(0, count - 1);
        _select(target);
      },
      child: SizedBox(
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Resting pill, under the items.
            Positioned(
              left: position * itemWidth,
              width: itemWidth,
              top: 0,
              height: _height,
              child: Opacity(
                opacity: 1 - glass,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: _restPill,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, item) in widget.items.indexed)
                  Expanded(
                    child: _buildItem(
                      item,
                      // 1 under the lens, 0 a tab or more away.
                      (1 - (position - i).abs()).clamp(0.0, 1.0),
                      stage(0.3 + i * 0.1, 0.6 + i * 0.1, Curves.easeOutBack),
                    ),
                  ),
              ],
            ),
            // Glass lens, over the items while moving.
            if (glass > 0)
              Positioned(
                left: lensLeft,
                width: lensWidth,
                top: lensTop,
                height: lensHeight,
                child: IgnorePointer(child: _Lens(amount: glass)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(GlassTabItem item, double active, double pop) {
    final iconColor = Color.lerp(_iconIdle, _active, active)!;
    final labelColor = Color.lerp(_labelIdle, _active, active)!;
    return Opacity(
      opacity: pop.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.5 + 0.5 * pop,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1 + 0.08 * active,
              child: TabIcon(
                item.glyph,
                color: iconColor,
                selected: active > 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Kept inside the pill: side padding, and only shrinks if a
            // label still wouldn't fit (narrow phones, large text).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: active > 0.5
                        ? FontWeight.w500
                        : FontWeight.w400,
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

/// The moving glass lens: frosts what's under it, with a light sheen, a
/// bright rim and a soft shadow.
class _Lens extends StatelessWidget {
  const _Lens({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(34);
    return Opacity(
      opacity: amount,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: math.max(0.01, 0.5 * amount),
              sigmaY: math.max(0.01, 0.5 * amount),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.12),
                    const Color(0xFFE9F2FE).withValues(alpha: 0.35),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
