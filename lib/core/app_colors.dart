import 'package:flutter/material.dart';

/// Brand colors for Crystal.
abstract final class AppColors {
  static const primary = Color(0xFF0277F6);

  /// Headings and main text.
  static const ink = Color(0xFF0D0D12);

  /// Light blue tint behind blue text and icons (tags, chips).
  static const tint = Color(0xFFEFF5FE);

  /// Hairline border on white cards.
  static const border = Color(0xFFF1F2F4);

  /// Warm accent for highlights: "Most booked", offers, the bell.
  static const accent = Color(0xFFFF9500);
  static const accentDeep = Color(0xFFDB6E00);

  /// Light warm tint behind accent text.
  static const accentTint = Color(0xFFFFF0DE);

  /// Secondary text (hints under titles, legal copy).
  static const textMuted = Color(0xFF8D9AA5);

  /// Icons and labels on unselected surfaces.
  static const iconMuted = Color(0xFF6A7B89);

  /// Input fields and unselected cards.
  static const surface = Color(0xFFE4E7EA);

  /// Light fill for chips, search and tiles on white screens (looks like
  /// [surface] at 30% on white).
  static const fill = Color(0xFFF7F8F9);

  /// Badges such as "Most booked" and "School Offers".
  static const badge = Color(0xFFF10000);

  /// Unselected bottom-navigation items.
  static const navInactive = Color(0xFFA3ABB3);

  /// Placeholder text inside inputs.
  static const placeholder = Color(0xFFC7CED3);

  /// Thin decorative outlines on white screens.
  static const doodle = Color.fromARGB(126, 209, 209, 209);
}
