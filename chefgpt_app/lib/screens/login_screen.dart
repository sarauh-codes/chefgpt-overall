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
import '../widgets/neo_glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
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
      duration: const Duration(seconds: 20),
    )..repeat();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutExpo,
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
      setState(() {
        _errorMessage = "Connection error. Please try again.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Animated Orbs Background ──
          _buildAnimatedOrbs(),

          // ── Login Content ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _cardAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_cardAnimation),
                  child: NeoGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Section
                        _buildLogo(),
                        const SizedBox(height: 24),

                        // Title Section
                        Text('Welcome Back', style: AppStyles.h1),
                        const SizedBox(height: 8),
                        Text('Login to your ChefGPT account', style: AppStyles.bodyMedium),
                        
                        const SizedBox(height: 40),

                        // Input Fields
                        _buildTextField(
                          controller: _emailController,
                          label: 'Username',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          isPassword: true,
                          togglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),

                        if (_errorMessage.isNotEmpty) _buildErrorLabel(),

                        const SizedBox(height: 32),

                        // Login Button
                        _buildLoginButton(),

                        const SizedBox(height: 24),

                        // Footer
                        _buildFooter(),
                      ],
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

  Widget _buildAnimatedOrbs() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (_, __) {
        return Stack(
          children: [
            // Top Right Orb
            Positioned(
              top: -100 + sin(_orbController.value * 2 * pi) * 40,
              right: -100 + cos(_orbController.value * 2 * pi) * 20,
              child: _orb(400, AppColors.accent.withOpacity(0.15)),
            ),
            // Bottom Left Orb
            Positioned(
              bottom: -150 + cos(_orbController.value * 2 * pi) * 30,
              left: -150 + sin(_orbController.value * 2 * pi) * 40,
              child: _orb(450, AppColors.secondary.withOpacity(0.1)),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.restaurant_rounded, size: 40, color: Colors.white),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? togglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: AppStyles.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                      onPressed: togglePassword,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorLabel() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        _errorMessage,
        style: AppStyles.caption.copyWith(color: Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _login,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: AppDecorations.primaryButton,
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Text('LOGIN', style: AppStyles.buttonText),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: AppStyles.bodyMedium),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: Text(
            'Sign Up',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}