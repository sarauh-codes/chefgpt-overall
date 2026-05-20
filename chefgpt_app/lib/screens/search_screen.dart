import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import '../widgets/dashboard/recipe_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCuisine;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCuisine,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _aiSuggestions = [];
  bool _isLoading = false;
  bool _isAiLoading = false;
  String _errorMessage = '';

  // Filter States
  String _selectedCuisine = '';
  String _selectedTime = '';
  String _selectedPortions = '';

  // Options matching the Web experience
  final List<String> _cuisines = [
    'Malay',
    'Chinese',
    'Indian',
    'Western',
    'Italian',
    'Mexican',
    'Japanese',
    'Thai',
    'Dessert',
    'Bakery',
    'Asian',
    'Salad',
    'Pasta & Noodles'
  ];

  final List<Map<String, String>> _times = [
    {'value': '15', 'label': 'Under 15 min'},
    {'value': '30', 'label': 'Under 30 min'},
    {'value': '45', 'label': 'Under 45 min'},
    {'value': '60', 'label': 'Under 60 min'},
  ];

  final List<String> _portions = ['2', '3', '4'];

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Prepopulate initial filters if supplied
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialCuisine != null) {
      _selectedCuisine = widget.initialCuisine!;
    }

    // Trigger initial search
    _triggerSearch();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _triggerSearch() async {
    setState(() {
      _isLoading = true;
      _isAiLoading = false;
      _errorMessage = '';
      _recipes = [];
      _aiSuggestions = [];
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final query = _searchController.text.trim();

    // Build URL with query parameters exactly matching the Flask backend filters
    var url = '$baseUrl/api/search-recipes?q=${Uri.encodeComponent(query)}';
    if (_selectedCuisine.isNotEmpty) {
      url += '&cuisine=${Uri.encodeComponent(_selectedCuisine)}';
    }
    if (_selectedTime.isNotEmpty) {
      url += '&time=$_selectedTime';
    }
    if (_selectedPortions.isNotEmpty) {
      url += '&portions=$_selectedPortions';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recipes = List<Map<String, dynamic>>.from(data['recipes'] ?? []);
          _isLoading = false;
          if (data['trigger_ai'] == true) {
            _isAiLoading = true;
          }
        });

        // Stage 2: Load AI suggested creative recipes if search triggered them
        if (data['trigger_ai'] == true) {
          _loadAiSuggestions(query);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to find recipes.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Cannot connect to server.';
      });
    }
  }

  Future<void> _loadAiSuggestions(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final aiRes = await http.get(
        Uri.parse('$baseUrl/api/ai-search-suggestions?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (aiRes.statusCode == 200) {
        final aiData = jsonDecode(aiRes.body);
        setState(() {
          _aiSuggestions = List<Map<String, dynamic>>.from(aiData['suggestions'] ?? []);
          _isAiLoading = false;
        });
      } else {
        setState(() => _isAiLoading = false);
      }
    } catch (_) {
      setState(() => _isAiLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _triggerSearch();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCuisine = '';
      _selectedTime = '';
      _selectedPortions = '';
      _searchController.clear();
    });
    _triggerSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Unified Aurora Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (context, _) => CustomPaint(
                painter: AuroraPainter(_auroraController.value),
              ),
            ),
          ),

          // ── Scrollable Content Area ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchInput(),
                _buildFilterChipsRow(),
                Expanded(
                  child: _buildResultsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
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
          const SizedBox(width: 16),
          Text(
            'Search Recipes',
            style: AppStyles.h1.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: AppStyles.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search recipes, cuisines, ingredients...',
            hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary),
                    onPressed: () {
                      _searchController.clear();
                      _triggerSearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    final hasActiveFilters = _selectedCuisine.isNotEmpty ||
        _selectedTime.isNotEmpty ||
        _selectedPortions.isNotEmpty ||
        _searchController.text.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // cuisine dropdown/sheet chip
          _buildFilterChip(
            label: _selectedCuisine.isEmpty ? '🍽️ Cuisine' : '🍽️ $_selectedCuisine',
            isActive: _selectedCuisine.isNotEmpty,
            onTap: _showCuisineSelector,
          ),
          const SizedBox(width: 8),

          // time dropdown/sheet chip
          _buildFilterChip(
            label: _selectedTime.isEmpty
                ? '⏱️ Time'
                : '⏱️ ${_times.firstWhere((x) => x['value'] == _selectedTime)['label']}',
            isActive: _selectedTime.isNotEmpty,
            onTap: _showTimeSelector,
          ),
          const SizedBox(width: 8),

          // portion size dropdown/sheet chip
          _buildFilterChip(
            label: _selectedPortions.isEmpty ? '👥 Portions' : '👥 $_selectedPortions portions',
            isActive: _selectedPortions.isNotEmpty,
            onTap: _showPortionSelector,
          ),

          if (hasActiveFilters) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _resetFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Text(
                  'Reset Filters',
                  style: AppStyles.caption.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.accent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppStyles.caption.copyWith(
                color: isActive ? AppColors.accent : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isActive ? AppColors.accent : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  void _showCuisineSelector() {
    _showBottomSelector(
      title: 'Filter by Cuisine',
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _cuisines.length + 1,
        itemBuilder: (context, index) {
          final isAny = index == 0;
          final cuisineName = isAny ? 'Any Category' : _cuisines[index - 1];
          final isSelected = isAny ? _selectedCuisine.isEmpty : _selectedCuisine == cuisineName;

          return _buildSelectorRow(
            label: cuisineName,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedCuisine = isAny ? '' : cuisineName;
              });
              Navigator.pop(context);
              _triggerSearch();
            },
          );
        },
      ),
    );
  }

  void _showTimeSelector() {
    _showBottomSelector(
      title: 'Filter by Cooking Time',
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _times.length + 1,
        itemBuilder: (context, index) {
          final isAny = index == 0;
          final timeVal = isAny ? '' : _times[index - 1]['value']!;
          final timeLabel = isAny ? 'Any Time' : _times[index - 1]['label']!;
          final isSelected = isAny ? _selectedTime.isEmpty : _selectedTime == timeVal;

          return _buildSelectorRow(
            label: timeLabel,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedTime = timeVal;
              });
              Navigator.pop(context);
              _triggerSearch();
            },
          );
        },
      ),
    );
  }

  void _showPortionSelector() {
    _showBottomSelector(
      title: 'Filter by Portion Size',
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _portions.length + 1,
        itemBuilder: (context, index) {
          final isAny = index == 0;
          final portionVal = isAny ? '' : _portions[index - 1];
          final portionLabel = isAny ? 'Any Portions' : '$portionVal Portions';
          final isSelected = isAny ? _selectedPortions.isEmpty : _selectedPortions == portionVal;

          return _buildSelectorRow(
            label: portionLabel,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedPortions = portionVal;
              });
              Navigator.pop(context);
              _triggerSearch();
            },
          );
        },
      ),
    );
  }

  void _showBottomSelector({required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: AppStyles.h3.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    child,
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectorRow({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: AppStyles.bodyMedium.copyWith(
          color: isSelected ? AppColors.accent : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
          : const Icon(Icons.circle_outlined, color: Colors.white30),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white30, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: AppStyles.bodyMedium.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (_recipes.isEmpty && _aiSuggestions.isEmpty && !_isAiLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              'No matching recipes found',
              style: AppStyles.h3.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refining your search terms or expanding filter options',
              style: AppStyles.caption.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Tab indicator like the web Count tag
        if (_recipes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  'Recipes Found',
                  style: AppStyles.caption.copyWith(color: Colors.white60, letterSpacing: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_recipes.length}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._recipes.map((recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: RecipeCard(recipe: recipe),
              )),
        ],

        // AI search loading trigger spinner
        if (_isAiLoading) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  'ChefGPT is thinking of more creative ideas...',
                  style: AppStyles.caption.copyWith(color: Colors.purpleAccent),
                ),
              ],
            ),
          ),
        ],

        // Dynamic ChefGPT's Creative Ideas block
        if (_aiSuggestions.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                "ChefGPT's Creative Ideas",
                style: AppStyles.h3.copyWith(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._aiSuggestions.map((recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: RecipeCard(recipe: {
                  ...recipe,
                  'is_ai': true, // Add flag to render AI SUGGESTED badge
                }),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}
