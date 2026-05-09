import '../constants.dart';
import '../utils/recipe_format.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard/aurora_painter.dart';
import '../widgets/neo_glass_container.dart';
import '../theme/app_theme.dart';
import 'dart:ui';
import 'chat_fab.dart';

class CookingModeScreen extends StatefulWidget {
  final int recipeId;
  final Map<String, dynamic> recipe;
  const CookingModeScreen({
    super.key,
    required this.recipeId,
    required this.recipe,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late PageController _pageController;
  late List<String> _steps;
  int _currentIndex = 0;
  bool _isMarkingCooked = false;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _steps = splitRecipeInstructions(widget.recipe['instructions']).where((s) => s.trim().isNotEmpty).toList();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markAsCooked() async {
    setState(() => _isMarkingCooked = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.post(
        Uri.parse('$baseUrl/api/mark-cooked/${widget.recipeId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        setState(() => _isDone = true);
      } else {
        _showSnack('Failed to mark as cooked.');
      }
    } catch (_) {
      _showSnack('Cannot connect to server.');
    } finally {
      if (mounted) setState(() => _isMarkingCooked = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const ChatFab(),
      body: Stack(
        children: [
          // ── Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (_, __) => CustomPaint(
                painter: AuroraPainter(_auroraController.value),
              ),
            ),
          ),

          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) => _buildStepCard(index),
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),

          // ── Finish Overlay ──
          if (_isDone) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeoGlassContainer(
              padding: const EdgeInsets.all(10),
              borderRadius: BorderRadius.circular(50),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COOKING MODE', style: AppStyles.caption.copyWith(color: AppColors.accent, letterSpacing: 2, fontWeight: FontWeight.bold)),
                Text(widget.recipe['recipe_name'] ?? 'The Perfect Dish', style: AppStyles.h3.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / _steps.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_currentIndex + 1} of ${_steps.length}', style: AppStyles.caption),
              Text('${(progress * 100).round()}%', style: AppStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: NeoGlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.outdoor_grill_rounded, color: AppColors.accent, size: 40),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _steps[index].trim(),
                  textAlign: TextAlign.center,
                  style: AppStyles.bodyLarge.copyWith(
                    fontSize: 28,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_none_rounded, color: Colors.white30, size: 16),
                const SizedBox(width: 8),
                Text('SAY "NEXT" TO CONTINUE', style: AppStyles.caption.copyWith(color: Colors.white24, letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentIndex == _steps.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Row(
        children: [
          if (_currentIndex > 0)
            GestureDetector(
              onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutQuart),
              child: NeoGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isLast) {
                  _markAsCooked();
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutQuart);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: isLast ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF10B981)]) : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isLast ? const Color(0xFF22C55E) : AppColors.accent).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: _isMarkingCooked
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          isLast ? 'FINISH COOKING' : 'NEXT STEP',
                          style: AppStyles.h3.copyWith(color: Colors.white, fontSize: 16, letterSpacing: 1),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 20),
                Text('Masterpiece Complete!', style: AppStyles.h1),
                const SizedBox(height: 12),
                Text('You have successfully cooked this recipe.', style: AppStyles.bodyMedium.copyWith(color: Colors.white60)),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                          child: NeoGlassContainer(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Center(child: Text('DASHBOARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pop(context, 'rate');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(child: Text('RATE RECIPE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}