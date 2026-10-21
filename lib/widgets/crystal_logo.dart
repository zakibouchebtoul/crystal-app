import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// The Crystal logo (diamond, wave and wordmark) in a single [color].
/// Built from the white logo pieces, so it stays sharp at any [width].
///
/// [reveal] (0–1) plays a small entrance: the diamond pops in, the wave
/// draws from left to right, then the wordmark wipes in. 1 = fully shown.
class CrystalLogo extends StatelessWidget {
  const CrystalLogo({
    super.key,
    this.width = 90,
    this.color = AppColors.primary,
    this.reveal = 1,
  });

  final double width;
  final Color color;
  final double reveal;

  double _step(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((reveal - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    // Positions in "logo units": the logo is a 234 × 161 box.
    final k = width / 234;
    final diamond = _step(0, 0.45, Curves.easeOutBack);
    final wave = _step(0.25, 0.7, Curves.easeInOutCubic);
    final text = _step(0.45, 1, Curves.easeOutCubic);

    return SizedBox(
      width: width,
      height: 161 * k,
      child: Stack(
        children: [
          Positioned(
            left: 57.7 * k,
            top: 74.1 * k,
            width: 148.4 * k,
            child: ClipRect(
              clipper: _LeftReveal(wave),
              child: Image.asset(
                'assets/images/crystal_wave.png',
                color: color,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 110.7 * k,
            width: width,
            child: _Wipe(
              progress: text,
              child: Image.asset(
                'assets/images/crystal_text.png',
                color: color,
              ),
            ),
          ),
          Positioned(
            left: 70.5 * k,
            top: 0,
            width: 107 * k,
            child: Opacity(
              opacity: diamond.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.4 + 0.6 * diamond,
                child: Image.asset(
                  'assets/images/crystal_diamond.png',
                  color: color,
                ),
              ),
            ),
          ),
        ],
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

/// Clips to the left [progress] fraction of the child.
class _LeftReveal extends CustomClipper<Rect> {
  const _LeftReveal(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_LeftReveal old) => old.progress != progress;
}
