import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerFactory {
  static const double _markerRenderScale = 3;

  static Future<BitmapDescriptor> createFoodEventMarker({
    bool highlighted = false,
    double size = 68,
  }) {
    return _renderMarker(
      size: size,
      painter: (canvas, markerSize) {
        final center = Offset(markerSize / 2, markerSize / 2);
        final outerRadius = markerSize * 0.32;
        final innerRadius = highlighted ? markerSize * 0.245 : markerSize * 0.255;
        final outerColor = highlighted
            ? const Color(0xFF121212)
            : const Color(0xFF3C3C3C);
        final innerColor = highlighted
            ? const Color(0xFF121212)
            : const Color(0xFF3C3C3C);
        final iconColor = highlighted
            ? Colors.white
            : const Color(0xFFF5F5F5);

        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: highlighted ? 0.22 : 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(
          center.translate(0, markerSize * 0.05),
          outerRadius,
          shadowPaint,
        );

        final outerPaint = Paint()
          ..color = outerColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, outerRadius, outerPaint);

        if (highlighted) {
          final ringPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = markerSize * 0.036;
          canvas.drawCircle(center, outerRadius - markerSize * 0.04, ringPaint);
        }

        if (highlighted) {
          final innerPaint = Paint()
            ..color = innerColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, innerRadius, innerPaint);
        }

        final iconPainter = TextPainter(textDirection: TextDirection.ltr);
        iconPainter.text = TextSpan(
          text: String.fromCharCode(Icons.local_pizza_rounded.codePoint),
          style: TextStyle(
            fontSize: markerSize * 0.26,
            fontFamily: Icons.local_pizza_rounded.fontFamily,
            package: Icons.local_pizza_rounded.fontPackage,
            color: iconColor,
          ),
        );
        iconPainter.layout();
        iconPainter.paint(
          canvas,
          Offset(
            center.dx - iconPainter.width / 2,
            center.dy - iconPainter.height / 2,
          ),
        );
      },
    );
  }

  static Future<BitmapDescriptor> createUserLocationMarker({
    double size = 56,
  }) {
    return _renderMarker(
      size: size,
      painter: (canvas, markerSize) {
        final center = Offset(markerSize / 2, markerSize / 2);
        final haloRadius = markerSize * 0.33;
        final ringRadius = markerSize * 0.25;
        final coreRadius = markerSize * 0.17;
        final dotRadius = markerSize * 0.05;

        final haloPaint = Paint()
          ..color = const Color(0xFFD9D9D9).withValues(alpha: 0.68)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, haloRadius, haloPaint);

        final ringPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = markerSize * 0.045;
        canvas.drawCircle(center, ringRadius, ringPaint);

        final corePaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, coreRadius, corePaint);

        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, dotRadius, dotPaint);
      },
    );
  }

  static Future<BitmapDescriptor> createMapPinMarker({
    bool highlighted = false,
    double size = 72,
  }) {
    return _renderMarker(
      size: size,
      painter: (canvas, markerSize) {
        final fillColor = highlighted
            ? const Color(0xFF121212)
            : const Color(0xFF2E2E2E);
        final accentColor = highlighted
            ? Colors.white
            : const Color(0xFFF3F3F3);
        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

        final pinPath = Path();
        final width = markerSize;
        final height = markerSize;
        pinPath.moveTo(width * 0.5, height * 0.96);
        pinPath.cubicTo(
          width * 0.32,
          height * 0.72,
          width * 0.16,
          height * 0.56,
          width * 0.16,
          height * 0.36,
        );
        pinPath.cubicTo(
          width * 0.16,
          height * 0.16,
          width * 0.31,
          height * 0.04,
          width * 0.5,
          height * 0.04,
        );
        pinPath.cubicTo(
          width * 0.69,
          height * 0.04,
          width * 0.84,
          height * 0.16,
          width * 0.84,
          height * 0.36,
        );
        pinPath.cubicTo(
          width * 0.84,
          height * 0.56,
          width * 0.68,
          height * 0.72,
          width * 0.5,
          height * 0.96,
        );
        pinPath.close();

        canvas.drawPath(
          pinPath.shift(Offset(0, markerSize * 0.04)),
          shadowPaint,
        );

        final fillPaint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(pinPath, fillPaint);

        final innerCirclePaint = Paint()
          ..color = accentColor.withValues(alpha: highlighted ? 0.18 : 0.14)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(markerSize * 0.5, markerSize * 0.34),
          markerSize * 0.18,
          innerCirclePaint,
        );

        final iconPainter = TextPainter(textDirection: TextDirection.ltr);
        iconPainter.text = TextSpan(
          text: String.fromCharCode(Icons.place_rounded.codePoint),
          style: TextStyle(
            fontSize: markerSize * 0.22,
            fontFamily: Icons.place_rounded.fontFamily,
            package: Icons.place_rounded.fontPackage,
            color: accentColor,
          ),
        );
        iconPainter.layout();
        iconPainter.paint(
          canvas,
          Offset(
            markerSize * 0.5 - iconPainter.width / 2,
            markerSize * 0.34 - iconPainter.height / 2,
          ),
        );
      },
    );
  }

  static Future<BitmapDescriptor> createClusterMarker({
    required int count,
    double size = 76,
  }) {
    final outerColor = count > 9
        ? const Color(0xFF111111)
        : const Color(0xFF1B1B1B);
    final ringColor = count > 9 ? const Color(0xFFD9D9D9) : Colors.white;

    return _renderMarker(
      size: size,
      painter: (canvas, markerSize) {
        final center = Offset(markerSize / 2, markerSize / 2);
        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(
          center.translate(0, markerSize * 0.05),
          markerSize * 0.31,
          shadowPaint,
        );

        final haloPaint = Paint()
          ..color = const Color(0xFFEDEDED)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, markerSize * 0.31, haloPaint);

        final corePaint = Paint()
          ..color = outerColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, markerSize * 0.225, corePaint);

        final ringPaint = Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = markerSize * 0.024;
        canvas.drawCircle(center, markerSize * 0.265, ringPaint);

        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.text = TextSpan(
          text: '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: markerSize * (count > 99 ? 0.18 : 0.2),
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
      },
    );
  }

  static Future<BitmapDescriptor> _renderMarker({
    required double size,
    required void Function(Canvas canvas, double size) painter,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_markerRenderScale);
    painter(canvas, size);

    final imageSize = (size * _markerRenderScale).round();

    final image = await recorder.endRecording().toImage(
      imageSize,
      imageSize,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Failed to render marker bytes.');
    }

    return BitmapDescriptor.bytes(
      Uint8List.sublistView(bytes.buffer.asUint8List()),
      width: size,
      height: size,
    );
  }
}
