import 'dart:math';
import 'package:flutter/material.dart';

class AuroraPainter extends CustomPainter {
  final double animation;
  AuroraPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFF6B35).withOpacity(0.2),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.05),
        radius: 350,
      ));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.05), 350, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFF7931E).withOpacity(0.14),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(
        center: Offset(
          size.width + 80 - 50 * cos(animation * 2 * pi),
          size.height * 0.85,
        ),
        radius: 300,
      ));
    canvas.drawCircle(
        Offset(
          size.width + 80 - 50 * cos(animation * 2 * pi),
          size.height * 0.85,
        ),
        300,
        paint2);
  }

  @override
  bool shouldRepaint(AuroraPainter old) => old.animation != animation;
}