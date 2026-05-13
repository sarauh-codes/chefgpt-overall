import 'package:flutter/material.dart';
import '../../screens/recipe_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../neo_glass_container.dart';

class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    final recipeName = recipe['recipe_name'] ?? recipe['name'] ?? 'Recipe';
    
    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: NeoGlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipeName, style: AppStyles.h2.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (recipe['cuisine'] != null) _tag(recipe['cuisine'], Icons.restaurant_rounded),
                      if (recipe['calories'] != null) _tag('${recipe['calories']} cal', Icons.local_fire_department_rounded),
                      if (recipe['cook_time'] != null) _tag('${recipe['cook_time']} min', Icons.timer_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('View Details', style: AppStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label, style: AppStyles.caption.copyWith(color: AppColors.accent)),
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

  void _navigateToDetail(BuildContext context) {
    final rawId = recipe['recipe_id'] ?? recipe['id'];
    if (rawId == null) return;
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
    );
  }
}