import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TasteProfileWidget extends StatelessWidget {
  final Map<String, dynamic> tasteProfile;
  final bool isLoading;
  final bool tasteEmpty;

  const TasteProfileWidget({
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
        final safeScores =
            scores.map((s) => s.clamp(0, 100) / 100.0).toList();

        final chart = SizedBox(
          width: isWide ? 260 : double.infinity,
          height: isWide ? 280 : 300,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  titleTextStyle: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  dataSets: [
                    RadarDataSet(
                      fillColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                      entryRadius: 0,
                      dataEntries: List.generate(
                          labels.length, (_) => const RadarEntry(value: 1.0)),
                    ),
                    RadarDataSet(
                      fillColor: const Color(0xFF4F98A3).withOpacity(0.2),
                      borderColor: const Color(0xFF4F98A3),
                      borderWidth: 2,
                      entryRadius: 4,
                      dataEntries:
                          safeScores.map((s) => RadarEntry(value: s)).toList(),
                    ),
                  ],
                  radarBorderData:
                      const BorderSide(color: Colors.transparent),
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(fontSize: 0),
                  tickBorderData:
                      const BorderSide(color: Color(0x40000000)),
                  gridBorderData:
                      const BorderSide(color: Color(0x40000000)),
                  titlePositionPercentageOffset: 0.15,
                  getTitle: (index, angle) {
                    if (index >= labels.length) {
                      return const RadarChartTitle(text: '');
                    }
                    final label = labels[index];
                    final emoji = _axisEmojis[label] ?? '';
                    return RadarChartTitle(
                        text: '$emoji $label',
                        angle: 0,
                        positionPercentageOffset: 0.15);
                  },
                ),
              ),
            ),
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
}