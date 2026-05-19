import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'recommend_screen.dart';
import 'meal_planner_screen.dart';
import 'saved_recipes_screen.dart';
import 'cooking_history_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'dart:ui';

import 'chat_fab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 2; // Home is now middle
  late AnimationController _auroraController;
  final GlobalKey<RecommendScreenState> _recommendKey = GlobalKey<RecommendScreenState>();

  late final List<Widget> _screens = [
    RecommendScreen(key: _recommendKey),
    const MealPlannerScreen(),
    const DashboardScreen(),
    const SavedRecipesScreen(),
    CookingHistoryScreen(),
  ];

  void _changeTab(int index) {
    if (_currentIndex == 0 && index != 0) {
      // Navigating away from Recommend screen, clear all inputs!
      _recommendKey.currentState?.clearAllInputs();
    }
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 100),
        child: ChatFab(),
      ),
      body: Stack(
        children: [
          // ── Unified Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (context, _) => CustomPaint(
                painter: AuroraPainter(_auroraController.value),
              ),
            ),
          ),

          // ── Active Screen ──
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),

          // ── Floating Bottom Navigation ──
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // ── The Main Bar ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(0, Icons.explore_rounded, 'Explore'),
                          _buildNavItem(1, Icons.calendar_today_rounded, 'Planner'),
                          const SizedBox(width: 60), // Space for floating Home
                          _buildNavItem(3, Icons.bookmark_rounded, 'Saved'),
                          _buildNavItem(4, Icons.history_rounded, 'History'),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Floating 3D Home Button ──
                Positioned(
                  bottom: 12, // Lifts it above the bar base
                  child: _buildFloatingHome(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingHome(int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _changeTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected 
            ? AppColors.primaryGradient 
            : LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
          border: Border.all(
            color: isSelected ? Colors.white54 : Colors.white10,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.accent.withOpacity(0.5) : Colors.black45,
              blurRadius: 20,
              spreadRadius: isSelected ? 4 : 0,
              offset: const Offset(0, 10),
            ),
            if (isSelected)
              BoxShadow(
                color: AppColors.accent.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
          ],
        ),
        child: Icon(
          Icons.home_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _changeTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
