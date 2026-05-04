import 'package:flutter/material.dart';
import '../../screens/recipe_detail_screen.dart';

class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 16),
        ],
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.07), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          if (imageUrl.isNotEmpty)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                loadingBuilder: (context, child, prog) {
                  if (prog == null) return child;
                  return const ColoredBox(
                    color: Color(0xFFFFF3EE),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFFFF3EE),
                  alignment: Alignment.center,
                  child: Icon(Icons.restaurant_rounded,
                      color: const Color(0xFFFF6B35).withOpacity(0.5),
                      size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe['recipe_name'] ?? 'Recipe',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (recipe['cuisine'] != null)
                      _infoTag('🍽️ ${recipe['cuisine']}'),
                    if (recipe['calories'] != null)
                      _infoTag('🔥 ${recipe['calories']} cal'),
                    if (recipe['rating'] != null)
                      _infoTag('⭐ ${recipe['rating']}/5'),
                  ],
                ),
                const SizedBox(height: 12),
                if (recipe['ingredients'] != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF7),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                          left: BorderSide(color: Color(0xFFFF6B35), width: 3)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666), height: 1.6),
                        children: [
                          const TextSpan(
                            text: 'Ingredients: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333)),
                          ),
                          TextSpan(text: recipe['ingredients'].toString()),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    final rawId = recipe['recipe_id'] ?? recipe['id'];
                    if (rawId == null) return;
                    final id = rawId is int
                        ? rawId
                        : int.tryParse(rawId.toString()) ?? 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipeId: id),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text('View Full Recipe',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.15), width: 1),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFFF6B35))),
    );
  }
}