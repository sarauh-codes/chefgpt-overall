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
  bool _isLoadingRecipes = false;
  String _recipeError = '';

  Map<String, dynamic> _tasteProfile = {};
  bool _isLoadingTaste = true;
  bool _showTastePanel = false;

  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _loadUser();
    _loadRecipes();
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
          _allRecipes = List<Map<String, dynamic>>.from(data['recipes'] ?? data);
          _filteredRecipes = List.from(_allRecipes);
        });
      } else {
        setState(() => _recipeError = 'Failed to load recipes.');
      }
    } catch (e) {
      setState(() => _recipeError = 'Cannot connect to server.');
    } finally {
      if (mounted) setState(() => _isLoadingRecipes = false);
    }
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
      setState(() => _isLoadingStats = false);
    }
  }

  void _searchRecipes(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredRecipes = List.from(_allRecipes));
      return;
    }
    setState(() {
      _filteredRecipes = _allRecipes.where((recipe) {
        final name = (recipe['name'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
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
          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _loadRecipes,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildEliteHero(),
                          const SizedBox(height: 32),
                          _buildCommunityTrends(),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildSearchBar(),
                          ),
                          const SizedBox(height: 32),
                          _buildRecipeSection(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text('ChefGPT', style: AppStyles.h2.copyWith(fontSize: 22, letterSpacing: 1)),
          const Spacer(),
          _buildUserMenu(),
        ],
      ),
    );
  }

  Widget _buildEliteHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeoGlassContainer(
        padding: const EdgeInsets.all(0),
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withOpacity(0.8),
                AppColors.accent.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(Icons.ramen_dining_rounded, size: 180, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Premium\nFlavour Awaits', style: AppStyles.h1.copyWith(fontSize: 30, height: 1.1)),
                    const SizedBox(height: 12),
                    Text('Discover curated recipes tailored\nto your unique taste profile.', style: AppStyles.bodyMedium.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityTrends() {
    if (_isLoadingStats) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrendingSection(),
        const SizedBox(height: 32),
        _buildTopGemsSection(),
      ],
    );
  }

  Widget _buildTrendingSection() {
    final trending = _userStats['global_favorites'] as List? ?? [];
    if (trending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Text('Trending Now', style: AppStyles.h3.copyWith(fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: trending.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _trendCard(trending[i], isTrending: true),
          ),
        ),
      ],
    );
  }

  Widget _buildTopGemsSection() {
    final gems = _userStats['top_gems'] as List? ?? [];
    if (gems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Text('Top Rated Gems', style: AppStyles.h3.copyWith(fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: gems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _trendCard(gems[i], isTrending: false),
          ),
        ),
      ],
    );
  }

  Widget _trendCard(dynamic data, {required bool isTrending}) {
    return GestureDetector(
      onTap: () {
        final rawId = data['id'];
        if (rawId == null) return;
        final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
        );
      },
      child: NeoGlassContainer(
        width: 150,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Image or Placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (data['image'] != null && data['image'].toString().isNotEmpty)
                  ? Image.network(
                      data['image'],
                      height: double.infinity,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                    )
                  : Container(color: Colors.white10),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isTrending) ...[
                        const Icon(Icons.people_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('${data['count']} cooked', style: AppStyles.caption.copyWith(fontSize: 10)),
                      ] else ...[
                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${data['rating']}', style: AppStyles.caption.copyWith(fontSize: 10)),
                      ],
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: AppStyles.h3.copyWith(fontSize: 18, color: Colors.white)),
    );
  }

  Widget _buildRecipeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Handpicked for You'),
        const SizedBox(height: 16),
        _buildRecipeList(),
      ],
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchRecipes,
        style: AppStyles.bodyMedium.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Find ingredients or recipes...',
          hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRecipeList() {
    if (_isLoadingRecipes) {
      return const Padding(
        padding: EdgeInsets.only(top: 100),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_filteredRecipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(child: Text('No recipes found', style: AppStyles.bodyMedium.copyWith(color: Colors.white30))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredRecipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) => RecipeCard(recipe: _filteredRecipes[i]),
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
