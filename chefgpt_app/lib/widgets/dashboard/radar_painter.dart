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
    final radius = size.width * 0.38;
    final count = scores.length;
    if (count == 0) return;
    
    final angle = (2 * pi) / count;
    const startAngle = -pi / 2;

    // ── Grid Paint ──
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
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

    // ── Data Polygon ──
    final dataPath = Path();
    for (int i = 0; i < count; i++) {
      final a = startAngle + i * angle;
      final val = (scores[i] / 100.0).clamp(0.1, 1.0); // min 0.1 for visibility
      final r = radius * val;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      if (i == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();

    // Fill with Gradient + Glow
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B35).withOpacity(0.6),
          const Color(0xFFFF6B35).withOpacity(0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke with Neon Glow
    final strokePaint = Paint()
      ..color = const Color(0xFFFF6B35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawPath(dataPath, strokePaint);

    // ── Glow Dots ──
    for (int i = 0; i < count; i++) {
      final a = startAngle + i * angle;
      final val = (scores[i] / 100.0).clamp(0.1, 1.0);
      final r = radius * val;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      final color = i < dotColors.length ? dotColors[i] : const Color(0xFFFF6B35);
      
      // Outer Glow
      canvas.drawCircle(Offset(x, y), 8, Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      
      // Main Dot
      canvas.drawCircle(Offset(x, y), 4, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), 4, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter old) => true;
}