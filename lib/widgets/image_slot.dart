import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Shows the image at [asset]; until that file is added to the project it
/// shows a placeholder naming the file and what it should show.
class ImageSlot extends StatelessWidget {
  const ImageSlot({
    super.key,
    required this.asset,
    required this.label,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.placeholderAlignment = Alignment.center,
    this.fallback,
  });

  final String asset;

  /// What the image should show, e.g. "Hero photo".
  final String label;
  final BoxFit fit;

  /// Icon only (for small slots such as avatars).
  final bool compact;

  /// Where the placeholder's label sits.
  final Alignment placeholderAlignment;

  /// Shown instead of the upload placeholder while the file is missing.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, _, _) =>
          fallback ??
          _Placeholder(
            label: label,
            file: asset.split('/').last,
            compact: compact,
            alignment: placeholderAlignment,
          ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.label,
    required this.file,
    required this.compact,
    required this.alignment,
  });

  final String label;
  final String file;
  final bool compact;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF3FF), Color(0xFFF5F8FC)],
        ),
      ),
      child: Align(
        alignment: alignment,
        child: compact
            ? const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary,
                size: 20,
              )
            : Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        file,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6A7B89),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
