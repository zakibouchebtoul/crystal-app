import 'package:flutter/material.dart';

import 'svg_path.dart';

/// Bottom-bar icons from the design (SVG paths), drawn in a [size] box so
/// their color can follow the sliding selection smoothly.
enum TabGlyph { home, calendar, concierge, messages, profile }

class TabIcon extends StatelessWidget {
  const TabIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.selected = false,
    this.size = 24,
  });

  final TabGlyph glyph;
  final Color color;

  /// Selected tabs use the filled variant where the design has one.
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TabIconPainter(_icons[glyph]!.variant(selected), color),
    );
  }
}

/// One drawable icon: SVG paths in a viewBox, filled or stroked.
class _SvgIcon {
  const _SvgIcon(
    this.viewBox,
    this.paths, {
    this.stroked = false,
    this.strokeWidth = 1,
  });

  final Size viewBox;
  final List<Path> paths;

  /// Drawn as outlines ([strokeWidth] in viewBox units) rather than filled.
  final bool stroked;
  final double strokeWidth;
}

/// Unselected and selected variants of a tab icon.
class _TabIconSet {
  const _TabIconSet(this.idle, [this.active]);

  final _SvgIcon idle;
  final _SvgIcon? active;

  _SvgIcon variant(bool selected) => selected ? (active ?? idle) : idle;
}

class _TabIconPainter extends CustomPainter {
  const _TabIconPainter(this.icon, this.color);

  final _SvgIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the viewBox into the box, centered, keeping its proportions.
    final scale = size.shortestSide / icon.viewBox.longestSide;
    canvas
      ..translate(
        (size.width - icon.viewBox.width * scale) / 2,
        (size.height - icon.viewBox.height * scale) / 2,
      )
      ..scale(scale);
    final paint = Paint()..color = color;
    if (icon.stroked) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = icon.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    for (final path in icon.paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.icon != icon || old.color != color;
}

// Paths copied from the design's SVG files.

final _home = _SvgIcon(const Size(25, 25), [
  parseSvgPath(
    'M21.6335 7.9219C21.3792 7.37758 20.9668 6.92251 20.45 6.61604L13.8493 '
    '2.53523C13.3652 2.23527 12.8069 2.07635 12.2374 2.07635C11.6679 2.07635 '
    '11.1096 2.23527 10.6255 2.53523L4.02476 6.61604C3.52439 6.93472 3.12741 '
    '7.39195 2.88213 7.93211C2.62733 8.47226 2.54198 9.07688 2.63728 '
    '9.66645L4.35122 19.8685C4.46113 20.5799 4.82324 21.2281 5.37143 '
    '21.6947C5.91527 22.1502 6.60045 22.4026 7.30982 22.4088H17.1242C17.8476 '
    '22.4121 18.5488 22.1591 19.1034 21.6947C19.6545 21.2305 20.0172 20.5811 '
    '20.1236 19.8685L21.8375 9.66645C21.9414 9.07749 21.8705 8.471 21.6335 '
    '7.9219ZM15.6551 17.8179H8.82992C8.55934 17.8179 8.29985 17.7104 8.10853 '
    '17.5191C7.9172 17.3277 7.80972 17.0683 7.80972 16.7977C7.80972 16.5271 '
    '7.9172 16.2676 8.10853 16.0763C8.29985 15.885 8.55934 15.7775 8.82992 '
    '15.7775H15.6551C15.9257 15.7775 16.1852 15.885 16.3765 16.0763C16.5678 '
    '16.2676 16.6753 16.5271 16.6753 16.7977C16.6753 17.0683 16.5678 17.3277 '
    '16.3765 17.5191C16.1852 17.7104 15.9257 17.8179 15.6551 17.8179Z',
  ),
]);

final _calendarOutline = _SvgIcon(const Size(24, 24), [
  parseSvgPath(
    'M18 4H6C3.79086 4 2 5.79086 2 8V18C2 20.2091 3.79086 22 6 22H18C20.2091 '
    '22 22 20.2091 22 18V8C22 5.79086 20.2091 4 18 4Z',
  ),
  parseSvgPath('M8 2V6M16 2V6M2 10H22'),
], stroked: true);

final _calendarFilled = _SvgIcon(const Size(24, 24), [
  parseSvgPath(
    'M22 15V13C22 12.161 22 11.415 21.987 10.75H2.013C2 11.415 2 12.161 2 '
    '13V15C2 18.771 2 20.657 3.172 21.828C4.344 22.999 6.229 23 10 23H14C17.771 '
    '23 19.657 23 20.828 21.828C21.999 20.656 22 18.771 22 15ZM7.75 3.5C7.75 '
    '3.30109 7.67098 3.11032 7.53033 2.96967C7.38968 2.82902 7.19891 2.75 7 '
    '2.75C6.80109 2.75 6.61032 2.82902 6.46967 2.96967C6.32902 3.11032 6.25 '
    '3.30109 6.25 3.5V5.08C4.81 5.195 3.866 5.477 3.172 6.172C2.477 6.866 '
    '2.195 7.811 2.079 9.25H21.921C21.805 7.81 21.523 6.866 20.828 6.172C20.134 '
    '5.477 19.189 5.195 17.75 5.079V3.5C17.75 3.30109 17.671 3.11032 17.5303 '
    '2.96967C17.3897 2.82902 17.1989 2.75 17 2.75C16.8011 2.75 16.6103 2.82902 '
    '16.4697 2.96967C16.329 3.11032 16.25 3.30109 16.25 3.5V5.013C15.585 5 '
    '14.839 5 14 5H10C9.161 5 8.415 5 7.75 5.013V3.5Z',
  ),
]);

final _concierge = _SvgIcon(const Size(24, 24), [
  parseSvgPath(
    'M9.205 8.658V6.398C9.205 6.208 9.277 6.065 9.443 5.97L13.986 3.354C14.605 '
    '2.997 15.342 2.831 16.103 2.831C18.957 2.831 20.765 5.043 20.765 '
    '7.397C20.765 7.564 20.765 7.754 20.741 7.944L16.031 5.185C15.903 5.10392 '
    '15.7545 5.06088 15.603 5.06088C15.4515 5.06088 15.303 5.10392 15.175 '
    '5.185L9.205 8.658ZM19.814 17.458V12.06C19.814 11.727 19.671 11.49 19.385 '
    '11.323L13.415 7.85L15.365 6.732C15.4355 6.68513 15.5183 6.66013 15.603 '
    '6.66013C15.6877 6.66013 15.7705 6.68513 15.841 6.732L20.384 9.349C21.693 '
    '10.109 22.573 11.727 22.573 13.297C22.573 15.105 21.503 16.77 19.813 '
    '17.46L19.814 17.458ZM7.802 12.703L5.852 11.561C5.77505 11.5204 5.71152 '
    '11.4584 5.66911 11.3824C5.62669 11.3064 5.6072 11.2198 5.613 '
    '11.133V5.899C5.613 3.354 7.563 1.427 10.204 1.427C11.204 1.427 12.131 '
    '1.76 12.916 2.355L8.23 5.067C7.945 5.233 7.802 5.471 7.802 '
    '5.804V12.703ZM12 15.128L9.205 13.558V10.228L12 8.658L14.795 '
    '10.228V13.558L12 15.128ZM13.796 22.358C12.796 22.358 11.869 22.026 11.084 '
    '21.431L15.77 18.719C16.055 18.553 16.198 18.315 16.198 17.982V11.084L18.172 '
    '12.226C18.339 12.321 18.41 12.464 18.41 12.654V17.887C18.41 20.432 16.436 '
    '22.358 13.796 22.358ZM8.159 17.055L3.615 14.438C2.307 13.677 1.427 12.06 '
    '1.427 10.49C1.42365 9.59786 1.68673 8.72504 2.18255 7.98336C2.67837 '
    '7.24169 3.38434 6.66493 4.21 6.327V11.75C4.21 12.083 4.353 12.321 4.638 '
    '12.488L10.585 15.937L8.635 17.055C8.56447 17.1019 8.48168 17.1269 8.397 '
    '17.1269C8.31232 17.1269 8.22953 17.1019 8.159 17.055ZM7.897 20.955C5.209 '
    '20.955 3.235 18.934 3.235 16.436C3.235 16.246 3.259 16.056 3.282 '
    '15.866L7.968 18.576C8.0956 18.6582 8.24419 18.702 8.396 18.702C8.54781 '
    '18.702 8.6964 18.6582 8.824 18.576L14.794 15.128V17.388C14.794 17.578 '
    '14.724 17.721 14.557 17.816L10.014 20.432C9.395 20.789 8.658 20.955 7.897 '
    '20.955ZM13.796 23.785C15.1664 23.7845 16.4947 23.3111 17.5563 '
    '22.4445C18.618 21.578 19.348 20.3715 19.623 19.029C22.287 18.339 24 15.84 '
    '24 13.296C24 11.631 23.287 10.014 22.002 8.848C22.121 8.348 22.192 7.849 '
    '22.192 7.35C22.192 3.949 19.433 1.403 16.246 1.403C15.6064 1.40012 '
    '14.9708 1.50492 14.366 1.713C13.2561 0.620228 11.7626 0.00535575 10.205 '
    '0C8.83445 0.000500422 7.50609 0.474136 6.44441 1.34087C5.38272 2.2076 '
    '4.6528 3.41428 4.378 4.757C1.713 5.447 0 7.945 0 10.49C0 12.156 0.713 '
    '13.773 1.998 14.938C1.879 15.438 1.808 15.938 1.808 16.437C1.808 19.838 '
    '4.567 22.383 7.754 22.383C8.396 22.383 9.014 22.288 9.634 22.074C10.7441 '
    '23.167 12.2381 23.7819 13.796 23.787V23.785Z',
    evenOdd: true,
  ),
]);

const _bubblePath =
    'M10.8333 0C4.86417 0 0 3.88917 0 8.66667C0 11.8192 2.05833 14.6358 '
    '5.41667 16.1742V19.5C5.41667 19.9117 5.64417 20.2908 6.0125 '
    '20.4642C6.16417 20.54 6.32667 20.5833 6.5 20.5833C6.7275 20.5833 6.955 '
    '20.5075 7.15 20.3667L11.2017 17.3333C17.0083 17.1817 21.6667 13.3467 '
    '21.6667 8.66667C21.6667 3.98667 16.8025 0 10.8333 0Z';

// The stroke is inset by drawing in a slightly larger box, so the outline
// isn't clipped at the edges.
final _messagesOutline = _SvgIcon(
  const Size(23.5, 22.5),
  [parseSvgPath(_bubblePath).shift(const Offset(0.9, 0.9))],
  stroked: true,
  strokeWidth: 1.3,
);

final _messagesFilled = _SvgIcon(const Size(22, 21), [
  parseSvgPath(_bubblePath),
]);

final _profile = _SvgIcon(const Size(20, 20), [
  parseSvgPath(
    'M9.99998 1.09873e-10C11.3132 -6.15562e-06 12.6136 0.258646 13.8268 '
    '0.76119C15.0401 1.26373 16.1425 2.00033 17.0711 2.92891C17.9997 3.8575 '
    '18.7363 4.95989 19.2388 6.17315C19.7414 7.3864 20 8.68676 20 '
    '9.99998C20 15.5228 15.5228 20 9.99998 20C4.47717 20 0 15.5228 0 '
    '9.99998C0 4.47717 4.47717 1.09873e-10 9.99998 1.09873e-10ZM11 11H9C6.5243 '
    '11 4.39884 12.4994 3.48211 14.6398C4.93261 16.6737 7.31142 18 9.99998 '
    '18C12.6885 18 15.0674 16.6737 16.5179 14.6396C15.6012 12.4994 13.4757 11 '
    '11 11ZM9.99998 3C8.34314 3 6.99998 4.34316 6.99998 6C6.99998 7.65684 '
    '8.34314 9 9.99998 9C11.6568 9 13 7.65684 13 6C13 4.34316 11.6569 3 '
    '9.99998 3Z',
    evenOdd: true,
  ),
]);

final _icons = {
  TabGlyph.home: _TabIconSet(_home),
  TabGlyph.calendar: _TabIconSet(_calendarOutline, _calendarFilled),
  TabGlyph.concierge: _TabIconSet(_concierge),
  TabGlyph.messages: _TabIconSet(_messagesOutline, _messagesFilled),
  TabGlyph.profile: _TabIconSet(_profile),
};
