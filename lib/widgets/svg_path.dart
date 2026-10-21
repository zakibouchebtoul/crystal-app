import 'dart:ui';

/// Parses SVG path data (the `d` attribute) into a [Path], so icons from
/// the design can be drawn without an SVG package.
///
/// Supports M, L, H, V, C, S, Q, T and Z in absolute and relative forms
/// (no arcs).
Path parseSvgPath(String data, {bool evenOdd = false}) {
  final tokens = RegExp(
    r'[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((m) => m.group(0)!).toList();

  final path = Path()
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  var i = 0;
  var command = '';
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? lastControl; // for S/T reflections
  var lastWasCubic = false;
  var lastWasQuad = false;

  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    final relative = command == command.toLowerCase();
    final base = relative ? current : Offset.zero;
    Offset point() {
      final x = next();
      final y = next();
      return base + Offset(x, y);
    }

    var cubic = false;
    var quad = false;
    switch (command.toUpperCase()) {
      case 'M':
        current = start = point();
        path.moveTo(current.dx, current.dy);
        // Further pairs after a move are implicit line-tos.
        command = relative ? 'l' : 'L';
      case 'L':
        current = point();
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset(next() + (relative ? current.dx : 0), current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(current.dx, next() + (relative ? current.dy : 0));
        path.lineTo(current.dx, current.dy);
      case 'C':
        final c1 = point();
        final c2 = point();
        final end = point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
        cubic = true;
      case 'S':
        final c1 = lastWasCubic && lastControl != null
            ? current * 2 - lastControl
            : current;
        final c2 = point();
        final end = point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastControl = c2;
        current = end;
        cubic = true;
      case 'Q':
        final c = point();
        final end = point();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastControl = c;
        current = end;
        quad = true;
      case 'T':
        final c = lastWasQuad && lastControl != null
            ? current * 2 - lastControl
            : current;
        final end = point();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastControl = c;
        current = end;
        quad = true;
      case 'Z':
        path.close();
        current = start;
      default:
        throw FormatException('Unsupported SVG path command: $command');
    }
    lastWasCubic = cubic;
    lastWasQuad = quad;
  }
  return path;
}
