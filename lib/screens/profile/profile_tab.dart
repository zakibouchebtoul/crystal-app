import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/profile_icons.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFFB3BCC3);
const _card = Color(0xFFF5F6F8);

/// Profile tab: photo, email, recent orders and the general settings list.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.onBack,
    this.active = true,
    this.email = 'bomohamed@test.com',
  });

  /// Called by the back button (returns to the home tab).
  final VoidCallback onBack;

  /// Whether the tab is on screen; the page re-enters each time it becomes
  /// so.
  final bool active;
  final String email;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _entrance = 0;

  @override
  void didUpdateWidget(ProfileTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) setState(() => _entrance++);
  }

  static const _general = [
    (
      ProfileGlyph.person,
      'Personal informations',
      'Manage your account details',
    ),
    (ProfileGlyph.notification, 'Notification', null),
    (ProfileGlyph.security, 'Security', null),
    (ProfileGlyph.language, 'Language', null),
    (ProfileGlyph.help, 'Help center', null),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: KeyedSubtree(
        key: ValueKey(_entrance),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            FadeSlideIn(child: _Header(onBack: widget.onBack)),
            const SizedBox(height: 40),
            const Center(child: _Photo()),
            const SizedBox(height: 44),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(
              delay: Duration(milliseconds: 320),
              child: _RecentOrderCard(),
            ),
            const SizedBox(height: 28),
            const FadeSlideIn(
              delay: Duration(milliseconds: 380),
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'General',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    for (final (i, (glyph, title, subtitle))
                        in _general.indexed)
                      FadeSlideIn(
                        delay: Duration(milliseconds: 500 + i * 60),
                        child: _SettingsRow(
                          glyph: glyph,
                          title: title,
                          subtitle: subtitle,
                          onTap: () {}, // TODO: open this settings page.
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.fill,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox.square(
              dimension: 44,
              child: Center(child: ArrowIcon()),
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ),
        // Settings gear turns a little when tapped.
        const _SpinOnTap(child: ProfileIcon(ProfileGlyph.settings)),
      ],
    );
  }
}

/// Settings button: the gear makes a quarter turn on each tap.
class _SpinOnTap extends StatefulWidget {
  const _SpinOnTap({required this.child});

  final Widget child;

  @override
  State<_SpinOnTap> createState() => _SpinOnTapState();
}

class _SpinOnTapState extends State<_SpinOnTap> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _turns += 0.25);
        // TODO: open the settings page.
      },
      icon: AnimatedRotation(
        turns: _turns,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Large round photo that pops in, with the edit badge springing on.
class _Photo extends StatelessWidget {
  const _Photo();

  static const _size = 168.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: CircleAvatar(
                backgroundImage: AssetImage('assets/images/profile/photo.jpg'),
              ),
            ),
            Positioned(
              right: -4,
              bottom: 14,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: const Interval(0.45, 1, curve: Curves.elasticOut),
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFFF1F2F4)),
                  ),
                  elevation: 0,
                  child: InkWell(
                    onTap: () {}, // TODO: change the profile photo.
                    customBorder: const CircleBorder(),
                    child: const SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: ProfileIcon(ProfileGlyph.edit, size: 22),
                      ),
                    ),
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

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () {}, // TODO: open recent orders.
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 20, 16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Recent Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Stay updated on your orders',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: ProfileIcon(ProfileGlyph.stats, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final ProfileGlyph glyph;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 9, 20, 9),
        child: Row(
          children: [
            ProfileIcon(glyph),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                  if (subtitle case final subtitle?) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6A7B89),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
