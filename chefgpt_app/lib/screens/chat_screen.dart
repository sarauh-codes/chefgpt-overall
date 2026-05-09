import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_glass_container.dart';
import '../constants.dart';

class ChatScreen extends StatefulWidget {
  final bool isEmbedded;
  const ChatScreen({super.key, this.isEmbedded = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'role': 'bot', 'text': data['reply'] ?? '...'});
        });
      } else {
        setState(() {
          _messages.add({'role': 'bot', 'text': 'Something went wrong. Try again!'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'bot', 'text': 'Cannot connect to server.'});
      });
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.transparent : AppColors.background,
      appBar: widget.isEmbedded 
        ? null 
        : AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text('ChefGPT Assistant', style: AppStyles.h2.copyWith(fontSize: 18)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedLogo(),
          const SizedBox(height: 24),
          Text('How can I help you?', style: AppStyles.h1.copyWith(fontSize: 24)),
          const SizedBox(height: 8),
          Text('Ask me anything about cooking!', style: AppStyles.bodyMedium),
          const SizedBox(height: 32),
          _buildSuggestions(),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withOpacity(0.1),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.accent),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = ['🍝 Quick Pasta', '🥗 Healthy Salad', '🥩 Steak Tips'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: suggestions.map((s) => GestureDetector(
        onTap: () {
          _inputController.text = s;
          _sendMessage();
        },
        child: NeoGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: BorderRadius.circular(20),
          child: Text(s, style: AppStyles.caption.copyWith(color: Colors.white)),
        ),
      )).toList(),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isTyping && i == _messages.length) return _buildTypingIndicator();
        final msg = _messages[i];
        return _buildChatBubble(msg['text']!, msg['role'] == 'user');
      },
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _avatar(),
          const SizedBox(width: 12),
          Flexible(
            child: NeoGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              borderColor: isUser ? AppColors.accent.withOpacity(0.3) : AppColors.glassBorder,
              child: Text(text, style: AppStyles.bodyMedium.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          if (isUser) _avatar(isUser: true),
        ],
      ),
    );
  }

  Widget _avatar({bool isUser = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser ? AppColors.primaryGradient : null,
        color: isUser ? null : AppColors.surface,
        border: Border.all(color: Colors.white10),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          const NeoGlassContainer(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _sendMessage(),
                style: AppStyles.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}