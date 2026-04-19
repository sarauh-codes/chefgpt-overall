import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';

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
                gradient: const LinearGradient(
                  colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
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
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: _isLoadingProfile
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                  : _buildContent(scrollController),
            ),
          ],
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
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🥗 Dietary Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Text(
          'Your settings affect which recipes we recommend to you.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_alertMessage.isNotEmpty) _buildAlert(),
        _sectionLabel('🍽️ Diet Type'),
        const SizedBox(height: 6),
        Text('Choose the diet that best describes you.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: _dietOptions.map((opt) => _dietOption(opt)).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        _sectionLabel('⚠️ Allergies'),
        const SizedBox(height: 6),
        Text('Will be filtered out from recommendations.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 10),
        _inputField(_allergiesController, 'e.g. peanuts, shellfish, gluten'),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        _sectionLabel('🚫 Forbidden Ingredients'),
        const SizedBox(height: 6),
        Text('Personal dislikes — not allergies.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 10),
        _inputField(_forbiddenController, 'e.g. coriander, anchovies'),
        const SizedBox(height: 28),
        _buildButtons(),
      ],
    );
  }

  Widget _buildAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _alertSuccess
            ? const Color(0xFF4ade80).withOpacity(0.12)
            : const Color(0xFFf87171).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _alertSuccess
              ? const Color(0xFF4ade80).withOpacity(0.3)
              : const Color(0xFFf87171).withOpacity(0.3),
        ),
      ),
      child: Text(
        _alertMessage,
        style: TextStyle(
          fontSize: 13,
          color: _alertSuccess
              ? const Color(0xFF276749)
              : const Color(0xFF9B2C2C),
          fontWeight: FontWeight.w500,
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
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
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('💾 Save & Apply',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }

  Widget _dietOption(Map<String, String> opt) {
    final selected = _selectedDiet == opt['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedDiet = opt['value']!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3EE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFF6B35) : const Color(0xFFFFE0D0),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(opt['label']!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF1A1A1A))),
            Text(opt['desc']!,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint) {
    return Focus(
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? const Color(0xFFFF6B35) : const Color(0xFFE0E0E0),
              width: 2,
            ),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      }),
    );
  }
}
