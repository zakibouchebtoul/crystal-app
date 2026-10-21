import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/bookings.dart';
import '../booking/booking_details_screen.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/messages.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/chat_icons.dart';
import '../../widgets/rating_chip.dart';
import 'messages_effects.dart';
import 'messages_tab.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFFB3BCC3);
const _bubble = Color(0xFFF7F8F9);
const _mineBubble = Color(0xFFE6F0FE);

/// Full-screen chat with one conversation (no bottom bar).
///
/// Sending is local for now: your message appears, gets "Seen", the other
/// side types and sends a short demo reply.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  /// Slides in from the right, iOS style.
  static Route<void> route(Conversation conversation) =>
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversation: conversation),
      );

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final List<ChatItem> _items = [...widget.conversation.history];
  late final List<String> _quickReplies = [...widget.conversation.quickReplies];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Items below this index were there on open and don't animate in.
  late final int _initialCount = _items.length;
  bool _typing = false;

  /// Quick replies already sent; they fold out of the row.
  final _usedReplies = <String>{};

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    HapticFeedback.lightImpact();
    _input.clear();
    setState(() {
      _items.add(ChatText(message, mine: true));
      _usedReplies.add(message);
    });
    _scrollToEnd();

    // TODO: send through the messaging backend. Demo: seen, typing, reply.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      final last = _items.lastIndexWhere((i) => i is ChatText && i.mine);
      _items[last] = ChatText(message, mine: true, seen: true);
      _typing = true;
    });
    _scrollToEnd();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _typing = false;
      _items.add(
        const ChatText('Got it! We\'ll take care of it and update you here.'),
      );
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Only the user's latest message shows "Seen".
  int get _lastMine => _items.lastIndexWhere((i) => i is ChatText && i.mine);

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                _Header(conversation: c),
                const Divider(height: 1, color: Color(0xFFF1F2F4)),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                    children: [
                      for (final (i, item) in _items.indexed)
                        _Appear(
                          key: ValueKey(i),
                          animate: i >= _initialCount,
                          mine: item is ChatText && item.mine,
                          // History cascades in when the chat opens, each
                          // message from its own side.
                          child: StaggerIn(
                            enabled: i < _initialCount,
                            delay: Duration(milliseconds: 180 + i * 110),
                            builder: (t, child) => sideIn(
                              t,
                              child,
                              fromRight: item is ChatText && item.mine,
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                              child: switch (item) {
                                ChatText(:final mine) when mine => _MineBubble(
                                  text: item,
                                  showSeen: i == _lastMine,
                                ),
                                ChatText() => _TheirBubble(
                                  text: item.text,
                                  conversation: c,
                                ),
                                ChatBooking() => ShineOnce(
                                  delay: Duration(milliseconds: 500 + i * 110),
                                  child: _BookingCard(booking: item),
                                ),
                              },
                            ),
                          ),
                        ),
                      if (_typing)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _Appear(child: _TypingBubble(conversation: c)),
                        ),
                    ],
                  ),
                ),
                Collapse(
                  visible: _usedReplies.length < _quickReplies.length,
                  child: _QuickReplies(
                    replies: _quickReplies,
                    used: _usedReplies,
                    onTap: _send,
                  ),
                ),
                _Composer(controller: _input, onSend: () => _send(_input.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Row(
        children: [
          RoundIconButton(
            onTap: () => Navigator.of(context).pop(),
            child: const ArrowIcon(),
          ),
          const SizedBox(width: 12),
          Hero(
            tag: 'avatar-${c.name}',
            child: ConversationAvatar(conversation: c, size: 48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          RoundIconButton(
            onTap: () {}, // TODO: start a call.
            child: const ChatIcon(ChatGlyph.call),
          ),
        ],
      ),
    );
  }
}

/// New messages slide in from their side; history shows as is.
class _Appear extends StatelessWidget {
  const _Appear({
    super.key,
    required this.child,
    this.animate = true,
    this.mine = false,
  });

  final Widget child;
  final bool animate;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Transform.scale(
            scale: 0.9 + 0.1 * t,
            alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _TheirBubble extends StatelessWidget {
  const _TheirBubble({required this.text, required this.conversation});

  final String text;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConversationAvatar(
            conversation: conversation,
            size: 28,
            showStatus: false,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _bubble,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, height: 1.3, color: _ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MineBubble extends StatelessWidget {
  const _MineBubble({required this.text, required this.showSeen});

  final ChatText text;
  final bool showSeen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _mineBubble,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    text.text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
                child: const Text(
                  'BO',
                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: !showSeen
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(text.seen),
                    padding: const EdgeInsets.only(top: 3, right: 36),
                    child: Text(
                      text.seen ? 'Seen' : 'Sent ✓',
                      style: TextStyle(
                        fontSize: 10,
                        color: text.seen ? AppColors.primary : _muted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.conversation});

  final Conversation conversation;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConversationAvatar(
            conversation: widget.conversation,
            size: 28,
            showStatus: false,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _bubble,
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Transform.translate(
                      offset: Offset(
                        0,
                        -3 *
                            math
                                .sin(
                                  ((_controller.value - i * 0.15) % 1) *
                                      math.pi,
                                )
                                .clamp(0.0, 1.0),
                      ),
                      child: Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: _muted,
                          shape: BoxShape.circle,
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
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final ChatBooking booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 6, 50, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F2F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    booking.image,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.when,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () {
                  final match = _bookingFor(booking);
                  if (match != null) {
                    Navigator.of(
                      context,
                    ).push(BookingDetailsScreen.route(match));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('View Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({
    required this.replies,
    required this.used,
    required this.onTap,
  });

  final List<String> replies;
  final Set<String> used;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox.shrink(),
        itemBuilder: (context, i) => Collapse(
          axis: Axis.horizontal,
          visible: !used.contains(replies[i]),
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: Material(
              color: _bubble,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () => onTap(replies[i]),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      replies[i],
                      style: const TextStyle(fontSize: 13, color: _ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Message composer. While there's text, the attachment and mic fold away
/// (the field widens) and the send button turns blue.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
          child: Row(
            children: [
              Collapse(
                axis: Axis.horizontal,
                visible: !hasText,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {}, // TODO: attach a photo or file.
                      icon: const ChatIcon(ChatGlyph.attach),
                    ),
                    IconButton(
                      onPressed: () {}, // TODO: record a voice message.
                      icon: const ChatIcon(ChatGlyph.mic),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: _bubble,
                    borderRadius: BorderRadius.circular(29),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          style: const TextStyle(fontSize: 14, color: _ink),
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6A7B89),
                            ),
                          ),
                        ),
                      ),
                      _SendButton(active: hasText, onTap: onSend),
                    ],
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

/// White send button that turns blue (with a little pop) once there's text,
/// and darts its arrow forward when pressed.
class _SendButton extends StatefulWidget {
  const _SendButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.active ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          final on = t.clamp(0.0, 1.0);
          return Transform.scale(
            scale: (_pressed ? 0.9 : 1) * (1 + 0.06 * math.sin(math.pi * on)),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Color.lerp(Colors.white, AppColors.primary, on),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: AnimatedSlide(
                  offset: Offset(_pressed ? 0.25 : 0, 0),
                  duration: const Duration(milliseconds: 120),
                  child: ArrowIcon(
                    forward: true,
                    color: Color.lerp(_ink, Colors.white, on)!,
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

/// The stored booking a chat card refers to: same company, else the next
/// booking of the same service.
Booking? _bookingFor(ChatBooking card) {
  final now = DateTime.now();
  final all = bookingStore.upcoming(now);
  for (final b in all) {
    if (b.provider == card.provider) return b;
  }
  final word = card.title.split(' ').first.toLowerCase();
  for (final b in all) {
    if (b.type.label.toLowerCase().startsWith(word)) return b;
  }
  return all.isEmpty ? null : all.first;
}
