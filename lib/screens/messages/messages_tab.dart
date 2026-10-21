import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/messages.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/centered_search.dart';
import '../../widgets/chat_icons.dart';
import '../../widgets/crystal_logo.dart';
import '../../widgets/fade_slide_in.dart';
import 'chat_screen.dart';
import 'messages_effects.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFFB3BCC3);

/// Messages tab: searchable list of conversations. Tapping one opens the
/// chat full screen.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.onBack, this.active = true});

  /// Called by the back button (returns to the home tab).
  final VoidCallback onBack;

  /// Whether the tab is on screen; the list re-enters each time it becomes
  /// so.
  final bool active;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final _search = TextEditingController();

  /// Bumped when the tab becomes visible, to replay the entrance.
  int _entrance = 0;

  @override
  void didUpdateWidget(MessagesTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) setState(() => _entrance++);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Conversation> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return sampleConversations;
    return sampleConversations
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _visible;
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
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
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: CenteredSearch(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  hint: 'Search conversations',
                ),
              ),
              const SizedBox(height: 22),
              // Rows glide in with a slight tilt; while searching, rows
              // that don't match fold away instead of disappearing.
              for (final (i, c) in sampleConversations.indexed)
                Collapse(
                  key: ValueKey(c.name),
                  visible: conversations.contains(c),
                  child: StaggerIn(
                    delay: Duration(milliseconds: 140 + i * 70),
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutBack,
                    builder: tiltIn,
                    child: _ConversationTile(
                      conversation: c,
                      avatarDelay: Duration(milliseconds: 260 + i * 70),
                      onTap: () =>
                          Navigator.of(context).push(ChatScreen.route(c)),
                    ),
                  ),
                ),
              Collapse(
                visible: conversations.isEmpty,
                child: const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No conversations found',
                      style: TextStyle(fontSize: 14, color: Color(0xFFD9D9D9)),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(onTap: onBack, child: const ArrowIcon()),
        const Expanded(
          child: Center(
            child: Text(
              'Messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ),
        RoundIconButton(
          onTap: () {}, // TODO: open the messages menu.
          child: const ChatIcon(ChatGlyph.dots),
        ),
      ],
    );
  }
}

/// Light gray circular button.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.onTap, required this.child});

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
        child: SizedBox.square(dimension: 44, child: Center(child: child)),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    this.avatarDelay = Duration.zero,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  /// When the avatar pops in.
  final Duration avatarDelay;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Duration(milliseconds: _pressed ? 80 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              // Glides into the chat header when the chat opens.
              Hero(
                tag: 'avatar-${c.name}',
                child: StaggerIn(
                  delay: widget.avatarDelay,
                  curve: Curves.elasticOut,
                  duration: const Duration(milliseconds: 900),
                  builder: popIn,
                  child: ConversationAvatar(conversation: c, size: 52),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _muted,
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

/// A conversation's avatar: the Crystal logo, initials or a group icon,
/// with an online dot when known.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    required this.size,
    this.showStatus = true,
  });

  final Conversation conversation;
  final double size;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final Widget face = switch (c.avatar) {
      AvatarKind.crystal => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary),
        ),
        alignment: Alignment.center,
        child: CrystalLogo(width: size * 0.66),
      ),
      AvatarKind.initials => Container(
        decoration: BoxDecoration(color: c.avatarColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          c.initials ?? '',
          style: TextStyle(
            fontSize: size * 0.3,
            fontWeight: FontWeight.w500,
            color: c.initialsColor,
          ),
        ),
      ),
      AvatarKind.group => Container(
        decoration: BoxDecoration(color: c.avatarColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(
          Icons.people_outline_rounded,
          color: Colors.white,
          size: size * 0.42,
        ),
      ),
    };

    final dotSize = size * 0.2;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: face),
          if (showStatus && c.online != null)
            Positioned(
              right: size * 0.06,
              bottom: size * 0.02,
              child: c.online!
                  // Online: a soft ring breathes out of the dot.
                  ? PulseDot(size: dotSize, color: const Color(0xFF16D33A))
                  : Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFB3BCC3),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
