import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_glass_container.dart';

class DietaryDrawer extends StatefulWidget {
  const DietaryDrawer({super.key});

  @override
  State<DietaryDrawer> createState() => _DietaryDrawerState();
}

class _DietaryDrawerState extends State<DietaryDrawer> {
  String _selectedDiet = 'omnivore';
  final _allergiesController = TextEditingController();
  final _forbiddenController = TextEditingController();
  bool _isSaving = false;
  String _alertMessage = '';
  bool _alertSuccess = false;
  bool _isLoadingProfile = true;

  final List<Map<String, String>> _dietOptions = [
    {'value': 'omnivore', 'label': '🍽️ No Restrictions', 'desc': 'Eats everything'},
    {'value': 'vegetarian', 'label': '🥦 Vegetarian', 'desc': 'No meat, dairy & eggs ok'},
    {'value': 'vegan', 'label': '🌱 Vegan', 'desc': 'No animal products'},
    {'value': 'halal', 'label': '☪️ Halal', 'desc': 'No pork & alcohol'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDietaryProfile();
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _forbiddenController.dispose();
    super.dispose();
  }

  Future<void> _loadDietaryProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/diet-settings'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedDiet = data['diet_type'] ?? 'omnivore';
          _allergiesController.text = data['allergies'] ?? '';
          _forbiddenController.text = data['forbidden_ingredients'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('LOAD ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveDietaryProfile() async {
    setState(() {
      _isSaving = true;
      _alertMessage = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/diet-settings'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'diet_type': _selectedDiet,
          'allergies': _allergiesController.text,
          'forbidden_ingredients': _forbiddenController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context);
        _showSuccessOverlay();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _alertSuccess = false;
            _alertMessage = data['message'] ?? 'Failed to save settings.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alertSuccess = false;
          _alertMessage = 'Cannot connect to server.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessOverlay() {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Transform.translate(
              offset: Offset(0, -20 * (1 - value)),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Settings Saved!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text('Your dietary preferences have been updated.',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry?.remove());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 1.5)),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(),
                Expanded(
                  child: _isLoadingProfile
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.accent))
                      : _buildContent(scrollController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('🥗 Dietary Settings', style: AppStyles.h2.copyWith(fontSize: 20)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Text(
          'Your settings affect which recipes we recommend to you.',
          style: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        if (_alertMessage.isNotEmpty) _buildAlert(),
        _sectionLabel('🍽️ Diet Type'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: _dietOptions.map((opt) => _dietOption(opt)).toList(),
        ),
        const SizedBox(height: 32),
        _sectionLabel('⚠️ Allergies'),
        const SizedBox(height: 8),
        Text('Will be filtered out from recommendations.',
            style: AppStyles.caption.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 12),
        _inputField(_allergiesController, 'e.g. peanuts, shellfish, gluten'),
        const SizedBox(height: 32),
        _sectionLabel('🚫 Forbidden Ingredients'),
        const SizedBox(height: 8),
        Text('Personal dislikes — not allergies.',
            style: AppStyles.caption.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 12),
        _inputField(_forbiddenController, 'e.g. coriander, anchovies'),
        const SizedBox(height: 40),
        _buildButtons(),
      ],
    );
  }

  Widget _buildAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _alertSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alertSuccess ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        _alertMessage,
        style: TextStyle(color: _alertSuccess ? Colors.greenAccent : Colors.redAccent, fontSize: 13),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _isSaving ? null : _saveDietaryProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save & Apply', style: AppStyles.h3.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text('Cancel', style: AppStyles.bodyMedium.copyWith(color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppStyles.h3);
  }

  Widget _dietOption(Map<String, String> opt) {
    final selected = _selectedDiet == opt['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedDiet = opt['value']!),
      child: NeoGlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: selected ? AppColors.accent : AppColors.glassBorder,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(opt['label']!,
                style: AppStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(opt['desc']!,
                style: AppStyles.caption.copyWith(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        style: AppStyles.bodyMedium.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
