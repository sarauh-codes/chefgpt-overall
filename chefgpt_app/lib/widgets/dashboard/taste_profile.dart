import 'package:flutter/material.dart';
import 'radar_painter.dart'; 
import 'dart:math';

class TasteProfile extends StatelessWidget {
  final Map<String, dynamic> tasteProfile;
  final bool isLoading;
  final bool tasteEmpty;

  const TasteProfile({
    super.key,
    required this.tasteProfile,
    required this.isLoading,
    required this.tasteEmpty,
  });

  static const _axisColors = {
    'Spicy': Color(0xFFE05D44),
    'Sweet': Color(0xFFF0A500),
    'Savory': Color(0xFF4F98A3),
    'Healthy': Color(0xFF6DAA45),
    'Indulgent': Color(0xFFBB65A0),
  };

  static const _axisEmojis = {
    'Spicy': '🌶️',
    'Sweet': '🍬',
    'Savory': '🧄',
    'Healthy': '🥗',
    'Indulgent': '🧁',
  };

  @override
  Widget build(BuildContext context) {
    final labels = ((tasteProfile['labels'] ?? []) as List).cast<String>();
    final scores = ((tasteProfile['scores'] ?? []) as List)
        .map((s) => (s as num).toDouble())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🍽️ Your Taste Profile',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        Text('Based on your cooking history',
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: _buildContent(labels, scores),
        ),
      ],
    );
  }

  Widget _buildContent(List<String> labels, List<double> scores) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF4F98A3)),
        ),
      );
    }

    if (tasteEmpty || labels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Text('🍳', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('No taste data yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF333333))),
              const SizedBox(height: 6),
              Text('Start cooking recipes to see your flavour profile!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;


        final axisColors = labels.map((l) => _axisColors[l] ?? const Color(0xFF4F98A3)).toList();

final chart = SizedBox(
  width: double.infinity,
  height: 300,
  child: Stack(
    children: [
    SizedBox.expand(
      child:CustomPaint(
        painter: RadarChartPainter(
          scores: scores,
          dotColors: axisColors,
          rings: 5,
        ),
        child: Container(),
      ),
    ),
    _buildLabels(labels, constraints),
    ],
  ),
);

        final bars = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(labels.length, (i) {
            final label = labels[i];
            final emoji = _axisEmojis[label] ?? '';
            final score = i < scores.length ? scores[i] : 0.0;
            final color = _axisColors[label] ?? const Color(0xFF4F98A3);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('$emoji $label',
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(99)),
                      alignment: Alignment.centerLeft,
                      child: LayoutBuilder(
                        builder: (context, boxConstraints) =>
                            AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          width: boxConstraints.maxWidth * (score / 100),
                          height: 8,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 38,
                    child: Text('${score.toInt()}%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        );

        return isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                chart,
                const SizedBox(width: 24),
                Expanded(child: bars),
              ])
            : Column(children: [
                chart,
                const SizedBox(height: 24),
                bars,
              ]);
      },
    );
  }
  Widget _buildLabels(List<String> labels, BoxConstraints constraints) {
  final count = labels.length;
  final angle = (2 * pi) / count;
  const startAngle = -pi / 2;
  final radius = constraints.maxWidth * 0.35 + 28.0; // label kat luar ring

  return Stack(
    children: List.generate(count, (i) {
      final a = startAngle + i * angle;
      final x = constraints.maxWidth / 2 + radius * cos(a);
      final y = 150 + radius * sin(a); // 150 = height/2
      final label = labels[i];
      final emoji = _axisEmojis[label] ?? '';
      return Positioned(
        left: x - 30,
        top: y - 10,
        child: Text('$emoji $label',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
      );
    }),
  );
}
}