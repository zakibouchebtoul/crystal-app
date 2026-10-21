import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'search_icon.dart';

/// Search box with the icon and [hint] centered; both glide away as soon as
/// it's tapped, and come back if it's left empty.
class CenteredSearch extends StatefulWidget {
  const CenteredSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<CenteredSearch> createState() => _CenteredSearchState();
}

class _CenteredSearchState extends State<CenteredSearch> {
  static const _muted = Color(0xFFB3BCC3);

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPlaceholder = !_focus.hasFocus && widget.controller.text.isEmpty;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // On focus the placeholder glides from the center towards the
            // leading edge while fading and shrinking away; it glides back
            // when the box is left empty.
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: showPlaceholder ? 0 : 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, hidden, child) => Align(
                    alignment: Alignment.lerp(
                      Alignment.center,
                      Alignment.centerLeft,
                      hidden,
                    )!,
                    child: Opacity(
                      opacity: (1 - hidden * 1.4).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 - 0.08 * hidden,
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SearchIcon(),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13, color: Colors.black),
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ],
        ),
      ),
    );
  }
}
