import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  late AnimationController _orbController;
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    _cardController.forward();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _cardController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('username', data['username']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Login failed';
        });
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          // ── Orb 1 top-left ──
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              return Positioned(
                top: -180 + sin(_orbController.value * 2 * pi) * 30,
                left: -180 + cos(_orbController.value * 2 * pi) * 20,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orangePrimary.withOpacity(0.22),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Orb 2 bottom-right ──
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              return Positioned(
                bottom: -160 + cos(_orbController.value * 2 * pi) * 25,
                right: -160 + sin(_orbController.value * 2 * pi) * 20,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFC0392B), Color(0xFFE74C3C)],
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC0392B).withOpacity(0.18),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Main Card ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: FadeTransition(
                opacity: _cardAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_cardAnimation),
                  child: Container(
                    decoration: AppDecorations.glassCard,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 44),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // ── Logo ──
                              Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.orangePrimary.withOpacity(0.2),
                                      AppColors.orangeSecondary.withOpacity(0.1),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.orangePrimary.withOpacity(0.25),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.orangePrimary.withOpacity(0.3),
                                      blurRadius: 32,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.smart_toy_rounded,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // ── Title ──
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF5E6),
                                    Color(0xFFFFD27F),
                                    Color(0xFFFF6B35),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text('ChefGPT', style: AppStyles.titleStyle),
                              ),
                              const SizedBox(height: 6),
                              Text('Your AI Recipe Assistant',
                                  style: AppStyles.subtitleStyle),

                              // ── Divider ──
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 20),
                                width: 48,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.orangePrimary,
                                      AppColors.orangeSecondary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.orangePrimary.withOpacity(0.6),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),

                              // ── Username Field ──
                              TextField(
                                controller: _emailController,
                                style: AppStyles.inputTextStyle,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontWeight: FontWeight.w300,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(Icons.person_outline_rounded,
                                      color: Colors.white.withOpacity(0.4), size: 20),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppColors.orangePrimary, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // ── Password Field ──
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: AppStyles.inputTextStyle,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontWeight: FontWeight.w300,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      color: Colors.white.withOpacity(0.4), size: 20),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white.withOpacity(0.4),
                                      size: 20,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppColors.orangePrimary, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                ),
                              ),

                              // ── Error Message ──
                              if (_errorMessage.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5050).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFF5050).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Color(0xFFF87171),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── Login Button ──
                              Container(
                                width: double.infinity,
                                height: 52,
                                decoration: AppDecorations.gradientButton,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text('LOGIN', style: AppStyles.buttonTextStyle),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Register Link ──
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    text: "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'Register',
                                        style: TextStyle(
                                          color: AppColors.goldText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}