import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Blue pill with a star, the rating and the review count, e.g.
/// "★ 4.9 (2.1k)".
class RatingChip extends StatelessWidget {
  const RatingChip({
    super.key,
    required this.rating,
    required this.reviews,
    this.compact = false,
  });

  final double rating;

  /// Review count label, e.g. "2.1k".
  final String reviews;

  /// Smaller text (12 / 10, semibold), for dense cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: compact ? 15 : 17,
            ),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 15,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($reviews)',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 11,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
