import 'dart:math';
import 'package:flutter/material.dart';

class RadarChartPainter extends CustomPainter {
  final List<double> scores; // 0-100
  final List<Color> dotColors;
  final int rings;

  RadarChartPainter({
    required this.scores,
    required this.dotColors,
    this.rings = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35; // 
    final count = scores.length;
    final angle = (2 * pi) / count;
    const startAngle = -pi / 2;

    final gridPaint = Paint()
      ..color = const Color(0x40000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw rings
    for (int r = 1; r <= rings; r++) {
      final ringRadius = radius * r / rings;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final a = startAngle + i * angle;
        final x = center.dx + ringRadius * cos(a);
        final y = center.dy + ringRadius * sin(a);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axes
    for (int i = 0; i < count; i++) {
      final a = startAngle + i * angle;
      final x = center.dx + radius * cos(a);
      final y = center.dy + radius * sin(a);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // Draw filled data polygon
    final dataPath = Path();
    for (int i = 0; i < count; i++) {
      final a = startAngle + i * angle;
      final val = (scores[i] / 100.0).clamp(0.0, 1.0);
      final r = radius * val;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      if (i == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()
      ..color = const Color(0xFF4F98A3).withOpacity(0.3)
      ..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()
        ..color = const Color(0xFF4F98A3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);

    // Draw dots
    for (int i = 0; i < count; i++) {
      final a = startAngle + i * angle;
      final val = (scores[i] / 100.0).clamp(0.0, 1.0);
      final r = radius * val;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      final color = i < dotColors.length ? dotColors[i] : const Color(0xFF4F98A3);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}