import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/dashboard/aurora_painter.dart';
import '../widgets/dashboard/dietary_drawer.dart';
import '../widgets/dashboard/recipe_card.dart';
import 'login_screen.dart';
import 'recommend_screen.dart';
import 'saved_recipes_screen.dart';
import 'cooking_history_screen.dart';
import '../constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _username = '';
  late AnimationController _auroraController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allRecipes = [];
  List<Map<String, dynamic>> _filteredRecipes = [];
  bool _isLoadingRecipes = false;
  String _recipeError = '';

  Map<String, dynamic> _tasteProfile = {};
  bool _isLoadingTaste = true;
  bool _tasteEmpty = false;

  final _axisColors = {
    'Spicy': const Color(0xFFE05D44),
    'Sweet': const Color(0xFFF0A500),
    'Savory': const Color(0xFF4F98A3),
    'Healthy': const Color(0xFF6DAA45),
    'Indulgent': const Color(0xFFBB65A0),
  };

  final _axisEmojis = {
    'Spicy': '🌶',
    'Sweet': '🍬',
    'Savory': '🧄',
    'Healthy': '🥗',
    'Indulgent': '🧁',
  };

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
          _allRecipes =
              List<Map<String, dynamic>>.from(data['recipes'] ?? data);
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
        final isEmpty = data['empty'] ?? true;
        setState(() {
          _tasteEmpty = isEmpty;
          _tasteProfile = isEmpty ? {'labels': [], 'scores': []} : data;
          _isLoadingTaste = false;
        });
      } else {
        setState(() {
          _tasteEmpty = true;
          _tasteProfile = {'labels': [], 'scores': []};
          _isLoadingTaste = false;
        });
      }
    } catch (e) {
      setState(() {
        _tasteEmpty = true;
        _tasteProfile = {'labels': [], 'scores': []};
        _isLoadingTaste = false;
      });
    }
  }

  Future<void> _searchRecipes(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _filteredRecipes = List.from(_allRecipes));
      return;
    }
    setState(() => _isLoadingRecipes = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/search-recipes?q=${Uri.encodeQueryComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _filteredRecipes =
              List<Map<String, dynamic>>.from(data['recipes'] ?? data);
        });
      }
    } catch (e) {
      setState(() => _recipeError = 'Search failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoadingRecipes = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _openDietaryDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DietaryDrawer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF7),
      body: AnimatedBuilder(
        animation: _auroraController,
        builder: (context, child) => Stack(
          children: [
            Positioned.fill(
              child:
                  CustomPaint(painter: AuroraPainter(_auroraController.value)),
            ),
            child!,
          ],
        ),
        child: Column(
          children: [
            _buildNavbar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFF6B35),
                onRefresh: _loadRecipes,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 28),
                      _buildTasteProfile(),
                      const SizedBox(height: 28),
                      _buildDashboardGrid(),
                      const SizedBox(height: 40),
                      _buildBrowseSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 20,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x4DFF6B35), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🍳 ChefGPT',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'diet') _openDietaryDrawer();
              if (value == 'logout') _logout();
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  BorderSide(color: const Color(0xFFFF6B35).withOpacity(0.12)),
            ),
            color: Colors.white,
            elevation: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      color: Colors.white, size: 17),
                  const SizedBox(width: 6),
                  Text(_username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 17),
                ],
              ),
            ),
            itemBuilder: (_) => [
              _popupItem('diet', '🥦', 'Dietary Settings'),
              _popupItem('logout', '🚪', 'Logout'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, String emoji, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.35),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $_username! 👋',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text('Ready to discover amazing recipes?',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _auroraController,
            builder: (_, child) => Transform.translate(
              offset:
                  Offset(0, -6 * sin(_auroraController.value * 2 * pi * 0.5)),
              child: child,
            ),
            child: const Icon(Icons.restaurant_rounded,
                size: 64, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTasteProfile() {
    final labels = ((_tasteProfile['labels'] ?? []) as List).cast<String>();
    final scores = ((_tasteProfile['scores'] ?? []) as List)
        .map((s) => (s as num).toDouble())
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 20),
        ],
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Taste Profile',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text('Based on your cooking history',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 16),
          if (_isLoadingTaste)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF4F98A3)),
              ),
            )
          else if (_tasteEmpty || labels.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('No taste data yet',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Text('Cook some recipes to see your flavour profile!',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 320,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      titleTextStyle: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      dataSets: [
                        RadarDataSet(
                          fillColor: const Color(0xFF4F98A3).withOpacity(0.15),
                          borderColor: const Color(0xFF4F98A3),
                          borderWidth: 2,
                          entryRadius: 0,
                          dataEntries:
                              scores.map((s) => RadarEntry(value: s)).toList(),
                        ),
                        ...List.generate(labels.length, (i) {
                          final color =
                              _axisColors[labels[i]] ?? const Color(0xFF4F98A3);
                          final pointScores = List.filled(labels.length, 0.0);
                          pointScores[i] = scores[i];
                          return RadarDataSet(
                            fillColor: Colors.transparent,
                            borderColor: Colors.transparent,
                            borderWidth: 0,
                            entryRadius: 6,
                            dataEntries: pointScores
                                .map((s) => RadarEntry(value: s))
                                .toList(),
                          );
                        }),
                      ],
                      radarBorderData:
                          const BorderSide(color: Colors.transparent),
                      tickCount: 4,
                      ticksTextStyle: const TextStyle(fontSize: 0),
                      tickBorderData:
                          const BorderSide(color: Color(0x30000000)),
                      gridBorderData:
                          const BorderSide(color: Color(0x30000000)),
                      titlePositionPercentageOffset: 0.15,
                      getTitle: (index, angle) {
                        if (index >= labels.length)
                          return const RadarChartTitle(text: '');
                        return RadarChartTitle(
                          text:
                              '${_axisEmojis[labels[index]] ?? ''} ${labels[index]}',
                          angle: 0,
                          positionPercentageOffset: 0.15,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(labels.length, (i) {
                  final label = labels[i];
                  final score = i < scores.length ? scores[i] : 0.0;
                  final color = _axisColors[label] ?? const Color(0xFF4F98A3);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${_axisEmojis[label] ?? ''} $label',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              backgroundColor: Colors.black.withOpacity(0.07),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${score.toInt()}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _dashCard(
                emoji: '🔍',
                title: 'Get Recipe\nSuggestions',
                subtitle: 'AI-powered recommendations',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RecommendScreen())),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _dashCard(
                emoji: '📖',
                title: 'My Cooked\nRecipes',
                subtitle: 'View cooking history',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CookingHistoryScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _dashCard(
          emoji: '⭐',
          title: 'Saved Recipes',
          subtitle: 'Access your favourite saved recipes anytime',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SavedRecipesScreen())),
          horizontal: true,
        ),
      ],
    );
  }

  Widget _dashCard({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool horizontal = false,
  }) {
    final content = horizontal
        ? Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            _orangeButton(onTap, label: 'View Saved'),
          ])
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.3)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600], height: 1.4)),
              const SizedBox(height: 14),
              _orangeButton(onTap,
                  label: title.contains('Suggest')
                      ? 'Start Cooking'
                      : 'View History'),
            ],
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: horizontal ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 20),
          ],
          border: Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.08), width: 1),
        ),
        child: content,
      ),
    );
  }

  Widget _orangeButton(VoidCallback onTap, {required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBrowseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFFFF6B35).withOpacity(0.0),
              const Color(0xFFFF6B35).withOpacity(0.15),
              const Color(0xFFFF6B35).withOpacity(0.0),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text('🍴 Browse All Recipes',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Explore our collection of delicious recipes',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFFFE0D0), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.08),
                  blurRadius: 16),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (query) => _searchRecipes(query),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Search by name, cuisine, or ingredients...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildRecipeList(),
      ],
    );
  }

  Widget _buildRecipeList() {
    if (_isLoadingRecipes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    if (_recipeError.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_recipeError,
                style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _loadRecipes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text('Try Again',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredRecipes.isEmpty) {
      return Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 52, color: Colors.black12),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No recipes available.'
                : 'No results for "${_searchController.text}"',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredRecipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => RecipeCard(recipe: _filteredRecipes[i]),
    );
  }
}
