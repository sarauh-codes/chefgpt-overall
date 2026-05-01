import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'recipe_detail_screen.dart';
import 'package:cross_file/cross_file.dart';
import 'chat_screen.dart';
import 'chat_fab.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  final ImagePicker _picker = ImagePicker();

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
  bool _isDetecting = false;
  List<XFile> _selectedImages =[];
  List<String> _detectedIngredients = [];

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
        _errorMessage =
            'Cannot connect to server. Check your connection.\nDebug: $e';
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

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path: 'recording.webm',
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
      _voiceStatus = '🤖 Whisper is transcribing your audio...';
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
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _voiceIngredientsController.text = data['transcript'] ?? '';
          _voiceStatus =
              '✅ Heard: "${data['transcript']}" — edit if needed, then tap Get Recipes!';
          _voiceResultVisible = true;
        });
      } else {
        setState(() => _voiceStatus =
            '❌ Error: ${data['error'] ?? 'Transcription failed'}');
      }
    } catch (e) {
      setState(() => _voiceStatus = '❌ Error: $e');
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  void _getRecommendationsFromVoice() {
    final value = _voiceIngredientsController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorMessage = '⚠️ No ingredients detected yet. Please record first!';
      });
      return;
    }
    _ingredientsController.text = value;
    _getRecommendations();
  }

  // ===== IMAGE =====
  Future<void> _pickAndAnalyzeImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF6B35)),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF6B35)),
              title: const Text('Choose From Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

  if (source == null) return; // ← user cancel

  final picker = ImagePicker();

  // ← Camera = single image, Gallery = multi image
  List<XFile> files = [];
  if (source == ImageSource.camera) {
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (photo != null) {
    setState(() => _selectedImages.add(photo));
    files = _selectedImages;  // guna semua gambar dalam list
}
  } else {
    final picked = await picker.pickMultiImage();
    setState(() => _selectedImages.addAll(picked));
    files = _selectedImages;
  }

  if (files.isEmpty) return;
    setState(() {
      _isAnalyzingImage = true;
      _imageStatus = '🤖 BLIP is analyzing ${files.length} image(s)...';
      _imageResultVisible = false;
      _imageIngredientsController.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final allIngredients = <String>{};

    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/analyze-image'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name,
        ));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          // Priority: ingredients_list (array), fallback: ingredients (string)
          if (data['ingredients_list'] != null && data['ingredients_list'] is List) {
            for (var item in data['ingredients_list']) {
              final trimmed = item.toString().trim();
              if (trimmed.isNotEmpty) allIngredients.add(trimmed);
            }
          } else {
            final detected = data['ingredients'] as String? ?? '';
            detected.split(',').forEach((i) {
              final trimmed = i.trim();
              if (trimmed.isNotEmpty) allIngredients.add(trimmed);
            });
        } else {
          setState(() =>
              _imageStatus = '❌ Error: ${data['error'] ?? 'Analysis failed'}');
          return;
        }
      }

      final finalIngredients = allIngredients.join(', ');
      setState(() {
        _imageIngredientsController.text = finalIngredients;
        _detectedIngredients = allIngredients.toList(); 
        _imageStatus =
            '✅ Detected ${allIngredients.length} ingredient(s) — edit if needed, then tap Get Recipes!';
        _imageResultVisible = true;
      });
    } catch (e) {
      setState(() => _imageStatus = '❌ Error: $e');
    } finally {
      setState(() => _isAnalyzingImage = false);
    }
  }

  void _getRecommendationsFromImage() {
    final value = _imageIngredientsController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorMessage =
            '⚠️ No ingredients detected yet. Please upload an image first!';
      });
      return;
    }
    _ingredientsController.text = value;
    _getRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:const ChatFab(),
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
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    _buildInputCard(),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildErrorBanner(),
                    ],
                    const SizedBox(height: 24),
                    if (_isLoading) _buildLoadingState(),
                    if (!_isLoading &&
                        _recommendations.isEmpty &&
                        _errorMessage.isEmpty)
                      _buildEmptyState(),
                    if (!_isLoading && _recommendations.isNotEmpty)
                      _buildResultsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 8,
        right: 20,
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
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              '🔍 Get Recommendations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Recipe Suggestions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter ingredients you have and let AI find the perfect recipes for you.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
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
          // Tab buttons
          Row(
            children: [
              _buildTabBtn('⌨️ Type', 0),
              const SizedBox(width: 8),
              _buildTabBtn('🎤 Voice', 1),
              const SizedBox(width: 8),
              _buildTabBtn('📸 Image', 2),
            ],
          ),
          const SizedBox(height: 20),

          // Tab content
          if (_activeTab == 0) _buildTextTab(),
          if (_activeTab == 1) _buildVoiceTab(),
          if (_activeTab == 2) _buildImageTab(),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _activeTab = index;
        _errorMessage = '';
        _recommendations = [];
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFF7931E)])
              : null,
          color: isActive ? null : const Color(0xFFFFF3EE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : const Color(0xFFFF6B35).withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFFFF6B35),
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🧄 Your Ingredients',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Separate multiple ingredients with commas',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 14),
        Focus(
          child: Builder(builder: (ctx) {
            final focused = Focus.of(ctx).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: focused
                    ? const Color(0xFFFF6B35).withOpacity(0.04)
                    : const Color(0xFFFFFAF7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? const Color(0xFFFF6B35).withOpacity(0.6)
                      : const Color(0xFFFFE0D0),
                  width: focused ? 1.5 : 1,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.1),
                          blurRadius: 16,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _ingredientsController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'e.g. chicken, garlic, onion, tomato...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Padding(
                    padding:
                        const EdgeInsets.only(left: 14, right: 10, top: 14),
                    child: Icon(Icons.kitchen_rounded,
                        color: Colors.grey[400], size: 20),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '🍗 Chicken',
            '🧄 Garlic',
            '🧅 Onion',
            '🍅 Tomato',
            '🥚 Egg',
            '🧀 Cheese'
          ]
              .map((item) => GestureDetector(
                    onTap: () {
                      final current = _ingredientsController.text;
                      final ingredient = item.substring(2).trim();
                      _ingredientsController.text = current.isEmpty
                          ? ingredient
                          : '$current, $ingredient';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.2)),
                      ),
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.w500)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        _buildGetRecipesButton(onTap: _isLoading ? null : _getRecommendations),
      ],
    );
  }

  Widget _buildVoiceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the mic, say your ingredients, then tap stop 🎙️',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 16),

        // Mic button
        Center(
          child: GestureDetector(
            onTap: _isTranscribing ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [const Color(0xFFFF3B30), const Color(0xFFFF6B35)]
                      : [const Color(0xFFFF6B35), const Color(0xFFF7931E)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFFFF6B35))
                        .withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                _isRecording
                    ? Icons.stop_rounded
                    : _isTranscribing
                        ? Icons.hourglass_top_rounded
                        : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status text
        if (_voiceStatus.isNotEmpty)
          Center(
            child: Text(
              _voiceStatus,
              style: TextStyle(
                fontSize: 12,
                color: _voiceStatus.startsWith('❌')
                    ? const Color(0xFFF87171)
                    : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Result input + button
        if (_voiceResultVisible) ...[
          const SizedBox(height: 16),
          _buildDetectedIngredientsField(
            controller: _voiceIngredientsController,
            hint: 'Detected ingredients will appear here...',
          ),
          const SizedBox(height: 12),
          _buildGetRecipesButton(
              onTap: _isLoading ? null : _getRecommendationsFromVoice),
        ],
      ],
    );
  }

  Widget _buildImageTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload photos of your ingredients and let AI detect them 📸',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 16),

        // Upload button
        GestureDetector(
          onTap: _isAnalyzingImage ? null : _pickAndAnalyzeImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isAnalyzingImage
                      ? Icons.hourglass_top_rounded
                      : Icons.add_photo_alternate_rounded,
                  color: const Color(0xFFFF6B35),
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  _isAnalyzingImage
                      ? 'Analyzing...'
                      : '📂 Tap to upload image(s)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status text
        if (_imageStatus.isNotEmpty)
          Text(
            _imageStatus,
            style: TextStyle(
              fontSize: 12,
              color: _imageStatus.startsWith('❌')
                  ? const Color(0xFFF87171)
                  : Colors.grey[600],
              height: 1.5,
            ),
          ),

        // Result input + button
        if (_imageResultVisible) ...[
          const SizedBox(height: 16),
           if (_detectedIngredients.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _detectedIngredients.map((ing) {
                return Chip(
                  label: Text(ing),
                  backgroundColor: const Color(0xFFFFF3EE),
                  side: const BorderSide(color: Color(0xFFFF6B35)),
                  labelStyle: const TextStyle(color: Color(0xFFFF6B35)),
                  deleteIcon: const Icon(Icons.close, size: 18, color: Color(0xFFFF6B35)),
                  onDeleted: () {
                    setState(() {
                      _detectedIngredients.remove(ing);
                      _imageIngredientsController.text = _detectedIngredients.join(', ');
                    });
                  },
                );
              }).toList(),
            ),
          if (_detectedIngredients.isNotEmpty) const SizedBox(height: 12),
          _buildDetectedIngredientsField(
            controller: _imageIngredientsController,
            hint: 'Detected ingredients will appear here...',
          ),
          const SizedBox(height: 12),
          _buildGetRecipesButton(
              onTap: _isLoading ? null : _getRecommendationsFromImage),
        ],
      ],
    );
  }

  Widget _buildDetectedIngredientsField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE0D0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 2,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        ),
      ),
    );
  }

  Widget _buildGetRecipesButton({VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Get Recommendations',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5050).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5050).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFF87171), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage,
                style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 13,
                    fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(height: 18, width: 200),
              const SizedBox(height: 10),
              _shimmerBox(height: 13, width: double.infinity),
              const SizedBox(height: 6),
              _shimmerBox(height: 13, width: 260),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox({required double height, required double width}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0D0).withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 48, color: Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter your ingredients above',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI will suggest the best recipes based on what you have in your kitchen.',
            style:
                TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '✨ Recommendations',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_recommendations.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _buildRecipeCard(_recommendations[i]),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(dynamic recipe) {
    final matchPct = recipe['match_pct'] ?? 0;
    final matchedCount = recipe['matched_count'] ?? 0;
    final totalIngredients = recipe['total_ingredients'] ?? 0;
    final missingIngredients = recipe['missing_ingredients'] as List? ?? [];

    Color matchColor;
    if (matchPct >= 70) {
      matchColor = const Color(0xFF00B894);
    } else if (matchPct >= 40) {
      matchColor = const Color(0xFFFDCB6E);
    } else {
      matchColor = const Color(0xFFFF6B6B);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 18),
        ],
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: matchColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.restaurant_rounded,
                          color: Color(0xFFFF6B35), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe['recipe_name'] ?? 'Recipe',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: matchColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$matchPct%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (recipe['cuisine'] != null)
                      _infoTag('🍽️ ${recipe['cuisine']}'),
                    if (recipe['calories'] != null)
                      _infoTag('🔥 ${recipe['calories']} cal'),
                    if (recipe['rating'] != null)
                      _infoTag('⭐ ${recipe['rating']}/5'),
                    if (recipe['difficulty'] != null)
                      _infoTag('⚡ ${recipe['difficulty']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You have $matchedCount of $totalIngredients ingredients',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (matchPct / 100).toDouble().clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEDF2F7),
                    valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                  ),
                ),
                const SizedBox(height: 10),
                if (missingIngredients.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🛒 ', style: TextStyle(fontSize: 13)),
                            Text(
                              'Still need:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...missingIngredients.map<Widget>((m) {
                          final ingredient = m.toString();
                          final recipeId =
                              recipe['recipe_id']?.toString() ?? 'x';
                          final key = '${recipeId}_$ingredient';
                          final isLoading = _substituteLoading[key] == true;
                          final subResult = _substituteResults[key];
                          final isShowing = subResult != null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFFF6B35)
                                                .withOpacity(0.25)),
                                      ),
                                      child: Text(
                                        ingredient,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: isLoading
                                          ? null
                                          : () =>
                                              _getSubstitute(ingredient, key),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isShowing
                                              ? const Color(0xFFFF6B35)
                                                  .withOpacity(0.15)
                                              : const Color(0xFFFFF3EE),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFFFF6B35)
                                                  .withOpacity(0.4)),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 10,
                                                width: 10,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: Color(0xFFFF6B35),
                                                ),
                                              )
                                            : Text(
                                                isShowing ? 'hide' : 'swap?',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFFF6B35),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isShowing) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Row(
                                      children: [
                                        const Text('→ ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFFF6B35))),
                                        Expanded(
                                          child: Text(
                                            subResult!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF92400E),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC6F6D5)),
                    ),
                    child: const Row(
                      children: [
                        Text('✅ ', style: TextStyle(fontSize: 13)),
                        Text(
                          'You have all ingredients!',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF276749),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (recipe['ingredients'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF7),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                        left: BorderSide(color: Color(0xFFFF6B35), width: 3),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                            height: 1.6),
                        children: [
                          const TextSpan(
                            text: 'Ingredients: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333)),
                          ),
                          TextSpan(text: recipe['ingredients'].toString()),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    final rawId = recipe['recipe_id'] ?? recipe['id'];
                    if (rawId == null) return;
                    final id = rawId is int
                        ? rawId
                        : int.tryParse(rawId.toString()) ?? 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipeId: id),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text('View Full Recipe',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTag(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFF6B35).withOpacity(0.12)
            : const Color(0xFFFFF3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(highlight ? 0.4 : 0.15)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFFFF6B35))),
    );
  }
}
