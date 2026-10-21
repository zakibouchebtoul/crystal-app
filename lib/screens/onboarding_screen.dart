import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../widgets/slide_to_start.dart';
import '../widgets/doodle_background.dart';
import 'login_screen.dart';

/// Welcome slides shown after the splash. The first slides have a "Next"
/// button and page dots; the last one replaces them with "Start Now".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Loads the slide photos ahead of time so they appear without a flash.
  static void precache(BuildContext context) {
    for (final image in [
      for (final slide in _slides) slide.image,
      ...DoodleBackground.preload,
    ]) {
      precacheImage(AssetImage(image), context);
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The mockups are drawn on a 402 × 874 screen; layout values below that
/// come from them are expressed in that reference size.
const _designHeight = 874.0;

/// Space between the bottom of the screen (above the home indicator) and
/// the page dots.
const _bottomGap = 37.0;

/// Height of the bottom controls: Next button (44) + gap (20) + dots (6).
const _controlsHeight = 70.0;

class _Slide {
  const _Slide({
    required this.image,
    required this.titleBold,
    required this.titleLight,
    required this.titleLine2,
    required this.body,
    required this.imageTop,
    required this.imageBottom,
    this.imageWidth = 1,
  });

  final String image;
  final String titleBold;
  final String titleLight;
  final String titleLine2;
  final String body;

  /// Where the photo starts and ends in the 874-tall mockup.
  final double imageTop;
  final double imageBottom;

  /// Photo width as a fraction of the screen width.
  final double imageWidth;
}

const _slides = [
  _Slide(
    image: 'assets/images/onboarding/cleaning.jpg',
    titleBold: 'A Cleaner',
    titleLight: ' Home',
    titleLine2: 'Starts Here Cleaning',
    body:
        'From quick touch-ups to deep cleaning, our verified professionals '
        'deliver reliable',
    imageTop: 88,
    imageBottom: 615,
    imageWidth: 0.965,
  ),
  _Slide(
    image: 'assets/images/onboarding/pet.jpg',
    titleBold: 'A Happier',
    titleLight: ' Pet',
    titleLine2: 'Starts Here',
    body: 'Professional grooming, bathing & styling — your pet will love it',
    imageTop: -4,
    imageBottom: 597,
  ),
  _Slide(
    image: 'assets/images/onboarding/car.jpg',
    titleBold: 'A Shinier',
    titleLight: ' Ride',
    titleLine2: 'Starts Here Cleaning',
    body:
        'From express wash to deep detailing, we make your car look '
        'brand new.',
    imageTop: 10,
    imageBottom: 678,
  ),
  _Slide(
    image: 'assets/images/onboarding/appliance.jpg',
    titleBold: 'Sparkling',
    titleLight: ' Appliances',
    titleLine2: 'Starts Here',
    body:
        'Expert deep cleaning that restores shine without damaging your '
        'electronics',
    imageTop: 88,
    imageBottom: 630,
    imageWidth: 0.985,
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Current scroll position in pages (e.g. 1.5 = halfway between 2 and 3).
  double get _page =>
      _controller.hasClients && _controller.position.haveDimensions
      ? _controller.page!
      : _controller.initialPage.toDouble();

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Opens the sign-in screen as a circle growing from [origin] (the end of
  /// the Start Now button).
  void _finish(Offset origin) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) => ClipPath(
          clipper: _CircleRevealClipper(
            origin: origin,
            progress: Curves.easeInOutCubic.transform(animation.value),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + _bottomGap;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 0 on the first slides, 1 on the last: cross-fades the controls.
            final lastPageProgress = (_page - (_slides.length - 2)).clamp(
              0.0,
              1.0,
            );
            return Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) => _SlidePage(
                    slide: _slides[index],
                    offset: _page - index,
                    bottomInset: bottomInset,
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 37),
                      child: _fadeOut(
                        lastPageProgress,
                        _SkipButton(onPressed: () => _goTo(_slides.length - 1)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 37,
                  right: 37,
                  bottom: bottomInset,
                  height: _controlsHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _fadeOut(
                        lastPageProgress,
                        Column(
                          children: [
                            _NextButton(
                              onPressed: () => _goTo(_page.round() + 1),
                            ),
                            const Spacer(),
                            _PageDots(count: _slides.length - 1, page: _page),
                          ],
                        ),
                      ),
                      Positioned(
                        left: -10,
                        right: -10,
                        top: -8,
                        child: _fadeOut(
                          1 - lastPageProgress,
                          SlideToStart(
                            label: 'Start Now',
                            onCompleted: _finish,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Fades [child] out as [progress] goes 0 → 1, and stops it from taking
  /// taps once it's mostly hidden.
  Widget _fadeOut(double progress, Widget child) {
    return IgnorePointer(
      ignoring: progress > 0.5,
      child: Opacity(opacity: 1 - progress, child: child),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({
    required this.slide,
    required this.offset,
    required this.bottomInset,
  });

  final _Slide slide;

  /// How far this slide is from the center: 0 = fully shown, ±1 = one page
  /// away. Drives the text slide and fade.
  final double offset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textOpacity = (1 - offset.abs() * 1.6).clamp(0.0, 1.0);

    // Clip so nothing from this slide draws over its neighbours mid-swipe.
    return ClipRect(
      child: Stack(
        children: [
          // Photo: moves together with its page.
          Positioned(
            top: slide.imageTop / _designHeight * size.height,
            bottom: _designHeight - slide.imageBottom,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: slide.imageWidth,
                // Fade the photo's edges into the page background.
                child: _EdgeFade(
                  axis: Axis.vertical,
                  stops: const [0, 0.04, 0.94, 1],
                  child: _EdgeFade(
                    axis: Axis.horizontal,
                    stops: const [0, 0.05, 0.95, 1],
                    child: Image.asset(slide.image, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          // Text: moves a little faster than the page and fades out.
          Positioned(
            left: 28,
            right: 28,
            bottom: bottomInset + _controlsHeight + 20,
            child: Opacity(
              opacity: textOpacity,
              child: Transform.translate(
                offset: Offset(-offset * size.width * 0.25, 0),
                child: _SlideText(slide: slide),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades [child] to transparent at both ends of [axis].
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.axis,
    required this.stops,
    required this.child,
  });

  final Axis axis;
  final List<double> stops;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: const [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: stops,
      ).createShader(rect),
      child: child,
    );
  }
}

class _SlideText extends StatelessWidget {
  const _SlideText({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 32,
      height: 1.25,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: titleStyle,
            children: [
              TextSpan(text: slide.titleBold),
              TextSpan(
                text: slide.titleLight,
                style: const TextStyle(fontWeight: FontWeight.w300),
              ),
              TextSpan(text: '\n${slide.titleLine2}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          slide.body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.25),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF5F7FB),
          foregroundColor: AppColors.primary,
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: const Text('Next'),
      ),
    );
  }
}

/// Pill-shaped page dots; the active one stretches smoothly while swiping.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 10 + 32 * (1 - (page - i).abs()).clamp(0.0, 1.0),
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Clips to a circle around [origin] that grows until it covers the screen.
class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  @override
  Path getClip(Size size) {
    // Distance to the farthest corner, so the circle ends fully covering.
    final maxRadius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    return Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxRadius * progress));
  }

  @override
  bool shouldReclip(_CircleRevealClipper old) =>
      old.progress != progress || old.origin != origin;
}
