import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'login_screen.dart';
import 'recipe_detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _maxCalController = TextEditingController();
  final TextEditingController _minRatingController = TextEditingController();

  String? _selectedCuisine;
  String _difficulty = 'any';
  String _baseIngredient = '';

  List<String> _cuisines = [];
  int _mealPlanValidDays = 7;
  List<Map<String, dynamic>> _days = [];
  String? _expiryBanner;
  String? _notice;
  bool _loadingMeta = true;
  bool _loadingAction = false;
  String _error = '';
  late AnimationController _auroraController;

  bool get _usingBaseMode => _baseIngredient.trim().isNotEmpty;
  bool get _usingOtherMode {
    final hasCuisine = _selectedCuisine != null && _selectedCuisine!.trim().isNotEmpty;
    final hasMaxCal = _maxCalController.text.trim().isNotEmpty;
    final hasMinRating = _minRatingController.text.trim().isNotEmpty;
    final hasDifficulty = _difficulty != 'any';
    return hasCuisine || hasMaxCal || hasMinRating || hasDifficulty;
  }

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _loadMeta();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _maxCalController.dispose();
    _minRatingController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = '';
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/meal-plan-week'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
        return;
      }

      if (response.statusCode != 200) {
        setState(() => _error = 'Could not load meal planner.');
        return;
      }

      final data = jsonDecode(response.body);
      final saved = data['saved_plan'];
      List<Map<String, dynamic>> rows = [];
      if (saved != null && saved is Map && saved['plan'] is List) {
        rows = List<Map<String, dynamic>>.from(
          (saved['plan'] as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
      }

      setState(() {
        _cuisines = List<String>.from(data['cuisines'] ?? []);
        _mealPlanValidDays = data['meal_plan_valid_days'] ?? 7;
        _days = rows;
        _expiryBanner = (saved != null && saved is Map && saved['expires_display'] != null) 
            ? 'Clears on ${saved['expires_display']}' 
            : null;
      });
    } catch (e) {
      setState(() => _error = 'Cannot connect to server.');
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _randomizeWeek() async {
    setState(() {
      _loadingAction = true;
      _error = '';
      _notice = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final payload = <String, dynamic>{
        'difficulty': _usingBaseMode ? 'any' : _difficulty,
      };
      
      if (!_usingBaseMode) {
        if (_selectedCuisine != null) payload['cuisine'] = _selectedCuisine;
        
        final maxCal = int.tryParse(_maxCalController.text);
        if (maxCal != null) payload['max_calories'] = maxCal;
        
        final minRating = double.tryParse(_minRatingController.text);
        if (minRating != null) payload['min_rating'] = minRating;
      } else {
        payload['base_ingredient'] = _baseIngredient;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/meal-plan-week'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map && data['plan'] is List) {
        setState(() {
          _days = List<Map<String, dynamic>>.from(
            (data['plan'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          );
          _expiryBanner = data['expires_display'] != null ? 'Clears on ${data['expires_display']}' : null;
          _notice = data['notice'];
        });
      } else {
        setState(() => _error = data['error'] ?? 'Could not build meal plan.');
      }
    } catch (e) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _clearPlan() async {
    setState(() {
      _loadingAction = true;
      _error = '';
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/meal-plan-week'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _days = [];
          _expiryBanner = null;
          _notice = null;
        });
      } else {
        setState(() => _error = 'Could not clear your plan.');
      }
    } catch (e) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loadingAction = false);
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
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Your Weekly Plan'),
                        const SizedBox(height: 16),
                        if (_error.isNotEmpty) _buildErrorBanner(),
                        if (_notice != null) _buildNoticeBanner(),
                        if (_expiryBanner != null) _buildExpiryBanner(),
                        const SizedBox(height: 16),
                        ..._buildDayTiles(),
                      ],
                    ),
                  ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 8),
          Text('Meal Planner', style: AppStyles.h2),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return NeoGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCuisineDropdown(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField('Max Calories', _maxCalController, Icons.local_fire_department_rounded, enabled: !_usingBaseMode)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Min Rating', _minRatingController, Icons.star_rounded, enabled: !_usingBaseMode)),
            ],
          ),
          const SizedBox(height: 16),
          _buildDifficultyDropdown(),
          const SizedBox(height: 16),
          _buildBaseIngredientDropdown(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildActionButton('RANDOMIZE', _randomizeWeek, isPrimary: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton('CLEAR', _clearPlan, isPrimary: false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuisineDropdown() {
    return Opacity(
      opacity: _usingBaseMode ? 0.4 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cuisine', style: AppStyles.caption),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCuisine,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                hint: Text('Any Cuisine', style: AppStyles.bodyMedium.copyWith(color: Colors.white38)),
                style: AppStyles.bodyMedium.copyWith(color: Colors.white),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Any Cuisine')),
                  ..._cuisines.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                ],
                onChanged: _usingBaseMode ? null : (v) => setState(() => _selectedCuisine = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    return Opacity(
      opacity: _usingBaseMode ? 0.4 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Difficulty', style: AppStyles.caption),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _difficulty,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: AppStyles.bodyMedium.copyWith(color: Colors.white),
                items: ['any', 'easy', 'medium', 'hard'].map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase()))).toList(),
                onChanged: _usingBaseMode ? null : (v) => setState(() => _difficulty = v ?? 'any'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseIngredientDropdown() {
    return Opacity(
      opacity: _usingOtherMode ? 0.4 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Base Ingredient Focus', style: AppStyles.caption),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _baseIngredient,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: AppStyles.bodyMedium.copyWith(color: Colors.white),
                items: ['', 'rice', 'pasta', 'noodles', 'potato', 'bread', 'quinoa'].map((i) => DropdownMenuItem(value: i, child: Text(i.isEmpty ? 'Any Base' : i.toUpperCase()))).toList(),
                onChanged: _usingOtherMode ? null : (v) => setState(() => _baseIngredient = v ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppStyles.caption),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              style: AppStyles.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: AppColors.accent, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap, {required bool isPrimary}) {
    return GestureDetector(
      onTap: _loadingAction ? null : onTap,
      child: Container(
        height: 48,
        decoration: isPrimary ? AppDecorations.primaryButton : BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: _loadingAction && isPrimary
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: AppStyles.buttonText.copyWith(fontSize: 13)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppStyles.h2.copyWith(fontSize: 20));
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(_error, style: AppStyles.caption.copyWith(color: Colors.redAccent)),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(_notice!, style: AppStyles.caption.copyWith(color: Colors.greenAccent)),
    );
  }

  Widget _buildExpiryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.accent, size: 16),
          const SizedBox(width: 12),
          Text(_expiryBanner!, style: AppStyles.caption.copyWith(color: AppColors.accent)),
        ],
      ),
    );
  }

  List<Widget> _buildDayTiles() {
    if (_days.isEmpty) {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NeoGlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(d, style: AppStyles.bodyLarge.copyWith(color: Colors.white38)),
              const Spacer(),
              const Icon(Icons.remove_circle_outline_rounded, color: Colors.white12, size: 16),
            ],
          ),
        ),
      )).toList();
    }
    return _days.map((day) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          final ridRaw = day['recipe_id'];
          final rid = int.tryParse(ridRaw.toString()) ?? 0;
          if (rid > 0) Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: rid)));
        },
        child: NeoGlassContainer(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Recipe Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                  child: day['image_url'] != null && day['image_url'].toString().isNotEmpty
                      ? Image.network(day['image_url'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white24))
                      : const Icon(Icons.restaurant_rounded, color: Colors.white24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day['day']?.toString().toUpperCase() ?? '', style: AppStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(day['recipe_name'] ?? 'No Recipe', style: AppStyles.bodyLarge.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${day['cuisine'] ?? 'Any'} · ${day['calories'] ?? '---'} cal', style: AppStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    )).toList();
  }
}
