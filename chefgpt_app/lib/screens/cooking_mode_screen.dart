import '../constants.dart';
import '../utils/recipe_format.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard/aurora_painter.dart';
import 'chat_screen.dart';
import 'chat_fab.dart';

class CookingModeScreen extends StatefulWidget {
  final int recipeId;
  final Map<String, dynamic> recipe;
  const CookingModeScreen({
    super.key,
    required this.recipeId,
    required this.recipe,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  late List<String> _steps;
  late List<bool> _checked;
  bool _isMarkingCooked = false;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _steps = splitRecipeInstructions(widget.recipe['instructions']);
    _checked = List.filled(_steps.length, false);
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  Future<void> _markAsCooked() async {
    setState(() => _isMarkingCooked = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.post(
        Uri.parse('$baseUrl/api/mark-cooked/${widget.recipeId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        setState(() => _isDone = true);
        // Show success overlay for 1.5s, then show what's next modal
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) _showWhatsNextModal();
      } else {
        _showSnack('Failed to mark as cooked. Try again.');
      }
    } catch (_) {
      _showSnack('Cannot connect to server.');
    } finally {
      if (mounted) setState(() => _isMarkingCooked = false);
    }
  }

  void _showWhatsNextModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Great job! 🎉',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 6),
            Text(
              'You\'ve cooked ${widget.recipe['recipe_name'] ?? 'this recipe'}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 8),
            const Text(
              'What would you like to do next?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF999999),
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 28),
            // Buttons row
            Row(
              children: [
                // Rate Recipe
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // close modal
                      Navigator.pop(context, 'rate'); // back to recipe detail with signal
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Column(
                        children: [
                          Text('⭐', style: TextStyle(fontSize: 22)),
                          SizedBox(height: 4),
                          Text('Rate Recipe',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Go Home
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // close modal
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.grey.shade200, width: 1.5),
                      ),
                      child: const Column(
                        children: [
                          Text('🏠', style: TextStyle(fontSize: 22)),
                          SizedBox(height: 4),
                          Text('Go Home',
                              style: TextStyle(
                                  color: Color(0xFF555555),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  int get _completedSteps => _checked.where((c) => c).length;
  double get _progress => _steps.isEmpty ? 0 : _completedSteps / _steps.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const ChatFab(),
      backgroundColor: const Color(0xFFFFFAF7),
      body: AnimatedBuilder(
        animation: _auroraController,
        builder: (_, child) => Stack(children: [
          Positioned.fill(
              child: CustomPaint(
                  painter: AuroraPainter(_auroraController.value))),
          child!,
          // Success overlay
          if (_isDone)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Color(0xFF22c55e),
                              Color(0xFF16a34a)
                            ]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text('Great job! 🎉',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A))),
                        const SizedBox(height: 8),
                        const Text('Recipe marked as cooked!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: Color(0xFF666666))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
        child: Column(children: [
          _buildAppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Text('👨‍🍳 ', style: TextStyle(fontSize: 18)),
                          Text('COOKING MODE',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5)),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          widget.recipe['recipe_name'] ?? 'Recipe',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildProgress(),
                  const SizedBox(height: 20),
                  _buildStepsCard(),
                  const SizedBox(height: 24),
                  _buildFinishButton(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 8,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
        boxShadow: [
          BoxShadow(
              color: Color(0x4DFF6B35),
              blurRadius: 24,
              offset: Offset(0, 4))
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
            child: Text('Cooking Mode',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          Text('$_completedSteps/${_steps.length}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A))),
              Text('${(_progress * 100).round()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFFFF6B35))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFFFE0D0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
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
          Row(children: [
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
            const Text('📝 Step-by-Step Instructions',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
          ]),
          const SizedBox(height: 6),
          Text('Tap each step when done',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ...List.generate(_steps.length, (i) => _buildStep(i)),
        ],
      ),
    );
  }

  Widget _buildStep(int i) {
    final done = _checked[i];
    return GestureDetector(
      onTap: () => setState(() => _checked[i] = !_checked[i]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFFFF6B35).withOpacity(0.06)
              : const Color(0xFFFFFAF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done
                ? const Color(0xFFFF6B35).withOpacity(0.3)
                : const Color(0xFFFFE0D0),
            width: done ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 12, top: 1),
              decoration: BoxDecoration(
                gradient: done
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFF7931E)])
                    : null,
                color: done ? null : Colors.white,
                shape: BoxShape.circle,
                border: done
                    ? null
                    : Border.all(
                        color: const Color(0xFFFFE0D0), width: 1.5),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF6B35))),
              ),
            ),
            Expanded(
              child: Text(
                _steps[i],
                style: TextStyle(
                    fontSize: 14,
                    color: done
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF333333),
                    height: 1.6,
                    decoration: done ? TextDecoration.lineThrough : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    final allDone = _completedSteps == _steps.length && _steps.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: (_isMarkingCooked || _isDone) ? null : _markAsCooked,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: allDone
                  ? [const Color(0xFF22c55e), const Color(0xFF16a34a)]
                  : [const Color(0xFFFF6B35), const Color(0xFFF7931E)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: (allDone ? Colors.green : const Color(0xFFFF6B35))
                    .withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: _isMarkingCooked
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    allDone
                        ? '✅ I\'ve Finished Cooking!'
                        : '✅ Mark as Cooked',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}