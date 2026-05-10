import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'recipe_detail_screen.dart';
import 'chat_fab.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen>
    with SingleTickerProviderStateMixin {
  final _ingredientsController = TextEditingController();
  final _voiceIngredientsController = TextEditingController();
  final _imageIngredientsController = TextEditingController();

  List _recommendations = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final Map<String, String> _substituteResults = {};
  final Map<String, bool> _substituteLoading = {};
  late AnimationController _auroraController;

  // Tab state
  int _activeTab = 0; // 0 = text, 1 = voice, 2 = image

  // Voice state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _voiceStatus = '';
  bool _voiceResultVisible = false;

  // Image state
  bool _isAnalyzingImage = false;
  String _imageStatus = '';
  bool _imageResultVisible = false;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _ingredientsController.dispose();
    _voiceIngredientsController.dispose();
    _imageIngredientsController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    if (_ingredientsController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter at least one ingredient.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recommendations = [];
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recommendations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ingredients': _ingredientsController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendations = data['recommendations'] ?? [];
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['message'] ??
              data['error'] ??
              'Failed to get recommendations.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Check your server settings.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getSubstitute(String ingredient, String key) async {
    if (_substituteResults.containsKey(key)) {
      setState(() => _substituteResults.remove(key));
      return;
    }

    setState(() => _substituteLoading[key] = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/get-substitute'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ingredient': ingredient}),
      );

      final data = jsonDecode(response.body);
      final subs = data['substitutes'] as List? ?? [];

      setState(() {
        _substituteResults[key] = subs.isEmpty
            ? 'No substitute found'
            : subs.map((s) => s[0].toString()).join(' or ');
      });
    } catch (e) {
      setState(() => _substituteResults[key] = 'Error fetching substitute');
    } finally {
      setState(() => _substituteLoading.remove(key));
    }
  }

  // ===== VOICE =====
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      setState(() => _voiceStatus = '❌ Microphone permission denied.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recording.webm';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _voiceStatus = '🎙️ Recording... speak your ingredients now!';
      _voiceResultVisible = false;
      _voiceIngredientsController.clear();
    });
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
      _voiceStatus = '🤖 Transcribing your audio...';
    });

    try {
      final path = await _audioRecorder.stop();
      if (path == null) throw Exception('Recording failed');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final bytes = await XFile(path).readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/transcribe-audio'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'recording.webm',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _voiceIngredientsController.text = data['transcript'] ?? '';
          _voiceStatus = '✅ Detected: "${data['transcript']}"';
          _voiceResultVisible = true;
        });
      } else {
        setState(() => _voiceStatus = '❌ Transcription failed');
      }
    } catch (e) {
      setState(() => _voiceStatus = '❌ Error: $e');
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  // ===== IMAGE =====
  Future<void> _pickAndAnalyzeImage() async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
                title: Text('Take Photo', style: AppStyles.bodyLarge),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                title: Text('Choose Gallery', style: AppStyles.bodyLarge),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final List<XFile> files = [];
    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(source: source);
      if (photo != null) files.add(photo);
    } else {
      final picked = await picker.pickMultiImage();
      files.addAll(picked);
    }

    if (files.isEmpty) return;

    setState(() {
      _isAnalyzingImage = true;
      _imageStatus = '🤖 Analyzing ingredients...';
      _imageResultVisible = false;
      _imageIngredientsController.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final allIngredients = <String>{};

    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-image'));
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: file.name));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          final detected = data['ingredients'] as String? ?? '';
          detected.split(',').forEach((i) {
            if (i.trim().isNotEmpty) allIngredients.add(i.trim());
          });
        }
      }

      setState(() {
        _imageIngredientsController.text = allIngredients.join(', ');
        _imageStatus = '✅ Found ${allIngredients.length} ingredients!';
        _imageResultVisible = true;
      });
    } catch (e) {
      setState(() => _imageStatus = '❌ Image analysis failed');
    } finally {
      setState(() => _isAnalyzingImage = false);
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
                _buildHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 24),
                        _buildInputSection(),
                        if (_errorMessage.isNotEmpty) _buildErrorBanner(),
                        const SizedBox(height: 24),
                        if (_isLoading) _buildLoadingState(),
                        if (!_isLoading && _recommendations.isEmpty && _errorMessage.isEmpty) _buildEmptyState(),
                        if (!_isLoading && _recommendations.isNotEmpty) _buildResultsList(),
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

  Widget _buildHeroCard() {
    return NeoGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Recommendations', style: AppStyles.h2.copyWith(fontSize: 22)),
                const SizedBox(height: 8),
                Text(
                  'Enter your ingredients and let our AI suggest the perfect meal.',
                  style: AppStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orangeGlass,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 8),
          Text('Recommendation', style: AppStyles.h2),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.orangeGlass, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return NeoGlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _tabBtn('⌨️ Text', 0),
              const SizedBox(width: 8),
              _tabBtn('🎤 Voice', 1),
              const SizedBox(width: 8),
              _tabBtn('📸 Image', 2),
            ],
          ),
          const SizedBox(height: 20),
          if (_activeTab == 0) _buildTextTab(),
          if (_activeTab == 1) _buildVoiceTab(),
          if (_activeTab == 2) _buildImageTab(),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeTab = index;
          _errorMessage = '';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: AppStyles.caption.copyWith(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(_ingredientsController, 'e.g. chicken, garlic, onion...'),
        const SizedBox(height: 16),
        Text('Quick Add:', style: AppStyles.caption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '🍗 Chicken', '🧄 Garlic', '🧅 Onion', 
            '🍅 Tomato', '🥚 Egg', '🧀 Cheese'
          ].map((item) => GestureDetector(
            onTap: () {
              final ingredient = item.substring(2).trim();
              final current = _ingredientsController.text;
              _ingredientsController.text = current.isEmpty ? ingredient : '$current, $ingredient';
            },
            child: NeoGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: BorderRadius.circular(20),
              child: Text(item, style: AppStyles.caption.copyWith(color: AppColors.accent, fontSize: 11)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
        _buildActionBtn('Find Recipes', _getRecommendations),
      ],
    );
  }

  Widget _buildVoiceTab() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isTranscribing ? null : _toggleRecording,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: _isRecording ? const LinearGradient(colors: [Colors.redAccent, AppColors.accent]) : AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20)],
            ),
            child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(_voiceStatus.isEmpty ? 'Tap to speak ingredients' : _voiceStatus, 
            style: AppStyles.caption, textAlign: TextAlign.center),
        if (_voiceResultVisible) ...[
          const SizedBox(height: 16),
          _buildInputField(_voiceIngredientsController, 'Detected ingredients'),
          const SizedBox(height: 12),
          _buildActionBtn('Use Voice Result', () {
            _ingredientsController.text = _voiceIngredientsController.text;
            _getRecommendations();
          }),
        ],
      ],
    );
  }

  Widget _buildImageTab() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isAnalyzingImage ? null : _pickAndAnalyzeImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                Icon(_isAnalyzingImage ? Icons.hourglass_top_rounded : Icons.add_a_photo_rounded, color: AppColors.accent, size: 40),
                const SizedBox(height: 12),
                Text(_isAnalyzingImage ? 'Analyzing...' : 'Scan Ingredients', style: AppStyles.bodyMedium),
              ],
            ),
          ),
        ),
        if (_imageStatus.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_imageStatus, style: AppStyles.caption, textAlign: TextAlign.center),
        ),
        if (_imageResultVisible) ...[
          const SizedBox(height: 16),
          _buildInputField(_imageIngredientsController, 'Detected ingredients'),
          const SizedBox(height: 12),
          _buildActionBtn('Use Scanned Result', () {
            _ingredientsController.text = _imageIngredientsController.text;
            _getRecommendations();
          }),
        ],
      ],
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        style: AppStyles.bodyMedium.copyWith(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppStyles.caption,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: AppDecorations.primaryButton,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: AppStyles.buttonText),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(_errorMessage, style: AppStyles.caption.copyWith(color: Colors.redAccent))),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.orangeGlass, shape: BoxShape.circle),
            child: const Icon(Icons.kitchen_rounded, size: 64, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text('Your Kitchen is Waiting', style: AppStyles.h2),
          const SizedBox(height: 10),
          Text('Enter what you have and let ChefGPT handle the rest.', 
              style: AppStyles.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: NeoGlassContainer(
          height: 120,
          child: Center(child: CircularProgressIndicator(color: AppColors.accent.withOpacity(0.3))),
        ),
      )),
    );
  }

  Widget _buildResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recommendations', style: AppStyles.h2.copyWith(fontSize: 20)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text('${_recommendations.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) => _buildRecipeCard(_recommendations[i]),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(dynamic recipe) {
    final matchPct = recipe['match_pct'] ?? 0;
    final missing = recipe['missing_ingredients'] as List? ?? [];
    final imgUrl = recipe['image_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(recipe['recipe_id'].toString()) ?? 0;
        if (id > 0) Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)));
      },
      child: NeoGlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (imgUrl.isNotEmpty) ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.network(imgUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(recipe['recipe_name'] ?? 'Recipe', style: AppStyles.h2.copyWith(fontSize: 18))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: matchPct > 70 ? Colors.greenAccent.withOpacity(0.2) : AppColors.orangeGlass, borderRadius: BorderRadius.circular(12)),
                        child: Text('$matchPct% Match', style: AppStyles.caption.copyWith(color: matchPct > 70 ? Colors.greenAccent : AppColors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip(Icons.local_fire_department_rounded, '${recipe['calories'] ?? '---'} cal'),
                      const SizedBox(width: 12),
                      _infoChip(Icons.star_rounded, '${recipe['rating'] ?? '---'}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Missing: ${missing.isEmpty ? 'None!' : missing.join(', ')}', 
                      style: AppStyles.bodyMedium.copyWith(color: missing.isEmpty ? Colors.greenAccent : AppColors.textSecondary, fontSize: 13)),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: missing.map((ing) {
                        final key = '${recipe['recipe_id']}_$ing';
                        final sub = _substituteResults[key];
                        return ActionChip(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          side: const BorderSide(color: AppColors.glassBorder),
                          label: Text(sub ?? 'Swap $ing?', style: AppStyles.caption.copyWith(color: AppColors.accent, fontSize: 11)),
                          onPressed: () => _getSubstitute(ing, key),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: AppStyles.caption),
      ],
    );
  }
}