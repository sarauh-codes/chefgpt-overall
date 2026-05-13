import 'package:flutter/material.dart';
import '../../screens/recipe_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../neo_glass_container.dart';

class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final isAi = recipe['is_ai'] == true;
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    final recipeName = recipe['recipe_name'] ?? recipe['name'] ?? 'Recipe';
    
    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isAi ? Colors.deepPurple.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            width: isAi ? 1.5 : 1,
          ),
          boxShadow: [
            if (isAi)
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: NeoGlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: (isAi || imageUrl.isEmpty || imageUrl == "AI_PLACEHOLDER")
                          ? _buildAiPlaceholder()
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildPlaceholder();
                              },
                            ),
                    ),
                  ),
                  if (isAi)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'AI SUGGESTED',
                              style: AppStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipeName,
                      style: AppStyles.h2.copyWith(
                        fontSize: 18,
                        color: isAi ? Colors.white : Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (recipe['cuisine'] != null) _tag(recipe['cuisine'], Icons.restaurant_rounded, isAi),
                        if (recipe['calories'] != null) _tag('${recipe['calories']} cal', Icons.local_fire_department_rounded, isAi),
                        if (recipe['cook_time'] != null) _tag('${recipe['cook_time']} min', Icons.timer_rounded, isAi),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'View Details',
                          style: AppStyles.bodyMedium.copyWith(
                            color: isAi ? const Color(0xFFA78BFA) : AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isAi ? const Color(0xFFA78BFA) : AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon, bool isAi) {
    final color = isAi ? const Color(0xFF8B5CF6) : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(child: Icon(Icons.restaurant_rounded, color: AppColors.textTertiary, size: 40)),
    );
  }

  Widget _buildAiPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6), size: 50),
          const SizedBox(height: 8),
          Text(
            "ChefGPT AI",
            style: AppStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    final rawId = recipe['recipe_id'] ?? recipe['id'];
    if (rawId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: rawId.toString()),
      ),
    );
  }
}