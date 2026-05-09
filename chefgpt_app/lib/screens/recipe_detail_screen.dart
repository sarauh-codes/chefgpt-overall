import '../constants.dart';
import '../utils/recipe_format.dart';
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

  @override
  void initState() {
    super.initState();
    _auroraController =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAll();
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
          _buildTopNav(),
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
              child: NeoGlassContainer(
                padding: const EdgeInsets.all(10),
                borderRadius: BorderRadius.circular(50),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _shareRecipe,
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.all(10),
                    borderRadius: BorderRadius.circular(50),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSaving ? null : _toggleSave,
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
    final recipe = _recipe!;
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
                    _compactInfo(Icons.timer_rounded, '45 min'),
                    _compactInfo(Icons.restaurant_rounded, 'Easy'),
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
            'This premium ${(_recipe!['cuisine'] ?? 'general').toLowerCase()} dish is meticulously crafted for the best flavour experience. Follow the steps carefully to achieve chef-quality results.',
            style: AppStyles.bodyMedium.copyWith(color: Colors.white70, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),
        _buildModernActionButtons(),
      ],
    );
  }

  Widget _buildIngredientsTab() {
    return _buildIngredientsList(_recipe!['ingredients'] ?? '');
  }

  Widget _buildStepsTab() {
    final raw = _recipe!['instructions'] ?? '';
    final steps = splitRecipeInstructions(raw).where((s) => s.trim().isNotEmpty).toList();
    final visibleSteps = steps.take(3).toList();
    final hasMore = steps.length > 3;

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: const [0.0, 0.7, 1.0],
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CookingModeScreen(recipeId: widget.recipeId, recipe: _recipe!))),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: list.map((ing) {
        final isChecked = _checkedIngredients.contains(ing);
        return GestureDetector(
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
                  Text(
                    ing,
                    style: AppStyles.bodyMedium.copyWith(
                      color: isChecked ? Colors.white : Colors.white70,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
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
      onTap: onTap,
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CookingModeScreen(recipeId: widget.recipeId, recipe: _recipe!))),
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
                Text('${_recipe!['rating'] ?? '5.0'}', style: AppStyles.h1.copyWith(fontSize: 40)),
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
    final recipe = _recipe!;
    final shareUrl = '$baseUrl/recipe/${widget.recipeId}';
    final text = '🍳 Check out this recipe: ${recipe['recipe_name']}!\n\n'
        '🍽️ Cuisine: ${recipe['cuisine']}\n'
        '🔥 Calories: ${recipe['calories']} cal\n'
        '⭐ Rating: ${recipe['rating']}/5\n\n'
        'View the full recipe here:\n$shareUrl\n\n'
        'Shared from ChefGPT 👨‍🍳';
    
    await Share.share(text, subject: recipe['recipe_name']);
  }

  Future<void> _printRecipe() async {
    final doc = await _buildPdfDocument();
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _downloadPdf() async {
    final doc = await _buildPdfDocument();
    await Printing.sharePdf(bytes: await doc.save(), filename: '${_recipe!['recipe_name']}.pdf');
  }

  Future<pw.Document> _buildPdfDocument() async {
    final recipe = _recipe!;
    final doc = pw.Document();
    final ingredients = recipe['ingredients'].toString().split(',');
    final steps = splitRecipeInstructions(recipe['instructions']);

    doc.addPage(pw.MultiPage(build: (context) => [
      pw.Text(recipe['recipe_name'], style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Text('Ingredients', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      ...ingredients.map((i) => pw.Text('• ${i.trim()}')),
      pw.SizedBox(height: 20),
      pw.Text('Instructions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      ...steps.asMap().entries.map((e) => pw.Text('${e.key + 1}. ${e.value.trim()}')),
    ]));
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

