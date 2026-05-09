import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import 'chat_fab.dart';
import '../widgets/dashboard/aurora_painter.dart';

class CookingHistoryScreen extends StatefulWidget {
  const CookingHistoryScreen({super.key});

  @override
  State<CookingHistoryScreen> createState() => _CookingHistoryScreenState();
}

class _CookingHistoryScreenState extends State<CookingHistoryScreen> with SingleTickerProviderStateMixin {
  List _history = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _fetchHistory();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cooked-history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _history = data['recipes'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Cannot connect to server';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const ChatFab(),
      body: Stack(
        children: [
          // ── Deep Immersive Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (context, child) => CustomPaint(
                painter: AuroraPainter(_auroraController.value),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cooking Journey', style: AppStyles.h1),
                      const SizedBox(height: 4),
                      Text('Your culinary achievements', style: AppStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _errorMessage.isNotEmpty
                          ? _buildErrorState()
                          : _history.isEmpty
                              ? _buildEmptyState()
                              : _buildHistoryTimeline(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildHistoryTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return _buildTimelineItem(item, index);
      },
    );
  }

  Widget _buildTimelineItem(dynamic item, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Connector
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        boxShadow: [
                          BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 10),
                        ],
                      ),
                    ),
                    if (index != _history.length - 1)
                      Container(
                        width: 2,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.accent, AppColors.accent.withOpacity(0.0)],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                // Content Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: NeoGlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                              child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                  ? Image.network(item['image_url'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white24))
                                  : const Icon(Icons.restaurant_rounded, color: Colors.white24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['cooked_at'] ?? 'Recently', style: AppStyles.caption.copyWith(color: AppColors.accent, fontSize: 10)),
                                    const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['recipe_name'] ?? 'Recipe',
                                  style: AppStyles.h2.copyWith(fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _statChip(Icons.local_fire_department_rounded, '${item['calories'] ?? '---'} cal'),
                                    const SizedBox(width: 8),
                                    _statChip(Icons.star_rounded, '${item['rating'] ?? '---'}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(label, style: AppStyles.caption.copyWith(fontSize: 10, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
            ),
            child: Icon(Icons.history_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          ),
          const SizedBox(height: 24),
          Text('No adventures yet', style: AppStyles.h2.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text('Start cooking to build your history!', style: AppStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Text(_errorMessage, style: AppStyles.bodyMedium.copyWith(color: Colors.redAccent)),
    );
  }
}