import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import '../widgets/dashboard/dietary_drawer.dart';
import '../widgets/dashboard/recipe_card.dart';
import '../widgets/dashboard/taste_profile.dart';
import 'login_screen.dart';
import 'recommend_screen.dart';
import 'saved_recipes_screen.dart';
import 'cooking_history_screen.dart';
import 'meal_planner_screen.dart';
import 'chat_screen.dart';
import 'chat_fab.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  String _username = '';
  late AnimationController _auroraController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allRecipes = [];
  List<Map<String, dynamic>> _filteredRecipes = [];
  List<Map<String, dynamic>> _featuredRecipes = [];
  List<Map<String, dynamic>> _quickRecipes = [];
  
  final List<Map<String, dynamic>> _fallbackFeatured = const [
    {
      'recipe_id': '101',
      'recipe_name': 'Flame-Grilled Wagyu Steak',
      'cuisine': 'Western',
      'rating': 4.9,
      'difficulty': 'Medium',
      'cook_time': '25',
      'servings': 2,
      'image_url': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '102',
      'recipe_name': 'Premium Seafood Ramen',
      'cuisine': 'Japanese',
      'rating': 4.8,
      'difficulty': 'Hard',
      'cook_time': '35',
      'servings': 1,
      'image_url': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '103',
      'recipe_name': 'Crispy Honey Garlic Chicken',
      'cuisine': 'Asian',
      'rating': 4.7,
      'difficulty': 'Easy',
      'cook_time': '20',
      'servings': 4,
      'image_url': 'https://images.unsplash.com/photo-1598515214211-89d3e73ae83b?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '104',
      'recipe_name': 'Truffle Mushroom Pasta',
      'cuisine': 'Italian',
      'rating': 4.9,
      'difficulty': 'Easy',
      'cook_time': '15',
      'servings': 2,
      'image_url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop',
    }
  ];

  final List<Map<String, dynamic>> _fallbackQuick = const [
    {
      'recipe_id': '201',
      'recipe_name': 'Smashed Avocado Toast',
      'cuisine': 'Healthy',
      'rating': 4.6,
      'difficulty': 'Easy',
      'cook_time': '10',
      'servings': 1,
      'image_url': 'https://images.unsplash.com/photo-1541532713592-79a0317b6b77?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '202',
      'recipe_name': 'Golden Egg Fried Rice',
      'cuisine': 'Asian',
      'rating': 4.7,
      'difficulty': 'Easy',
      'cook_time': '12',
      'servings': 2,
      'image_url': 'https://images.unsplash.com/photo-1603133872878-685f208b8480?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '203',
      'recipe_name': 'Classic Caesar Salad',
      'cuisine': 'Healthy',
      'rating': 4.5,
      'difficulty': 'Easy',
      'cook_time': '15',
      'servings': 2,
      'image_url': 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=500&auto=format&fit=crop',
    },
    {
      'recipe_id': '204',
      'recipe_name': 'Sweet Cream Berry Crepes',
      'cuisine': 'Dessert',
      'rating': 4.8,
      'difficulty': 'Medium',
      'cook_time': '20',
      'servings': 3,
      'image_url': 'https://images.unsplash.com/photo-1519676867240-f03562e64548?w=500&auto=format&fit=crop',
    }
  ];
  bool _isLoadingRecipes = false;
  String _recipeError = '';

  Map<String, dynamic> _tasteProfile = {};
  bool _isLoadingTaste = true;
  bool _showTastePanel = false;

  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;

  Timer? _searchDebounce;
  bool _isAiLoading = false;
  List<Map<String, dynamic>> _aiSuggestions = [];

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _loadUser();
    _loadRecipes();
    _fetchCategories();
    _fetchTasteProfile();
    _fetchUserStats();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _username = prefs.getString('username') ?? 'User');
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
      _recipeError = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _featuredRecipes = List<Map<String, dynamic>>.from(data['featured'] ?? []);
          _quickRecipes = List<Map<String, dynamic>>.from(data['quick'] ?? []);
          _allRecipes = List<Map<String, dynamic>>.from(data['recipes'] ?? data);
          _filteredRecipes = List.from(_allRecipes);
        });
      } else {
        setState(() => _recipeError = 'Failed to load recipes.');
      }
    } catch (e) {
      debugPrint('Load recipes error: $e');
      setState(() => _recipeError = 'Cannot connect to server.');
    } finally {
      if (mounted) setState(() => _isLoadingRecipes = false);
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadRecipes(),
      _fetchCategories(),
      _fetchTasteProfile(),
      _fetchUserStats(),
    ]);
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
          _isLoadingCategories = false;
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  Widget _buildPopularCategories() {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Popular Categories'),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(initialCuisine: cat['name']),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Card Image
                        Positioned.fill(
                          child: Image.network(
                            cat['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.restaurant_rounded, color: Colors.white24),
                            ),
                          ),
                        ),
                        // Dark overlay gradient
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.85),
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Category Name Text
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Text(
                            cat['name'] ?? '',
                            style: AppStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchTasteProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mobile-taste-profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tasteProfile = data['empty'] == true ? {'labels': [], 'scores': []} : data;
          _isLoadingTaste = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch taste error: $e');
      setState(() => _isLoadingTaste = false);
    }
  }

  Future<void> _fetchUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user-stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _userStats = jsonDecode(response.body);
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch stats error: $e');
      setState(() => _isLoadingStats = false);
    }
  }



  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let background show through
      body: Stack(
        children: [
          // ── Premium Ambient Shifting Aurora Glows ──
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.18),
                    blurRadius: 130,
                    spreadRadius: 90,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.15),
                    blurRadius: 160,
                    spreadRadius: 110,
                  ),
                ],
              ),
            ),
          ),
          
          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _handleRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildWelcomeHeroBanner(),
                          const SizedBox(height: 20),
                          _buildModernSearch(),
                          const SizedBox(height: 16),
                          _buildCategoriesTicker(),
                          const SizedBox(height: 24),
                          _buildUnifiedStatsBar(),
                          const SizedBox(height: 32),
                          _buildPopularCategories(),
                          const SizedBox(height: 32),
                          _buildCuratedSections(),
                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Slide-in Taste Panel ──
          if (_showTastePanel) _buildTasteOverlay(),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning 🌅';
    } else if (hour < 17) {
      greeting = 'Good Afternoon ☀️';
    } else {
      greeting = 'Good Evening 🌙';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppStyles.caption.copyWith(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                _username.isNotEmpty ? 'Chef $_username' : 'ChefGPT',
                style: AppStyles.h2.copyWith(fontSize: 18, letterSpacing: -0.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          _buildUserMenu(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🍜 Cook. Discover. Enjoy.',
                    style: AppStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: AppStyles.h1.copyWith(fontSize: 24, height: 1.2, fontWeight: FontWeight.w900),
                    children: [
                      const TextSpan(text: 'What do you want\nto cook '),
                      TextSpan(
                        text: 'today?',
                        style: TextStyle(
                          color: AppColors.accent,
                          shadows: [
                            Shadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Glowing illustrated food plate
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.white24, Colors.white10],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Nasi_lemak_on_banana_leaf.jpg/320px-Nasi_lemak_on_banana_leaf.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Text('🍜', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                  child: const Text(
                    'HOT 🔥',
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search recipes, ingredients...',
                  style: AppStyles.bodyMedium.copyWith(color: AppColors.textTertiary, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTicker() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _pill('⚡ Quick Meals', 'Quick'),
          _pill('💪 High Protein', 'High Protein'),
          _pill('🌱 Vegan', 'Vegan'),
          _pill('🧁 Desserts', 'Dessert'),
          _pill('🔌 Air Fryer', 'Air Fryer'),
        ],
      ),
    );
  }

  Widget _buildUnifiedStatsBar() {
    final cooked = _userStats['cooked_count'] ?? 0;
    final saved = _userStats['saved_count'] ?? 0;
    final level = _userStats['cooking_level'] ?? 'Kitchen Novice';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeoGlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Expanded(
              child: _unifiedStatItem('🔥', cooked.toString(), 'Cooked', Colors.deepOrangeAccent),
            ),
            Container(width: 1, height: 28, color: Colors.white10),
            Expanded(
              child: _unifiedStatItem('⭐', saved.toString(), 'Saved', Colors.amber),
            ),
            Container(width: 1, height: 28, color: Colors.white10),
            Expanded(
              child: _unifiedStatItem('👨‍🍳', level, 'Level', Colors.lightGreenAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unifiedStatItem(String emoji, String value, String label, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppStyles.caption.copyWith(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppStyles.h3.copyWith(fontSize: value.length > 12 ? 8 : 11, fontWeight: FontWeight.w900, color: Colors.white),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _pill(String label, String keyword) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(initialQuery: keyword),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: Text(
              label,
              style: AppStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebStatsGrid() {
    final cooked = _userStats['cooked_count'] ?? 0;
    final saved = _userStats['saved_count'] ?? 0;
    final level = _userStats['cooking_level'] ?? 'Kitchen Novice';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _statCard('🔥', cooked.toString(), 'Cooked', Colors.deepOrangeAccent)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('⭐', saved.toString(), 'Saved', Colors.amber)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('👨‍🍳', level, 'Chef Level', Colors.lightGreenAccent)),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color accentColor) {
    return NeoGlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppStyles.h3.copyWith(fontSize: value.length > 12 ? 7.5 : 9.5, fontWeight: FontWeight.w900, color: Colors.white),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppStyles.caption.copyWith(fontSize: 7.0, color: Colors.white54, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebBottomHighlights() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeoGlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _highlightItem('📖', '1000+ Recipes', 'Guides'),
            _divider(),
            _highlightItem('✨', 'AI Powered', 'Personalized'),
            _divider(),
            _highlightItem('❤️', 'ChefGPT Bot', 'Assistant'),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white10,
    );
  }

  Widget _highlightItem(String emoji, String title, String sub) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
          Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppStyles.bodyMedium.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(sub, style: AppStyles.caption.copyWith(fontSize: 7, color: Colors.white38)),
          ],
        ),
      ],
    );
  }

  Widget _buildCuratedSections() {
    final featured = _featuredRecipes.isNotEmpty ? _featuredRecipes : _fallbackFeatured;
    final quick = _quickRecipes.isNotEmpty ? _quickRecipes : _fallbackQuick;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Editor's Choice
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text("Editor's Choice", style: AppStyles.h3.copyWith(fontSize: 18, color: Colors.white)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: Text(
                  'See all →',
                  style: AppStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 242,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _curatedCard(featured[i]),
          ),
        ),
        const SizedBox(height: 32),

        // Section 2: Quick & Easy
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text("Quick & Easy (Under 30 Min)", style: AppStyles.h3.copyWith(fontSize: 18, color: Colors.white)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen(initialQuery: 'Quick')),
                  );
                },
                child: Text(
                  'See all →',
                  style: AppStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 242,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: quick.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _curatedCard(quick[i]),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _curatedCard(Map<String, dynamic> recipe) {
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();
    final name = recipe['recipe_name'] ?? recipe['name'] ?? 'Recipe';
    final cuisine = recipe['cuisine'] ?? 'Asian';
    final cookTime = recipe['cook_time'] ?? '30';
    final rating = recipe['rating'] ?? 4.5;
    final servings = recipe['servings'] ?? 2;
    final difficulty = (recipe['difficulty'] ?? 'medium').toString().toLowerCase();

    // Map difficulty to a premium visual pill style
    IconData diffIcon;
    Color diffColor;
    String diffLabel;
    if (difficulty == 'easy') {
      diffIcon = Icons.bolt_rounded;
      diffColor = Colors.greenAccent;
      diffLabel = 'Easy';
    } else if (difficulty == 'hard') {
      diffIcon = Icons.local_fire_department_rounded;
      diffColor = Colors.orangeAccent;
      diffLabel = 'Hard';
    } else {
      diffIcon = Icons.restaurant_rounded;
      diffColor = Colors.lightBlueAccent;
      diffLabel = 'Medium';
    }

    return GestureDetector(
      onTap: () {
        final rawId = recipe['recipe_id'] ?? recipe['id'];
        if (rawId == null) return;
        final int id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
        );
      },
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: NeoGlassContainer(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container with premium overlays
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: (imageUrl.isEmpty || imageUrl.contains('placeholder'))
                          ? Container(
                              color: Colors.white.withOpacity(0.05),
                              child: const Icon(Icons.restaurant_rounded, color: Colors.white30, size: 32),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withOpacity(0.05),
                                child: const Icon(Icons.restaurant_rounded, color: Colors.white30, size: 32),
                              ),
                            ),
                    ),
                  ),
                  // Image bottom gradient shadow for text integration
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Cuisine Tag top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            cuisine.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Cook Time tag bottom-right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            '$cookTime min',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Meta info
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Stats and Difficulty Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating & Servings Column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.people_rounded, color: Colors.white54, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '$servings por.',
                                  style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Difficulty badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: diffColor.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(diffIcon, color: diffColor, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                diffLabel,
                                style: TextStyle(color: diffColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
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

  Widget _buildLowerCtaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeoGlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            const Text('👨‍🍳', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need more ideas?',
                    style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tell me your ingredients, dietary preference or mood, and I'll handle the rest!",
                    style: AppStyles.caption.copyWith(color: Colors.white54, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(
                '✦ Ask',
                style: AppStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: AppStyles.h3.copyWith(fontSize: 18, color: Colors.white)),
    );
  }

  Widget _buildUserMenu() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'logout') _logout();
        if (val == 'taste') setState(() => _showTastePanel = true);
        if (val == 'diet') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const DietaryDrawer(),
          );
        }
      },
      offset: const Offset(0, 50),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white10),
      ),
      child: NeoGlassContainer(
        padding: const EdgeInsets.all(4),
        borderRadius: BorderRadius.circular(50),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.accent.withOpacity(0.2),
          child: Text(_username.isNotEmpty ? _username[0].toUpperCase() : 'U', 
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
        ),
      ),
      itemBuilder: (_) => [
        _menuItem('diet', Icons.eco_rounded, 'Dietary Settings'),
        _menuItem('taste', Icons.bar_chart_rounded, 'Taste Profile'),
        _menuItem('logout', Icons.logout_rounded, 'Logout'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(label, style: AppStyles.bodyMedium.copyWith(color: Colors.white)),
        ],
      ),
    );
  }



  Widget _buildTasteOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showTastePanel = false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.88,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.85),
                  border: const Border(left: BorderSide(color: Colors.white10, width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taste Profile', style: AppStyles.h2),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => setState(() => _showTastePanel = false),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 40),
                    Expanded(
                      child: TasteProfile(
                        tasteProfile: _tasteProfile,
                        isLoading: _isLoadingTaste,
                        tasteEmpty: (_tasteProfile['labels'] as List? ?? []).isEmpty,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
