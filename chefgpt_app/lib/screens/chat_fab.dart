import 'package:flutter/material.dart';
import 'chat_screen.dart';

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
    return FloatingActionButton(
      backgroundColor: const Color(0xFFFF6B35),
      onPressed: () {
        if (_isOpen) {
          hide();
        } else {
          show(context);
        }
      },
      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
    );
  }
}

class _ChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _ChatPanel({required this.onClose});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    final panelWidth = screenSize.width * 0.85 > 380 ? 380.0 : screenSize.width * 0.85;

    return Stack(
      children: [
        // Dim background
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              width: screenSize.width,
              height: screenSize.height,
              color: Colors.black,
            ),
          ),
        ),
        // Slide-in panel from right
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 48, 8, 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF9A5C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.restaurant_menu,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask ChefGPT',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text('AI Cooking Assistant',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _close,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Chat content
                  const Expanded(child: ChatScreen(isEmbedded: true)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}