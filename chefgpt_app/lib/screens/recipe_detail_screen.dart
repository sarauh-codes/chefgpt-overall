import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  Map<String, dynamic>? _recipe;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;
  int _selectedRating = 0;
  List _feedbacks = [];
  final _commentController = TextEditingController();
  bool _isSubmittingFeedback = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _ratingKey = GlobalKey();
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    _auroraController =
        AnimationController(vsync: this, duration: const Duration(seconds: 16))
          ..repeat();
    _loadAll();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _commentController.dispose();
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
        _showSnack('Recipe removed from saved!', isError: false);
        // Unsave
        await http.post(
          Uri.parse('$baseUrl/api/unsave-recipe/${widget.recipeId}'),
          headers: {'Authorization': 'Bearer $token'},
        );
        
      } else {
        // Save
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
      backgroundColor: isError ? Colors.red : const Color(0xFFFF6B35),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(
      bottom: 900,  
      left: 20,
      right: 20,
    ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(
        text:
            'Check out this recipe: ${_recipe?['recipe_name']} on ChefGPT!'));
    _showSnack('Link copied to clipboard!', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:const ChatFab(),
      backgroundColor: const Color(0xFFFFFAF7),
      body: AnimatedBuilder(
        animation: _auroraController,
        builder: (_, child) => Stack(children: [
          Positioned.fill(
              child: CustomPaint(
                  painter: AuroraPainter(_auroraController.value))),
          child!,
        ]),
        child: Column(children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6B35)))
                : _recipe == null
                    ? _buildErrorState()
                    : _buildBody(
                    )
          ),
        ]),
      ),
    );
  }

  // ── AppBar ──
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 8,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x4DFF6B35), blurRadius: 24, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Recipe Details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
            onPressed: _copyLink,
            tooltip: 'Share',
          ),
          // Save button
          GestureDetector(
            onTap: _isSaving ? null : _toggleSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _isSaved
                    ? Colors.white
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35), strokeWidth: 2))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSaved
                              ? const Color(0xFFFF6B35)
                              : Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSaved ? 'Saved' : 'Save',
                          style: TextStyle(
                            color: _isSaved
                                ? const Color(0xFFFF6B35)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildRatingSummary() {
  final total = _feedbacks.length;
  final avg = total == 0
      ? 0.0
      : _feedbacks.map((f) => (f['rating'] ?? 0) as int).reduce((a, b) => a + b) / total;

  return GestureDetector(
    onTap: () => showModalBottomSheet(
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
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'rating': rating, 'comment': comment}),
          );
        },
          onFetch: () async{
            await _fetchFeedbacks();
            return _feedbacks;
        },
      ),
    ).then((_) async {
      await _fetchFeedbacks();
      setState(() {});
    }),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)
        ],
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Ratings & Reviews',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFFF6B35)),
            ],
          ),
          const SizedBox(height: 16),

          // Average + stars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < avg.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFB800),
                      size: 20,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total ${total == 1 ? 'review' : 'reviews'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bars 5 → 1
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = _feedbacks
                .where((f) => (f['rating'] ?? 0) == star)
                .length;
            final percent = total == 0 ? 0.0 : count / total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('$star',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555))),
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded,
                      size: 12, color: Color(0xFFFFB800)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFFFF6B35),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    child: Text('$count',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'Tap to see all reviews & rate',
              style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFFF6B35).withOpacity(0.8),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}
  // ── Main Body ──
Widget _buildBody() {
  final recipe = _recipe!;

  final ingredients = (recipe['ingredients'] ?? '')
      .toString()
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final instructions =
      (recipe['instructions'] ?? '').toString().split(' | ');

  return SingleChildScrollView(
    controller: _scrollController,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero Card ──
        _buildHeroCard(recipe),
        const SizedBox(height: 20),

        // ── Meta Tags ──
        _buildMetaTags(recipe),
        const SizedBox(height: 20),
        // ── Action Buttons ──
        _buildActionButtons(),
        const SizedBox(height: 20),

        // ── Ingredients ──
        _buildSectionCard(
          title: '📝 Ingredients',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients.map((ing) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFFFF6B35)),
                  const SizedBox(width: 6),
                  Text(
                    ing,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ── Instructions ──
        _buildSectionCard(
          title: '👨‍🍳 Instructions',
          child: Column(
            children: List.generate(
              instructions.where((i) => i.trim().isNotEmpty).length,
              (i) {
                final steps =
                    instructions.where((s) => s.trim().isNotEmpty).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 12, top: 2),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0xFFFF6B35),
                            Color(0xFFF7931E)
                          ]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      Expanded(
                        child: Text(steps[i].trim(),
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF333333),
                                height: 1.6)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Start Cooking ──
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CookingModeScreen(
                    recipeId: widget.recipeId,
                    recipe: _recipe!,
                  ),
                ),
              );
              if (result == 'rate' && mounted) {
                await Future.delayed(const Duration(milliseconds: 400));
                Scrollable.ensureVisible(
                  _ratingKey.currentContext!,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🍳 Start Cooking',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
// ── Reviews & Rating ──
// ── Rating Summary ──
_buildRatingSummary(),
const SizedBox(height: 16),
      ],
    ),
  );} 

  // ── Hero Card ──
  Widget _buildHeroCard(Map<String, dynamic> recipe) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe['recipe_name'] ?? 'Recipe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe['cuisine'] ?? '',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  // ── Meta Tags ──
  Widget _buildMetaTags(Map<String, dynamic> recipe) {
    final difficulty = recipe['difficulty']?.toString().toLowerCase() ?? '';
    final diffColor = difficulty == 'easy'
        ? Colors.green
        : difficulty == 'medium'
            ? Colors.orange
            : Colors.red;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metaTag('🍽️ ${recipe['cuisine'] ?? ''}'),
        _metaTag('🔥 ${recipe['calories']} cal'),
        _metaTag('⭐ ${recipe['rating']}/5'),
        if (difficulty.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: diffColor.withOpacity(0.3)),
            ),
            child: Text(
              difficulty[0].toUpperCase() + difficulty.substring(1),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: diffColor),
            ),
          ),
      ],
    );
  }

  Widget _metaTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06), blurRadius: 8)
        ],
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.15)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333))),
    );
  }

  // ── Section Card ──
  Widget _buildSectionCard(
      {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 16)
        ],
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orange left border title
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Feedback Card ──
  Widget _buildFeedbackCard(dynamic fb) {
    final rating = fb['rating'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF7),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFF6B35).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(0xFFFF6B35).withOpacity(0.15),
                child: Text(
                  (fb['username'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fb['username'] ?? 'User',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1A1A1A))),
                    Text(fb['created_at'] ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: i < rating
                              ? const Color(0xFFFFB800)
                              : Colors.grey[300],
                          size: 16,
                        )),
              ),
            ],
          ),
          if (fb['comment'] != null &&
              fb['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(fb['comment'],
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF555555),
                    height: 1.5)),
          ],
        ],
      ),
    );
  }
Future<void> _shareRecipe() async {
  final recipe = _recipe!;
  final name = recipe['recipe_name'] ?? 'Recipe';
  final cuisine = recipe['cuisine'] ?? '';
  final calories = recipe['calories'] ?? '';
  final ingredients = (recipe['ingredients'] ?? '').toString();
  final text = '🍳 $name\n'
      '🍽️ Cuisine: $cuisine\n'
      '🔥 Calories: $calories cal\n\n'
      '📝 Ingredients:\n$ingredients\n\n'
      'Shared from ChefGPT 👨‍🍳';
  await Share.share(text, subject: name);
}

Future<void> _printRecipe() async {
  final doc = await _buildPdfDocument();
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

Future<void> _downloadPdf() async {
  try {
    final doc = await _buildPdfDocument();
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: '${_recipe!['recipe_name'] ?? 'recipe'}.pdf',
    );
    _showSnack('PDF downloaded!', isError: false);
  } catch (e) {
    _showSnack('Failed to generate PDF', isError: true);
  }
}

Future<pw.Document> _buildPdfDocument() async {
  final recipe = _recipe!;
  final doc = pw.Document();

  final ingredients = (recipe['ingredients'] ?? '')
      .toString()
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final instructions = (recipe['instructions'] ?? '')
      .toString()
      .split(' | ')
      .where((s) => s.trim().isNotEmpty)
      .toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          recipe['recipe_name'] ?? 'Recipe',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '${recipe['cuisine'] ?? ''} • ${recipe['calories']} cal • ${recipe['rating']}/5',
          style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
        ),
        pw.Divider(height: 24),
        pw.Text('Ingredients',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...ingredients.map((ing) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('• $ing', style: const pw.TextStyle(fontSize: 13)),
            )),
        pw.SizedBox(height: 16),
        pw.Text('Instructions',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...instructions.asMap().entries.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${e.key + 1}. ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Expanded(
                    child: pw.Text(e.value.trim(),
                        style: const pw.TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )),
        pw.SizedBox(height: 20),
        pw.Text('Generated by ChefGPT ',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
      ],
    ),
  );
  return doc;
}
Widget _buildActionButtons() {
  return Row(
    children: [
      _actionBtn(
        icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
        label: _isSaved ? 'Saved' : 'Save',
        color: const Color(0xFFFF6B35),
        onTap: _isSaving ? null : _toggleSave,
      ),
      const SizedBox(width: 10),
      _actionBtn(
        icon: Icons.share_rounded,
        label: 'Share',
        color: const Color(0xFF3B82F6),
        onTap: _shareRecipe,
      ),
      const SizedBox(width: 10),
      _actionBtn(
        icon: Icons.print_rounded,
        label: 'Print',
        color: const Color(0xFF8B5CF6),
        onTap: _printRecipe,
      ),
      const SizedBox(width: 10),
      _actionBtn(
        icon: Icons.picture_as_pdf_rounded,
        label: 'PDF',
        color: const Color(0xFF22C55E),
        onTap: _downloadPdf,
      ),
    ],
  );
}

Widget _actionBtn({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback? onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  // ── Error State ──
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 16),
          const Text('Recipe not found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back',
                style: TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }
}

