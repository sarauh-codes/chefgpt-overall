import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import 'chat_fab.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'recipe_detail_screen.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> with SingleTickerProviderStateMixin {
  List _recipes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _fetchSavedRecipes();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/saved-recipes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recipes = data['recipes'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load saved recipes';
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                      Text('Saved Collection', style: AppStyles.h1),
                      const SizedBox(height: 4),
                      Text('${_recipes.length} recipes ready to cook', style: AppStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage.isNotEmpty
                          ? _buildErrorState()
                          : _recipes.isEmpty
                              ? _buildEmptyState()
                              : _buildRecipesGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final canPop = Navigator.canPop(context);
    if (!canPop) return const SizedBox(height: 16);
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

  Widget _buildRecipesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _buildAnimatedCard(recipe, index);
      },
    );
  }

  Widget _buildAnimatedCard(dynamic recipe, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: _buildRecipeCard(recipe),
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(dynamic recipe) {
    final imageUrl = recipe['image_url'] ?? '';
    final name = recipe['recipe_name'] ?? 'Recipe';
    
    return GestureDetector(
      onTap: () {
        final id = int.tryParse(recipe['recipe_id'].toString()) ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
        );
      },
      child: NeoGlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Image Background
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: imageUrl.isNotEmpty 
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.bodyLarge.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.accent, size: 14),
                      const SizedBox(width: 4),
                      Text('View Details', style: AppStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            // Floating Tag
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.bookmark_rounded, color: AppColors.accent, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(child: Icon(Icons.restaurant_rounded, color: Colors.white12, size: 40)),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
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
            child: Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          ),
          const SizedBox(height: 24),
          Text('Your collection is empty', style: AppStyles.h2.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text('Save recipes to see them here!', style: AppStyles.bodyMedium),
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
