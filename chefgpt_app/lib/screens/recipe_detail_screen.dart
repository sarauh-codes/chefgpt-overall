import '../constants.dart';
import '../utils/recipe_format.dart';
import '../utils/language_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'cooking_mode_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../widgets/recipe/feedback_sheet.dart';
import 'chat_screen.dart';
import 'chat_fab.dart';
import 'recipe_print_preview_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late TabController _tabController;
  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;
  List _feedbacks = [];
  final ScrollController _scrollController = ScrollController();

  // ── Language state ──
  bool _isMalay = false;
  bool _isTranslating = false;
  String? _transIngredients; // translated comma-separated ingredients
  String? _transInstructions; // translated pipe-separated instructions

  @override
  void initState() {
    super.initState();
    _auroraController =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAll();
    _loadLanguagePref();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _tabController.dispose();
    _scrollController.dispose(); 
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadLanguagePref() async {
    final lang = await getLanguage();
    if (lang == 'ms' && mounted) {
      setState(() => _isMalay = true);
      // Fetch translation once recipe is loaded
      await _loadAll();
      _fetchTranslation();
    }
  }

  Future<void> _toggleLanguage() async {
    final newIsMalay = !_isMalay;
    setState(() => _isMalay = newIsMalay);
    await setLanguage(newIsMalay ? 'ms' : 'en');
    if (newIsMalay && _transIngredients == null) {
      _fetchTranslation();
    }
  }

  Future<void> _fetchTranslation() async {
    if (_recipe == null) return;
    final ingredients = _recipe!['ingredients']?.toString() ?? '';
    final instructions = _recipe!['instructions']?.toString() ?? '';
    if (ingredients.isEmpty && instructions.isEmpty) return;

    setState(() => _isTranslating = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/translate-recipe'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipe_id': widget.recipeId,
          'ingredients': ingredients,
          'instructions': instructions,
        }),
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _transIngredients = data['ingredients_ms']?.toString();
          _transInstructions = data['instructions_ms']?.toString();
        });
      }
    } catch (e) {
      debugPrint('[recipe_detail] Translation error: $e');
      if (mounted) {
        _showSnack('Translation unavailable. Showing English.', isError: true);
        setState(() => _isMalay = false);
        await setLanguage('en');
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchRecipe(), _checkSaved(), _fetchFeedbacks()]);
  }

  Future<void> _fetchRecipe() async {
    final token = await _getToken();
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/recipe/${widget.recipeId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _recipe = data['recipe'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSaved() async {
    final token = await _getToken();
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/saved-recipes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final saved = data['recipes'] as List;
        setState(() {
          _isSaved = saved.any((r) => r['recipe_id'] == widget.recipeId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    setState(() => _isSaving = true);
    final token = await _getToken();
    try {
      if (_isSaved) {
        setState(() => _isSaved = false);
        _showSnack('Removed from saved!', isError: false);
        await http.post(
          Uri.parse('$baseUrl/api/unsave-recipe/${widget.recipeId}'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        setState(() => _isSaved = true);
        _showSnack('Recipe saved!', isError: false);
        await http.post(
          Uri.parse('$baseUrl/api/save-recipe/${widget.recipeId}'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (_) {
      setState(() => _isSaved = !_isSaved);
      _showSnack('Cannot connect to server', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchFeedbacks() async {
    final token = await _getToken();
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/get-feedbacks/${widget.recipeId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _feedbacks = data['feedbacks'] ?? []);
      }
    } catch (_) {}
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          // ── Scrollable Body ──
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.accent))
          else if (_recipe == null)
            _buildErrorState()
          else
            _buildMainContent(),

          // ── Top Glass Navigation ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: NeoGlassContainer(
                padding: const EdgeInsets.all(10),
                borderRadius: BorderRadius.circular(50),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
            Row(
              children: [
                // ── Language Toggle ──
                GestureDetector(
                  onTap: _isTranslating ? null : _toggleLanguage,
                  behavior: HitTestBehavior.opaque,
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderRadius: BorderRadius.circular(50),
                    borderColor: _isMalay ? AppColors.accent : AppColors.glassBorder,
                    child: _isTranslating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language_rounded,
                                color: _isMalay ? AppColors.accent : Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isMalay ? 'BM' : 'EN',
                                style: TextStyle(
                                  color: _isMalay ? AppColors.accent : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _shareRecipe,
                  behavior: HitTestBehavior.opaque,
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.all(10),
                    borderRadius: BorderRadius.circular(50),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _printRecipe,
                  behavior: HitTestBehavior.opaque,
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.all(10),
                    borderRadius: BorderRadius.circular(50),
                    child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSaving ? null : _toggleSave,
                  behavior: HitTestBehavior.opaque,
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.all(10),
                    borderRadius: BorderRadius.circular(50),
                    borderColor: _isSaved ? AppColors.accent : AppColors.glassBorder,
                    child: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                      color: _isSaved ? AppColors.accent : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final recipe = _recipe ?? {};
    final imgUrl = recipe['image_url']?.toString() ?? '';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernHero(imgUrl, recipe),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 60), // Space for the floating card overlap
                      _buildTabBar(),
                      const SizedBox(height: 24),
                      _buildTabContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFixedBottomAction(),
      ],
    );
  }

  Widget _buildModernHero(String imgUrl, Map<String, dynamic> recipe) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main Image ──
        Container(
          height: 380,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            image: imgUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
                : null,
          ),
          child: imgUrl.isEmpty
              ? const Center(child: Icon(Icons.restaurant_rounded, size: 80, color: Colors.white10))
              : null,
        ),
        // ── Gradient Overlay ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  AppColors.background.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        // ── Floating Info Card ──
        Positioned(
          bottom: -40,
          left: 20,
          right: 20,
          child: NeoGlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orangeGlass,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recipe['cuisine']?.toString().toUpperCase() ?? 'GENERAL',
                        style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                    const SizedBox(width: 4),
                    Text('${recipe['rating']}/5', style: AppStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recipe['recipe_name'] ?? 'The Perfect Dish',
                  style: AppStyles.h2.copyWith(fontSize: 26, height: 1.2),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _compactInfo(Icons.local_fire_department_rounded, '${recipe['calories']} cal'),
                    _compactInfo(Icons.timer_rounded, '${recipe['cook_time'] ?? '45'} min'),
                    _compactInfo(Icons.restaurant_rounded, recipe['difficulty']?.toString().toUpperCase() ?? 'MEDIUM'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 6),
        Text(label, style: AppStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildTabBar() {
    return NeoGlassContainer(
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Ingredients'),
          Tab(text: 'Steps'),
          Tab(text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return [
      _buildOverviewTab(),
      _buildIngredientsTab(),
      _buildStepsTab(),
      _buildReviewsTab(),
    ][_tabController.index];
  }

  List<String> _checkedIngredients = [];

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('📖 About this Recipe'),
        const SizedBox(height: 16),
        NeoGlassContainer(
          padding: const EdgeInsets.all(20),
          child: Text(
            'This premium ${(_recipe?['cuisine'] ?? 'general').toLowerCase()} dish is meticulously crafted for the best flavour experience. Follow the steps carefully to achieve chef-quality results.',
            style: AppStyles.bodyMedium.copyWith(color: Colors.white70, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),
        _buildModernActionButtons(),
      ],
    );
  }

  Widget _buildIngredientsTab() {
    // Use translated ingredients string when Malay is active and translation is ready
    final raw = (_isMalay && _transIngredients != null)
        ? _transIngredients!
        : (_recipe?['ingredients'] ?? '');
    return _buildIngredientsList(raw);
  }

  Widget _buildStepsTab() {
    // Use translated instructions when Malay is active and translation is ready
    final rawInstructions = (_isMalay && _transInstructions != null)
        ? _transInstructions!
        : (_recipe?['instructions'] ?? '');
    final steps = splitRecipeInstructions(rawInstructions).where((s) => s.trim().isNotEmpty).toList();
    final visibleSteps = steps.take(3).toList();
    final hasMore = steps.length > 3;

    return Column(
      children: [
        // Translating indicator
        if (_isTranslating)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Menterjemah ke Bahasa Melayu...', style: AppStyles.caption.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.7, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: Column(
            children: List.generate(visibleSteps.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: NeoGlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(visibleSteps[i].trim(), style: AppStyles.bodyMedium.copyWith(color: Colors.white70, height: 1.6)),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              // Pass translated steps to cooking mode if available
              final cookingSteps = (_isMalay && _transInstructions != null)
                  ? _transInstructions
                  : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CookingModeScreen(
                    recipeId: widget.recipeId,
                    recipe: _recipe ?? {},
                    translatedInstructions: cookingSteps,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(
                    'VIEW ALL ${steps.length} STEPS',
                    style: AppStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildIngredientsList(String raw) {
    final list = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final swappableKeywords = ['pork', 'wine', 'alcohol', 'beer', 'beef', 'chicken', 'meat', 'bacon', 'ham', 'lard', 'shrimp', 'crab', 'prawn', 'fish', 'tofu', 'cheese', 'milk', 'cream', 'butter', 'rum', 'brandy', 'vodka', 'whiskey', 'sauce'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: list.map((ing) {
        final isChecked = _checkedIngredients.contains(ing);
        final isSwappable = swappableKeywords.any((k) => ing.toLowerCase().contains(k));
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() {
                if (isChecked) _checkedIngredients.remove(ing);
                else _checkedIngredients.add(ing);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: NeoGlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: BorderRadius.circular(16),
                  borderColor: isChecked ? AppColors.accent : AppColors.glassBorder,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChecked ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isChecked ? AppColors.accent : Colors.white30,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          ing,
                          style: AppStyles.bodyMedium.copyWith(
                            color: isChecked ? Colors.white : Colors.white70,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isSwappable) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showSwapSuggestions(ing),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                            ),
                            child: const Text(
                              '✨ swap',
                              style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showSwapSuggestions(String ingredient) async {
    // Clean ingredient name
    final cleanIngredient = ingredient.toLowerCase()
        .replaceAll(RegExp(r'^\d+\s*(cup|tsp|tbsp|g|kg|ml|l|oz|lb|piece|clove|stalk|slice|can|jar|bottle|pack|bunch)\s+'), '')
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NeoGlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        child: FutureBuilder(
          future: _fetchAISubstitutes(cleanIngredient),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox(height: 100, child: Center(child: Text("No suggestions found")));
            }

            final subs = snapshot.data as List;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Substitutes for '$cleanIngredient'", style: AppStyles.h3),
                const SizedBox(height: 20),
                ...subs.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(s[1], style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<List> _fetchAISubstitutes(String ingredient) async {
    final token = await _getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/get-substitute'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'ingredient': ingredient}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['substitutes'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Widget _buildModernActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _actionTile(Icons.share_rounded, 'Share', const Color(0xFF3B82F6), _shareRecipe)),
            const SizedBox(width: 12),
            Expanded(child: _actionTile(Icons.print_rounded, 'Print', const Color(0xFF8B5CF6), _printRecipe)),
          ],
        ),
        const SizedBox(height: 12),
        _actionTile(Icons.picture_as_pdf_rounded, 'Export High-Quality PDF', const Color(0xFF10B981), _downloadPdf, isFull: true),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap, {bool isFull = false}) {
    return GestureDetector(
      onTap: () {
        debugPrint('ChefGPT: $label button tapped');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: NeoGlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        borderColor: color.withOpacity(0.3),
        child: Row(
          mainAxisAlignment: isFull ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartCookingBtn() {
    return GestureDetector(
      onTap: () {
        final cookingSteps = (_isMalay && _transInstructions != null)
            ? _transInstructions
            : null;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CookingModeScreen(
              recipeId: widget.recipeId,
              recipe: _recipe ?? {},
              translatedInstructions: cookingSteps,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.outdoor_grill_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('START COOKING MODE', style: AppStyles.h3.copyWith(color: Colors.white, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return GestureDetector(
      onTap: _openFeedback,
      child: NeoGlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Text('Ratings & Reviews', style: AppStyles.h3),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${_recipe?['rating'] ?? '5.0'}', style: AppStyles.h1.copyWith(fontSize: 40)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) => Icon(
                        Icons.star_rounded, 
                        color: i < 4 ? AppColors.accent : Colors.white10, 
                        size: 20
                      )),
                    ),
                    const SizedBox(height: 4),
                    Text('${_feedbacks.length} Reviews', style: AppStyles.caption),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return _buildFeedbackSection();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: AppStyles.h3.copyWith(fontSize: 20)),
    );
  }

  Widget _buildFixedBottomAction() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.8),
            border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 1.5)),
          ),
          child: _buildStartCookingBtn(),
        ),
      ),
    );
  }

  void _openFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeedbackSheet(
        recipeId: widget.recipeId,
        feedbacks: _feedbacks,
        onSubmit: (rating, comment) async {
          final token = await _getToken();
          await http.post(
            Uri.parse('$baseUrl/api/submit-feedback/${widget.recipeId}'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'rating': rating, 'comment': comment}),
          );
        },
        onFetch: () async {
          await _fetchFeedbacks();
          return _feedbacks;
        },
      ),
    );
  }

  Future<void> _shareRecipe() async {
    final recipe = _recipe ?? {};
    final shareUrl = '$baseUrl/recipe/${widget.recipeId}';
    final text = '🍳 Check out this recipe: ${recipe['recipe_name'] ?? 'Recipe'}!\n\n'
        '🍽️ Cuisine: ${recipe['cuisine'] ?? 'General'}\n'
        '🔥 Calories: ${recipe['calories'] ?? 'N/A'} cal\n'
        '⭐ Rating: ${recipe['rating'] ?? '5.0'}/5\n\n'
        'View the full recipe here:\n$shareUrl\n\n'
        'Shared from ChefGPT 👨‍🍳';
    
    await Share.share(text, subject: recipe['recipe_name']?.toString() ?? 'Recipe');
  }

  Future<void> _printRecipe() async {
    final recipeData = _recipe;
    if (recipeData == null) {
      _showSnack('Recipe data is not ready.', isError: true);
      return;
    }
    try {
      _showSnack('Opening full preview...', isError: false);
      final doc = await _buildPdfDocument(format: PdfPageFormat.a4);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipePrintPreviewScreen(
            doc: doc,
            recipeName: recipeData['recipe_name']?.toString() ?? 'Recipe',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Printing Error: $e');
      _showSnack('Could not open preview: $e', isError: true);
    }
  }

  Future<void> _downloadPdf() async {
    final recipeData = _recipe;
    if (recipeData == null) {
      _showSnack('Recipe data is not ready.', isError: true);
      return;
    }
    try {
      _showSnack('Generating PDF...', isError: false);
      final doc = await _buildPdfDocument(format: PdfPageFormat.a4);
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes, 
        filename: '${(recipeData['recipe_name']?.toString() ?? 'Recipe').replaceAll(' ', '_')}.pdf'
      );
    } catch (e) {
      debugPrint('PDF Error: $e');
      _showSnack('Could not generate PDF: $e', isError: true);
    }
  }

  String _stripEmojis(String text) {
    return text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}]', unicode: true), '');
  }

  Future<pw.Document> _buildPdfDocument({PdfPageFormat format = PdfPageFormat.a4}) async {
    final recipe = _recipe ?? {};
    final doc = pw.Document();
    
    final name = _stripEmojis(recipe['recipe_name']?.toString() ?? 'Recipe');
    final cuisine = _stripEmojis(recipe['cuisine']?.toString() ?? 'General');
    final calories = recipe['calories']?.toString() ?? 'N/A';
    
    final ingList = (recipe['ingredients'] ?? '').toString()
        .split(',')
        .map((s) => _stripEmojis(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();
        
    final stepList = splitRecipeInstructions(recipe['instructions'])
        .map((s) => _stripEmojis(s))
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.deepPurple, width: 2))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(cuisine.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(width: 15),
                        pw.Text('$calories CALORIES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                      ],
                    ),
                  ],
                ),
                pw.Text('ChefGPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Ingredients', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: ingList.map((ing) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                children: [
                  pw.Container(width: 4, height: 4, decoration: const pw.BoxDecoration(color: PdfColors.grey700, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 8),
                  pw.Text(ing, style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            )).toList(),
          ),
          pw.SizedBox(height: 25),
          pw.Text('Instructions', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          ...stepList.asMap().entries.map((e) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${e.key + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Expanded(
                  child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                ),
              ],
            ),
          )),
          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated by ChefGPT AI Personal Assistant', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
    return doc;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.accent),
          const SizedBox(height: 16),
          Text('Recipe Not Found', style: AppStyles.h2),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeoGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text('Go Back', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

