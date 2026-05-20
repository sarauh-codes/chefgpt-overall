import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';

class ChatFab extends StatelessWidget {
  const ChatFab({super.key});

  static OverlayEntry? _overlayEntry;
  static bool _isOpen = false;

  static void show(BuildContext context) {
    if (_isOpen) return;
    _overlayEntry = OverlayEntry(
      builder: (_) => _ChatPanel(onClose: hide),
    );
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _isOpen ? hide() : show(context),
      child: Container(
        width: 60,
        height: 60,
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
        child: const Icon(Icons.forum_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _ChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _ChatPanel({required this.onClose});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = screenSize.width * 0.85 > 400 ? 400.0 : screenSize.width * 0.85;

    return Stack(
      children: [
        // Backdrop
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        ),
        // Side Panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), bottomLeft: Radius.circular(32)),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _buildHeader(),
                  const Expanded(child: ChatScreen(isEmbedded: true)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.1),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ChefGPT AI', style: AppStyles.h2.copyWith(fontSize: 18)),
                Text('Online Assistant', style: AppStyles.caption.copyWith(color: Colors.greenAccent)),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}