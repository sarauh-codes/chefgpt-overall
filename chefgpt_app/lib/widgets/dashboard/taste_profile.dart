import 'package:flutter/material.dart';
import 'radar_painter.dart'; 
import 'dart:math';
import '../../theme/app_theme.dart';
import '../../widgets/neo_glass_container.dart';

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
    'Spicy': Color(0xFFFF4D4D),
    'Sweet': Color(0xFFFFD93D),
    'Savory': Color(0xFF6BCB77),
    'Healthy': Color(0xFF4D96FF),
    'Indulgent': Color(0xFFB392AC),
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
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flavour Analytics', style: AppStyles.h2.copyWith(fontSize: 22)),
                Text('AI-driven taste profile', style: AppStyles.caption),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeGlass,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.insights_rounded, color: AppColors.accent, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 24),
        NeoGlassContainer(
          padding: const EdgeInsets.all(24),
          child: _buildContent(labels, scores),
        ),
      ],
    );
  }

  Widget _buildContent(List<String> labels, List<double> scores) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
        ),
      );
    }

    if (tasteEmpty || labels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50),
          child: Column(
            children: [
              Icon(Icons.query_stats_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text('Data Pending', style: AppStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text('Cook more recipes to unlock your profile.', 
                  style: AppStyles.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisColors = labels.map((l) => _axisColors[l] ?? AppColors.accent).toList();

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 260,
              child: Stack(
                children: [
                  Center(
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: RadarChartPainter(
                        scores: scores,
                        dotColors: axisColors,
                        rings: 5,
                      ),
                    ),
                  ),
                  _buildLabels(labels, constraints),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ...List.generate(labels.length, (i) {
              final label = labels[i];
              final emoji = _axisEmojis[label] ?? '';
              final score = i < scores.length ? scores[i] : 0.0;
              final color = _axisColors[label] ?? AppColors.accent;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('$emoji $label', style: AppStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${score.toInt()}%', style: AppStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutQuart,
                            width: (constraints.maxWidth - 48) * (score / 100),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.6)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLabels(List<String> labels, BoxConstraints constraints) {
    final count = labels.length;
    final angle = (2 * pi) / count;
    const startAngle = -pi / 2;
    final radius = 110.0;

    return Stack(
      children: List.generate(count, (i) {
        final a = startAngle + i * angle;
        final x = constraints.maxWidth / 2 + radius * cos(a);
        final y = 130 + radius * sin(a);
        final label = labels[i];
        return Positioned(
          left: x - 30,
          top: y - 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70)),
          ),
        );
      }),
    );
  }
}