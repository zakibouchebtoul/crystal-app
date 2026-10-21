import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/concierge.dart';
import '../../widgets/arrow_icon.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/rating_chip.dart';
import '../../widgets/svg_path.dart';
import '../../widgets/tab_icons.dart';
import 'concierge_effects.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _bubble = Color(0xFFF7F8F9);
const _inputFill = Color(0xFFF4F5F7);

/// What the concierge page shows.
enum _Mode { welcome, chat, listening }

/// Result returned when the page closes via the calendar button.
const conciergeOpenCalendar = 'calendar';

/// Full-screen AI Concierge (no bottom bar): a welcome screen with quick
/// suggestions, a chat with rich replies (weather, bookable services) and a
/// voice "listening" mode.
class ConciergeScreen extends StatefulWidget {
  const ConciergeScreen({super.key, this.userName = 'Bo Mohamed'});

  final String userName;

  /// Opens the concierge with a rise-and-fade transition.
  static Route<String> route() => PageRouteBuilder<String>(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const ConciergeScreen(),
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
  State<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends State<ConciergeScreen> {
  final _engine = const ConciergeEngine();
  final _messages = <ConciergeMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  _Mode _mode = _Mode.welcome;
  bool _typing = false;

  /// Messages below this index were already shown and don't animate again
  /// when the chat is rebuilt (e.g. after listening).
  int _staticBelow = 0;

  /// Times the chat has been entered; the greeting streams only the first.
  int _chatEntries = 0;

  // Listening demo.
  Timer? _transcribe;
  String _transcript = '';

  @override
  void dispose() {
    _transcribe?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Avatar letters, as in the design: the first two letters of the first
  /// name ("Bo Mohamed" → "BO").
  String get _initials {
    final first = widget.userName.trim().split(' ').first;
    return first.substring(0, first.length.clamp(0, 2)).toUpperCase();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _typing) return;
    HapticFeedback.lightImpact();
    _input.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      if (_mode != _Mode.chat) {
        _staticBelow = _messages.length;
        _chatEntries++;
      }
      _mode = _Mode.chat;
      _messages.add(UserMessage(message));
      _typing = true;
    });
    _scrollToEnd();

    // Simulated thinking, then the reply arrives piece by piece; each text
    // part finishes streaming before the next one appears.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final reply = _engine.replyTo(message);
    for (final (i, part) in reply.indexed) {
      if (!mounted) return;
      setState(() {
        _messages.add(part);
        _typing = i < reply.length - 1;
      });
      _scrollToEnd();
      await Future<void>.delayed(switch (part) {
        AssistantText(:final lead, :final text) =>
          StreamingText.durationFor(lead, text) +
              const Duration(milliseconds: 250),
        _ => const Duration(milliseconds: 520),
      });
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startListening() {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = _Mode.listening;
      _transcript = '';
    });
    // Demo transcription (word by word) until speech recognition is
    // connected.
    final words = sampleVoiceRequest.split(' ');
    var shown = 0;
    _transcribe?.cancel();
    _transcribe = Timer.periodic(const Duration(milliseconds: 190), (timer) {
      if (shown >= words.length) {
        timer.cancel();
        _transcribe = Timer(
          const Duration(milliseconds: 900),
          _finishListening,
        );
        return;
      }
      shown++;
      setState(() => _transcript = words.take(shown).join(' '));
    });
  }

  /// Stops listening and sends what was heard.
  void _finishListening() {
    _transcribe?.cancel();
    final heard = _transcript;
    if (heard.isEmpty) {
      _leaveListening();
    } else {
      _send(heard);
    }
  }

  void _leaveListening() {
    _transcribe?.cancel();
    setState(() {
      if (_messages.isNotEmpty) {
        _staticBelow = _messages.length;
        _chatEntries++;
      }
      _mode = _messages.isEmpty ? _Mode.welcome : _Mode.chat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Drifting light behind everything; dimmer while chatting.
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _mode == _Mode.chat ? 0.35 : 1,
                duration: const Duration(milliseconds: 600),
                child: const Aurora(),
              ),
            ),
            SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: _Header(
                        name: widget.userName,
                        onBack: () => Navigator.of(context).pop(),
                        onCalendar: () =>
                            Navigator.of(context).pop(conciergeOpenCalendar),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(
                              begin: 0.96,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (_mode) {
                          _Mode.welcome => _Welcome(
                            key: const ValueKey(_Mode.welcome),
                            onSuggestion: _send,
                          ),
                          _Mode.chat => _Chat(
                            key: const ValueKey(_Mode.chat),
                            messages: _messages,
                            typing: _typing,
                            initials: _initials,
                            scroll: _scroll,
                            staticBelow: _staticBelow,
                            animateGreeting: _chatEntries <= 1,
                          ),
                          _Mode.listening => _Listening(
                            key: const ValueKey(_Mode.listening),
                            transcript: _transcript,
                          ),
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _mode == _Mode.listening
                            ? _ListeningControls(
                                key: const ValueKey('listening'),
                                onChat: _leaveListening,
                                onMic: _finishListening,
                              )
                            : _InputBar(
                                key: const ValueKey('input'),
                                controller: _input,
                                hint: _mode == _Mode.welcome
                                    ? 'AI Assistant'
                                    : 'Ask ...',
                                onMic: _startListening,
                                onSend: () => _send(_input.text),
                                thinking: _typing,
                              ),
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

// ---------------------------------------------------------------------------
// Header

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onBack,
    required this.onCalendar,
  });

  final String name;
  final VoidCallback onBack;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(onTap: onBack, child: const ArrowIcon()),
        const SizedBox(width: 4),
        _RoundButton(
          onTap: () {}, // TODO: open the concierge menu / history.
          child: const CustomPaint(
            size: Size.square(20),
            painter: _MenuIconPainter(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Hello, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
          ),
        ),
        _RoundButton(
          onTap: onCalendar,
          child: const TabIcon(TabGlyph.calendar, color: _ink, size: 22),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.onTap, required this.child});

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

// ---------------------------------------------------------------------------
// Orb

/// The glass Crystal orb: floats and breathes gently, with a slowly turning
/// sheen. While [listening], it pulses with (simulated) voice level and
/// sends rings outward.
class _Orb extends StatefulWidget {
  const _Orb({required this.size, this.listening = false});

  final double size;
  final bool listening;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final seconds = _clock.value * 12;
        final float = math.sin(seconds * 2 * math.pi / 4) * 6;
        // A lively, irregular "voice level" while listening.
        final level = widget.listening
            ? (math.sin(seconds * 9.1) * 0.5 +
                          math.sin(seconds * 13.7) * 0.3 +
                          math.sin(seconds * 5.3) * 0.2)
                      .abs() *
                  0.07
            : 0.0;
        final breathe = 1 + math.sin(seconds * 2 * math.pi / 4) * 0.012;

        return SizedBox.square(
          dimension: size * 1.45,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // A shockwave ring when the orb first appears.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                builder: (context, t, _) => t >= 1
                    ? const SizedBox.shrink()
                    : _PulseRing(progress: t, baseSize: size * 1.05),
              ),
              if (widget.listening) ...[
                for (var i = 0; i < 3; i++)
                  _PulseRing(
                    progress: (seconds / 1.8 + i / 3) % 1,
                    baseSize: size,
                  ),
                // Voice waveform hugging the orb.
                WaveformRing(
                  radius: size / 2,
                  time: seconds,
                  level: (level / 0.07).clamp(0.0, 1.0),
                ),
              ],
              Transform.translate(
                offset: Offset(0, widget.listening ? 0 : float),
                child: Transform.scale(scale: breathe + level, child: child),
              ),
              Transform.translate(
                offset: Offset(0, widget.listening ? 0 : float),
                child: OrbitSparkles(radius: size / 2, time: seconds),
              ),
            ],
          ),
        );
      },
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/concierge/orb.png'),
            ),
            // Slowly turning sheen to keep the glass alive.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        transform: GradientRotation(_clock.value * 2 * math.pi),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.08, 0.18, 1],
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

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress, required this.baseSize});

  final double progress;
  final double baseSize;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    final size = baseSize * (0.95 + 0.45 * eased);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35 * (1 - progress)),
          width: 2,
        ),
        color: AppColors.primary.withValues(alpha: 0.05 * (1 - progress)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                ),
                child: const _Orb(size: 200),
              ),
              const FadeSlideIn(
                delay: Duration(milliseconds: 250),
                child: Text(
                  'Weather-aware home services',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Narrow box so it breaks into three balanced lines:
              // "Tell me what needs / cleaning, I'll handle / the rest".
              // Words rise out of a blur one after another.
              const SizedBox(
                width: 250,
                child: WordReveal(
                  'Tell me what needs cleaning, I’ll handle the rest',
                  delay: Duration(milliseconds: 380),
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const FadeSlideIn(
                delay: Duration(milliseconds: 450),
                child: Text(
                  'Quick Suggestions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Each row scrolls on its own.
              for (final (row, items) in quickSuggestions.indexed) ...[
                if (row > 0) const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      for (final (i, label) in items.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        FadeSlideIn(
                          delay: Duration(
                            milliseconds: 520 + (row * 3 + i) * 70,
                          ),
                          child: _SuggestionChip(
                            label: label,
                            onTap: () => onSuggestion(label),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: const Color(0xFFF9FAFB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFF1F2F4)),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat

class _Chat extends StatelessWidget {
  const _Chat({
    super.key,
    required this.messages,
    required this.typing,
    required this.initials,
    required this.scroll,
    required this.staticBelow,
    required this.animateGreeting,
  });

  final List<ConciergeMessage> messages;
  final bool typing;
  final String initials;
  final ScrollController scroll;

  /// Messages below this index show without animating.
  final int staticBelow;
  final bool animateGreeting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      children: [
        _Appear(
          animate: animateGreeting,
          child: _AssistantBubble(
            animate: animateGreeting,
            text: const AssistantText(
              'Hi 👋 i\'m your home concierge. Ask me anything about '
              'cleaning, or the weather around.',
            ),
          ),
        ),
        for (final (i, message) in messages.indexed)
          _Appear(
            key: ValueKey(i),
            animate: i >= staticBelow,
            // Your messages rise from the input bar on the right.
            fromInput: message is UserMessage,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: switch (message) {
                UserMessage(:final text) => _UserBubble(
                  text: text,
                  initials: initials,
                ),
                AssistantText() => _AssistantBubble(
                  text: message,
                  animate: i >= staticBelow,
                ),
                WeatherReport() => _WeatherCard(report: message),
                ServiceOffers(:final offers) => _OfferCarousel(offers: offers),
              },
            ),
          ),
        if (typing)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: _Appear(child: _TypingBubble()),
          ),
      ],
    );
  }
}

/// Slides and fades a new message in once ([animate] off shows it as is).
/// [fromInput] messages rise further, from the input bar, growing out of
/// their bottom-right corner.
class _Appear extends StatelessWidget {
  const _Appear({
    super.key,
    required this.child,
    this.animate = true,
    this.fromInput = false,
  });

  final Widget child;
  final bool animate;
  final bool fromInput;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: fromInput ? 520 : 420),
      curve: fromInput ? Curves.easeOutBack : Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (fromInput ? 60 : 18) * (1 - t)),
          child: Transform.scale(
            scale: (fromInput ? 0.85 : 0.97) + (fromInput ? 0.15 : 0.03) * t,
            alignment: fromInput
                ? Alignment.bottomRight
                : Alignment.bottomCenter,
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/concierge/orb.png',
      width: 34,
      height: 34,
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text, this.animate = true});

  final AssistantText text;

  /// Stream the text in word by word.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BotAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _bubble,
                borderRadius: BorderRadius.circular(22),
              ),
              child: StreamingText(
                lead: text.lead,
                text: text.text,
                animate: animate,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.3,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.initials});

  final String text;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _bubble,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14.5, color: _ink),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF5FE),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots bouncing in turn while the assistant "thinks".
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

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
        children: [
          // The orb glows and pulses while the assistant thinks.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final g = math.sin(_controller.value * 2 * math.pi) * 0.5 + 0.5;
              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2 + 0.3 * g),
                      blurRadius: 8 + 10 * g,
                      spreadRadius: 1 + 2 * g,
                    ),
                  ],
                ),
                child: Transform.scale(scale: 1 + 0.06 * g, child: child),
              );
            },
            child: const _BotAvatar(),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _bubble,
              borderRadius: BorderRadius.circular(22),
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
                        -4 *
                            math
                                .sin(
                                  ((_controller.value - i * 0.15) % 1) *
                                      math.pi,
                                )
                                .clamp(0.0, 1.0),
                      ),
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
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

// ---------------------------------------------------------------------------
// Weather card

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF15161F),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      color: Color(0xFFC9CCD3),
                    ),
                  ),
                ),
                Text(
                  report.alert,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF2C063),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (i, day) in report.days.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    // Tiles pop in one after another.
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 450 + i * 140),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) {
                        final local = ((t * (450 + i * 140) - i * 140) / 450)
                            .clamp(0.0, 1.2);
                        return Opacity(
                          opacity: local.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.7 + 0.3 * local,
                            child: child,
                          ),
                        );
                      },
                      child: _WeatherTile(day: day),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherTile extends StatelessWidget {
  const _WeatherTile({required this.day});

  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final best = day.best;
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: best ? null : const Color(0xFF21242C),
        gradient: best
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFEC783), Color(0xFFFCA35B)],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            day.label,
            style: TextStyle(
              fontSize: 11,
              color: best ? const Color(0xFF3B2A12) : const Color(0xFFC9CCD3),
            ),
          ),
          SizedBox(
            height: 26,
            child: switch (day.kind) {
              WeatherKind.sand => const _Sway(
                child: Image(
                  image: AssetImage('assets/images/concierge/weather_sand.png'),
                ),
              ),
              WeatherKind.dustSun => const _Sway(
                distance: 2,
                child: Image(
                  image: AssetImage(
                    'assets/images/concierge/weather_dust_sun.png',
                  ),
                ),
              ),
              WeatherKind.sunny => const _Sun(),
            },
          ),
          // Temperatures count up.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: day.temperature.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '${value.round()}°',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: best ? const Color(0xFF3B2A12) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small glowing sun that slowly pulses.
class _Sun extends StatefulWidget {
  const _Sun();

  @override
  State<_Sun> createState() => _SunState();
}

class _SunState extends State<_Sun> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFF1A8), Color(0xFFFFC21C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD34D).withValues(alpha: 0.8),
              blurRadius: 8 + 6 * _pulse.value,
              spreadRadius: 1 + 2 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bookable services

class _OfferCarousel extends StatelessWidget {
  const _OfferCarousel({required this.offers});

  final List<ServiceOffer> offers;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 196 * textScale.clamp(1.0, 1.3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: offers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 480 + i * 120),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(60 * (1 - t), 0),
              child: child,
            ),
          ),
          child: _OfferCard(offer: offers[i]),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final ServiceOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 316,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _bubble,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  offer.image,
                  width: 52,
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
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${offer.category} - ${offer.minutes}mins',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA4A4A4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              RatingChip(
                rating: offer.rating,
                reviews: offer.reviews,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offer.provider,
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
                '${offer.price}QAR',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BookButton(onBooked: HapticFeedback.heavyImpact),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listening

class _Listening extends StatelessWidget {
  const _Listening({super.key, required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Orb(size: 210, listening: true),
        const Text(
          'Listening...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            clipBehavior: Clip.none,
            child: _TranscriptWords(transcript),
          ),
        ),
      ],
    );
  }
}

class _ListeningControls extends StatelessWidget {
  const _ListeningControls({
    super.key,
    required this.onChat,
    required this.onMic,
  });

  final VoidCallback onChat;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: onChat,
                borderRadius: BorderRadius.circular(22),
                child: const SizedBox(
                  width: 58,
                  height: 58,
                  child: Center(
                    child: CustomPaint(
                      size: Size.square(33),
                      painter: _ChatIconPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _MicOrb(size: 50, active: true, onTap: onMic),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input

/// The galaxy mic button; glows and breathes while [active].
class _MicOrb extends StatefulWidget {
  const _MicOrb({required this.size, required this.onTap, this.active = false});

  final double size;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final g = Curves.easeInOut.transform(_glow.value);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A4DFF).withValues(
                    alpha: widget.active ? 0.25 + 0.25 * g : 0.12 * g,
                  ),
                  blurRadius: widget.active ? 14 + 10 * g : 10,
                  spreadRadius: widget.active ? 1 + 3 * g : 0,
                ),
              ],
            ),
            child: Transform.scale(
              scale: widget.active ? 1 + 0.05 * g : 1,
              child: child,
            ),
          );
        },
        child: Image.asset(
          'assets/images/concierge/mic_orb.png',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onMic,
    required this.onSend,
    this.thinking = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onMic;
  final VoidCallback onSend;

  /// Shows a rotating iridescent border while the assistant is working.
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return IridescentBorder(
      active: thinking,
      radius: 29,
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _inputFill,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Row(
          children: [
            _MicOrb(size: 46, onTap: onMic),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15, color: _ink),
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PressScale(
              scale: 0.9,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onSend,
                  borderRadius: BorderRadius.circular(20),
                  child: const SizedBox(
                    height: 46,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Center(child: ArrowIcon(forward: true)),
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

/// Gentle horizontal drift, like sand carried by the wind.
class _Sway extends StatefulWidget {
  const _Sway({required this.child, this.distance = 3});

  final Widget child;
  final double distance;

  @override
  State<_Sway> createState() => _SwayState();
}

class _SwayState extends State<_Sway> with SingleTickerProviderStateMixin {
  late final AnimationController _wind = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _wind.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wind,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          widget.distance * Curves.easeInOut.transform(_wind.value) -
              widget.distance / 2,
          0,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// The heard words, each rising out of a blur as it arrives.
class _TranscriptWords extends StatelessWidget {
  const _TranscriptWords(this.transcript);

  final String transcript;

  static const _style = TextStyle(fontSize: 14.5, height: 1.35, color: _muted);

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) return const SizedBox.shrink();
    final words = transcript.split(' ');
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '“', style: _style),
          for (final (i, word) in words.indexed) ...[
            if (i > 0) const TextSpan(text: ' ', style: _style),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(i),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - t)),
                    child: t < 1
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 4 * (1 - t),
                              sigmaY: 4 * (1 - t),
                            ),
                            child: child,
                          )
                        : child,
                  ),
                ),
                child: Text(word, style: _style),
              ),
            ),
          ],
          const TextSpan(text: '”', style: _style),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Menu icon from the design (ci menu-alt-04): two long lines and a short
/// top one.
class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter();

  static final _path = parseSvgPath('M5 17H19M5 12H19M5 7H13');

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / 24)
      ..drawPath(
        _path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _ink,
      );
  }

  @override
  bool shouldRepaint(_MenuIconPainter old) => false;
}

/// Two overlapping speech bubbles (arcticons google-messages), drawn in
/// code with the design's thin stroke.
class _ChatIconPainter extends CustomPainter {
  const _ChatIconPainter();

  static final _back = parseSvgPath(
    'M11.55 20.1341C7.25519 20.1341 3.78125 16.4697 3.78125 11.9577C3.78125 '
    '7.44562 7.25519 3.78125 11.55 3.78125H19.6329C23.9277 3.78125 27.4017 '
    '7.44562 27.4017 11.9577C27.4017 16.4697 23.9277 20.1341 19.6329 '
    '20.1341H11.55Z',
  );
  static final _front = parseSvgPath(
    'M16.7886 23.4382V28.424C16.7886 28.8571 16.4393 29.2187 16.0206 '
    '29.2187C15.9192 29.2179 15.8189 29.1966 15.7259 29.1562C15.6328 29.1158 '
    '15.5488 29.0571 15.4789 28.9836L7.90264 21.1805C6.41833 19.6625 5.59814 '
    '17.5849 5.59814 15.4357C5.59814 11.0096 9.07208 7.41467 13.3669 '
    '7.41467H21.4498C25.7446 7.41467 29.2186 11.0103 29.2186 15.4357C29.2186 '
    '19.8612 25.7446 23.4561 21.4498 23.4561H16.7886V23.4382Z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    canvas
      ..scale(size.width / 33)
      ..drawPath(_back, stroke)
      ..drawPath(_front, stroke);
  }

  @override
  bool shouldRepaint(_ChatIconPainter old) => false;
}
