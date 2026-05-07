import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'login_screen.dart';
import 'recipe_detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
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

  static const Color _accent = Color(0xFFFF6B35);

  bool get _usingBaseMode => _baseIngredient.trim().isNotEmpty;

  bool get _usingOtherMode {
    final hasCuisine = _selectedCuisine != null && _selectedCuisine!.trim().isNotEmpty;
    final hasMaxCal = _maxCalController.text.trim().isNotEmpty;
    final hasMinRating = _minRatingController.text.trim().isNotEmpty;
    final hasDifficulty = _difficulty != 'any';
    return hasCuisine || hasMaxCal || hasMinRating || hasDifficulty;
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _maxCalController.dispose();
    _minRatingController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = '';
    });
    final token = await _token();
    if (!mounted) return;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/meal-plan-week'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

      if (response.statusCode != 200) {
        setState(() => _error = 'Could not load meal planner.');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final cuisines = List<String>.from(data['cuisines'] ?? []);
      final saved = data['saved_plan'];
      List<Map<String, dynamic>> rows = [];
      String? expiry;
      if (saved != null &&
          saved is Map &&
          saved['plan'] is List &&
          (saved['plan'] as List).length == 7) {
        rows = List<Map<String, dynamic>>.from(
          (saved['plan'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        expiry = saved['expires_display'] as String?;
      }

      setState(() {
        _cuisines = cuisines;
        _mealPlanValidDays = data['meal_plan_valid_days'] is int
            ? data['meal_plan_valid_days'] as int
            : 7;
        _days = rows;
        _expiryBanner =
            expiry != null && expiry.isNotEmpty ? 'Clears on $expiry.' : null;
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
    final token = await _token();
    try {
      final payload = <String, dynamic>{
        'difficulty': _usingBaseMode ? 'any' : _difficulty,
      };
      if (!_usingBaseMode &&
          _selectedCuisine != null &&
          _selectedCuisine!.trim().isNotEmpty) {
        payload['cuisine'] = _selectedCuisine!.trim();
      }
      final mc = _maxCalController.text.trim();
      if (!_usingBaseMode && mc.isNotEmpty) {
        final c = int.tryParse(mc);
        if (c != null) {
          payload['max_calories'] = c;
        }
      }
      final mr = _minRatingController.text.trim();
      if (!_usingBaseMode && mr.isNotEmpty) {
        final r = double.tryParse(mr);
        if (r != null) payload['min_rating'] = r;
      }
      if (_usingBaseMode) {
        payload['base_ingredient'] = _baseIngredient.trim();
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/meal-plan-week'),
            headers: _authHeaders(token),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 400) {
        final err = data is Map ? (data['error'] ?? '') : '';
        final avail = data is Map && data['available'] != null
            ? ' (${data['available']} recipe(s) match.)'
            : '';
        setState(() => _error = '$err$avail'.trim());
        return;
      }

      if (response.statusCode != 200 ||
          data is! Map ||
          data['plan'] is! List) {
        setState(() => _error = 'Could not build a meal plan.');
        return;
      }

      final plan = List<Map<String, dynamic>>.from(
        (data['plan'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      setState(() {
        _days = plan;
        _expiryBanner = data['expires_display'] != null
            ? 'Clears on ${data['expires_display']}.'
            : _expiryBanner;
        _notice =
            data['notice'] is String ? data['notice'] as String : null;
      });

    } catch (e) {
      setState(() => _error = 'Network error. Try again.');
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _clearPlan() async {
    setState(() {
      _loadingAction = true;
      _error = '';
    });
    final token = await _token();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/meal-plan-week'),
        headers: _authHeaders(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

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
      backgroundColor: const Color(0xFFFFFAF7),
      appBar: AppBar(
        title: const Text('Weekly Meal Planner'),
        foregroundColor: Colors.white,
        backgroundColor: _accent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMeta,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plans respect your dietary settings (edit from the dashboard drawer). Saved for $_mealPlanValidDays days.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              if (_notice != null && _notice!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FFF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF9AE6B4)),
                  ),
                  child: Text(
                    _notice!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF14532D),
                    ),
                  ),
                ),
              if (_expiryBanner != null && _expiryBanner!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FC),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.blue.withOpacity(0.35)),
                  ),
                  child: Text(
                    _expiryBanner!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              if (_error.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF9B2C2C)),
                  ),
                ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.orange.withOpacity(0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _loadingMeta
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: _accent),
                        ))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String?>(
                              decoration: const InputDecoration(
                                  labelText: 'Cuisine', border: OutlineInputBorder()),
                              isExpanded: true,
                              hint: const Text('Any cuisine'),
                              value: _selectedCuisine,
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('Any cuisine')),
                                ..._cuisines.map((c) => DropdownMenuItem<String?>(
                                      value: c,
                                      child: Text(c,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (_loadingAction || _usingBaseMode)
                                  ? null
                                  : (v) => setState(() => _selectedCuisine = v),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _maxCalController,
                              enabled: !_loadingAction && !_usingBaseMode,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max calories per meal',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _minRatingController,
                              enabled: !_loadingAction && !_usingBaseMode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Min rating (0–5)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                  labelText: 'Difficulty',
                                  border: OutlineInputBorder()),
                              value: _difficulty,
                              items: const [
                                DropdownMenuItem(
                                    value: 'any', child: Text('Any')),
                                DropdownMenuItem(
                                    value: 'easy', child: Text('Easy')),
                                DropdownMenuItem(
                                    value: 'medium', child: Text('Medium')),
                                DropdownMenuItem(
                                    value: 'hard', child: Text('Hard')),
                              ],
                              onChanged: (_loadingAction || _usingBaseMode)
                                  ? null
                                  : (v) => setState(
                                      () => _difficulty = v ?? 'any'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Base ingredient focus',
                                border: OutlineInputBorder(),
                              ),
                              value: _baseIngredient,
                              items: const [
                                DropdownMenuItem(
                                    value: '', child: Text('Any base')),
                                DropdownMenuItem(
                                    value: 'rice', child: Text('Rice')),
                                DropdownMenuItem(
                                    value: 'pasta', child: Text('Pasta')),
                                DropdownMenuItem(
                                    value: 'noodles', child: Text('Noodles')),
                                DropdownMenuItem(
                                    value: 'potato', child: Text('Potato')),
                                DropdownMenuItem(
                                    value: 'bread', child: Text('Bread')),
                                DropdownMenuItem(
                                    value: 'quinoa', child: Text('Quinoa')),
                              ],
                              onChanged: (_loadingAction || _usingOtherMode)
                                  ? null
                                  : (v) => setState(
                                      () => _baseIngredient = v ?? ''),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Base ingredient mode and the other filters cannot be combined.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_loadingMeta || _loadingAction)
                          ? null
                          : _randomizeWeek,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _loadingAction
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.casino_outlined),
                      label:
                          Text(_loadingAction ? 'Working…' : 'Randomize week'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_loadingMeta || _loadingAction)
                          ? null
                          : _clearPlan,
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Your week',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingMeta)
                const SizedBox.shrink()
              else ..._days.isEmpty ? _placeholderRows() : _dayTiles(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _placeholderRows() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days.map((d) => _tile(d, null)).toList();
  }

  List<Widget> _dayTiles() {
    return _days
        .map((m) => _tile(m['day']?.toString() ?? '', m))
        .toList();
  }

  int? _recipeId(Map<String, dynamic> item) {
    final raw = item['recipe_id'];
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _recipeDisplayName(Map<String, dynamic> item) {
    for (final key in const ['recipe_name', 'recipeName', 'name']) {
      final v = item[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return 'Untitled recipe';
  }

  Widget _thumbPlaceholder56() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey[400]),
    );
  }

  Widget _mealThumbnail(Map<String, dynamic> item) {
    final url = (item['image_url'] ?? '').toString().trim();
    final Widget thumb;
    if (url.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbPlaceholder56(),
        ),
      );
    } else {
      thumb = _thumbPlaceholder56();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: thumb,
    );
  }

  Widget _tile(String dayLabel, Map<String, dynamic>? item) {
    final empty = item == null;
    final rid = empty ? null : _recipeId(item!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: empty || rid == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(recipeId: rid),
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.grey[800],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!empty) _mealThumbnail(item!),
                    Expanded(
                      child: empty
                          ? Text(
                              '—',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _recipeDisplayName(item),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    height: 1.25,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['cuisine'] ?? ''} · ${item['calories']} cal · ★ ${item['rating']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black26),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
