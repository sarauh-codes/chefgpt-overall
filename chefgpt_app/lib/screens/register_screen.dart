import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'login_screen.dart';
import '../widgets/dashboard/aurora_painter.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! Please login.'),
              backgroundColor: const Color(0xFF2CB67D).withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Registration failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Cannot connect to server. Check your connection.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBuilder(
        animation: _auroraController,
        builder: (context, child) {
          return Stack(
            children: [
              // ── Aurora Background ──
              Positioned.fill(
                child: CustomPaint(
                  painter: AuroraPainter(_auroraController.value),
                ),
              ),

              // ── Main Content ──
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildGlassCard(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassCard() {
    return Container(
      width: 400,
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF140A00).withOpacity(0.55),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFFF9650).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 80,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.08),
            blurRadius: 120,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ColorFilter.mode(
            Colors.transparent,
            BlendMode.multiply,
          ),
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Icon ──
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35).withOpacity(0.2),
                const Color(0xFFF7931E).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFF9650).withOpacity(0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                blurRadius: 32,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // ── Title ──
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5E6),
              Color(0xFFFFD27F),
              Color(0xFFFF6B35),
            ],
            stops: [0.0, 0.4, 1.0],
          ).createShader(bounds),
          child: const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ),

        // ── Underline accent ──
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.6),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Username Field ──
        _buildInputField(
          controller: _usernameController,
          hint: 'Username',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),

        // ── Email Field ──
        _buildInputField(
          controller: _emailController,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // ── Password Field ──
        _buildInputField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: true,
        ),

        // ── Error Message ──
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5050).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF5050).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF87171), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // ── Register Button ──
        _buildRegisterButton(),
        const SizedBox(height: 24),

        // ── Login Link ──
        Text.rich(
          TextSpan(
            text: 'Already have an account?  ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
            children: [
              WidgetSpan(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    'Login here',
                    style: TextStyle(
                      color: Color(0xFFFFB464),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isFocused
                  ? const Color(0xFFFF6B35).withOpacity(0.08)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused
                    ? const Color(0xFFFF6B35).withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontWeight: FontWeight.w300,
                ),
                prefixIcon: Icon(icon,
                    color: Colors.white.withOpacity(0.4), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 15),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.45),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'REGISTER',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
        ),
      ),
    );
  }
}

