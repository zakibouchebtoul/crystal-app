import 'package:flutter/material.dart';

import 'svg_path.dart';

/// Icons from the design's SVG files, drawn in code at their native sizes.
enum ChatGlyph {
  /// famicons call-outline, 24.
  call,

  /// bi mic, 24.
  mic,

  /// codex file (paper clip), 26.
  attach,

  /// bi three-dots-vertical, 16.
  dots,
}

class ChatIcon extends StatelessWidget {
  const ChatIcon(this.glyph, {super.key, this.color});

  final ChatGlyph glyph;

  /// Overrides the design's color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = _icons[glyph]!;
    return CustomPaint(
      size: Size.square(icon.size),
      painter: _ChatIconPainter(icon, color ?? icon.color),
    );
  }
}

class _Icon {
  const _Icon({
    required this.size,
    required this.path,
    required this.color,
    this.strokeWidth,
  });

  final double size;
  final Path path;
  final Color color;

  /// Drawn as an outline when set; filled otherwise.
  final double? strokeWidth;
}

class _ChatIconPainter extends CustomPainter {
  const _ChatIconPainter(this.icon, this.color);

  final _Icon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / icon.size);
    final paint = Paint()..color = color;
    if (icon.strokeWidth case final width?) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(icon.path, paint);
  }

  @override
  bool shouldRepaint(_ChatIconPainter old) =>
      old.icon != icon || old.color != color;
}

const _ink = Color(0xFF0D0D12);
const _slate = Color(0xFF6A7B89);

final _icons = {
  ChatGlyph.call: _Icon(
    size: 24,
    color: _ink,
    strokeWidth: 1,
    path: parseSvgPath(
      'M21.1404 17.5313C20.396 16.7813 18.5932 15.6867 17.7185 15.2456C16.5795 '
      '14.6719 16.4857 14.625 15.5904 15.2902C14.9932 15.7341 14.5962 16.1306 '
      '13.8973 15.9816C13.1984 15.8325 11.6796 14.992 10.3498 13.6664C9.01994 '
      '12.3408 8.13072 10.778 7.98119 10.0814C7.83166 9.38485 8.23478 8.9925 '
      '8.67447 8.39391C9.29415 7.55016 9.24728 7.40953 8.71759 6.27047C8.30462 '
      '5.38453 7.17822 3.59859 6.42541 2.85797C5.62009 2.0625 5.62009 2.20313 '
      '5.10119 2.41875C4.67872 2.59646 4.27343 2.81252 3.89041 3.06422C3.14041 '
      '3.5625 2.72416 3.97641 2.43306 4.59844C2.14197 5.22047 2.01119 6.67875 '
      '3.51447 9.40969C5.01775 12.1406 6.07244 13.537 8.2554 15.7139C10.4384 '
      '17.8908 12.117 19.0613 14.5709 20.4375C17.6065 22.1377 18.7709 21.8063 '
      '19.3948 21.5156C20.0187 21.225 20.4345 20.8125 20.9337 20.0625C21.186 '
      '19.6801 21.4026 19.2753 21.5806 18.8531C21.7967 18.3361 21.9373 '
      '18.3361 21.1404 17.5313Z',
    ),
  ),
  ChatGlyph.mic: _Icon(
    size: 24,
    color: _slate,
    path:
        parseSvgPath(
          'M5.25 9.75C5.44891 9.75 5.63968 9.82902 5.78033 9.96967C5.92098 '
          '10.1103 6 10.3011 6 10.5V12C6 13.5913 6.63214 15.1174 7.75736 '
          '16.2426C8.88258 17.3679 10.4087 18 12 18C13.5913 18 15.1174 '
          '17.3679 16.2426 16.2426C17.3679 15.1174 18 13.5913 18 12V10.5C18 '
          '10.3011 18.079 10.1103 18.2197 9.96967C18.3603 9.82902 18.5511 '
          '9.75 18.75 9.75C18.9489 9.75 19.1397 9.82902 19.2803 '
          '9.96967C19.421 10.1103 19.5 10.3011 19.5 10.5V12C19.5 13.8593 '
          '18.8094 15.6523 17.5622 17.0312C16.3149 18.4101 14.6 19.2766 '
          '12.75 19.4625V22.5H17.25C17.4489 22.5 17.6397 22.579 17.7803 '
          '22.7197C17.921 22.8603 18 23.0511 18 23.25C18 23.4489 17.921 '
          '23.6397 17.7803 23.7803C17.6397 23.921 17.4489 24 17.25 '
          '24H6.75C6.55109 24 6.36032 23.921 6.21967 23.7803C6.07902 23.6397 '
          '6 23.4489 6 23.25C6 23.0511 6.07902 22.8603 6.21967 '
          '22.7197C6.36032 22.579 6.55109 22.5 6.75 22.5H11.25V19.4625C9.40003 '
          '19.2766 7.68506 18.4101 6.43782 17.0312C5.19058 15.6523 4.49998 '
          '13.8593 4.5 12V10.5C4.5 10.3011 4.57902 10.1103 4.71967 '
          '9.96967C4.86032 9.82902 5.05109 9.75 5.25 9.75Z',
        )..addPath(
          parseSvgPath(
            'M15 12C15 12.7956 14.6839 13.5587 14.1213 14.1213C13.5587 '
            '14.6839 12.7956 15 12 15C11.2044 15 10.4413 14.6839 9.87868 '
            '14.1213C9.31607 13.5587 9 12.7956 9 12V4.5C9 3.70435 9.31607 '
            '2.94129 9.87868 2.37868C10.4413 1.81607 11.2044 1.5 12 '
            '1.5C12.7956 1.5 13.5587 1.81607 14.1213 2.37868C14.6839 2.94129 '
            '15 3.70435 15 4.5V12ZM12 0C10.8065 0 9.66193 0.474106 8.81802 '
            '1.31802C7.97411 2.16193 7.5 3.30653 7.5 4.5V12C7.5 13.1935 '
            '7.97411 14.3381 8.81802 15.182C9.66193 16.0259 10.8065 16.5 12 '
            '16.5C13.1935 16.5 14.3381 16.0259 15.182 15.182C16.0259 14.3381 '
            '16.5 13.1935 16.5 12V4.5C16.5 3.30653 16.0259 2.16193 15.182 '
            '1.31802C14.3381 0.474106 13.1935 0 12 0Z',
            evenOdd: true,
          ),
          Offset.zero,
        ),
  ),
  ChatGlyph.attach: _Icon(
    size: 26,
    color: _slate,
    strokeWidth: 2,
    path: parseSvgPath(
      'M14.4344 9.13899L10.2864 13.2058C9.89203 13.5958 9.67537 14.1288 9.68403 '
      '14.6889C9.69585 15.2555 9.92919 15.7949 10.334 16.1915C10.7403 16.5934 '
      '11.2874 16.8242 11.8539 16.8339C12.1313 16.8397 12.407 16.79 12.6649 '
      '16.6877C12.9228 16.5854 13.1576 16.4325 13.3554 16.2381L17.5024 '
      '12.1712C17.8937 11.7842 18.2022 11.3217 18.4093 10.8118C18.6164 '
      '10.3019 18.7177 9.7553 18.7071 9.20508C18.6843 8.07182 18.2184 6.9926 '
      '17.4093 6.19883C16.5979 5.39592 15.5086 4.93621 14.3673 '
      '4.91508C13.8131 4.90402 13.2624 5.00351 12.7471 5.20775C12.2319 '
      '5.41199 11.7625 5.71687 11.3664 6.10458L7.2162 10.1725C6.6298 10.7533 '
      '6.16738 11.4471 5.85697 12.2119C5.54655 12.9767 5.39459 13.7965 '
      '5.41028 14.6217C5.44517 16.3212 6.1444 17.9394 7.35812 '
      '19.1295C8.57455 20.3335 10.2077 21.0233 11.9189 21.0557C12.7505 '
      '21.073 13.5771 20.9242 14.3504 20.618C15.1237 20.3118 15.8281 19.8544 '
      '16.4224 19.2725L20.5704 15.2035',
    ),
  ),
  ChatGlyph.dots: _Icon(
    size: 16,
    color: _ink,
    path: Path()
      ..addOval(Rect.fromCircle(center: const Offset(8, 3), radius: 1.5))
      ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 1.5))
      ..addOval(Rect.fromCircle(center: const Offset(8, 13), radius: 1.5)),
  ),
};
