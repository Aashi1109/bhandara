import 'package:flutter/material.dart';

void paintUserLocationMarker(Canvas canvas, double markerSize) {
  final scale = markerSize / 24;
  const offset = Offset.zero;

  final pinPath = Path()
    ..moveTo(offset.dx + (20 * scale), offset.dy + (10 * scale))
    ..cubicTo(
      offset.dx + (20 * scale),
      offset.dy + (14.993 * scale),
      offset.dx + (14.461 * scale),
      offset.dy + (20.193 * scale),
      offset.dx + (12.601 * scale),
      offset.dy + (21.799 * scale),
    )
    ..arcToPoint(
      Offset(offset.dx + (11.399 * scale), offset.dy + (21.799 * scale)),
      radius: Radius.circular(1 * scale),
      clockwise: true,
    )
    ..cubicTo(
      offset.dx + (9.539 * scale),
      offset.dy + (20.193 * scale),
      offset.dx + (4 * scale),
      offset.dy + (14.993 * scale),
      offset.dx + (4 * scale),
      offset.dy + (10 * scale),
    )
    ..arcToPoint(
      Offset(offset.dx + (20 * scale), offset.dy + (10 * scale)),
      radius: Radius.circular(8 * scale),
      clockwise: true,
    );

  final fillPaint = Paint()
    ..color = const Color(0xFF2E2E2E)
    ..style = PaintingStyle.fill;
  canvas.drawPath(pinPath, fillPaint);

  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawCircle(
    Offset(offset.dx + (12 * scale), offset.dy + (10 * scale)),
    3 * scale,
    strokePaint,
  );
}

class UserLocationMapMarkerPainter extends CustomPainter {
  const UserLocationMapMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintUserLocationMarker(canvas, size.shortestSide);
  }

  @override
  bool shouldRepaint(covariant UserLocationMapMarkerPainter oldDelegate) =>
      false;
}
