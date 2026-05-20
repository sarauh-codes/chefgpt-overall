import 'package:flutter/material.dart';

class FeedbackSheet extends StatefulWidget {
  final int recipeId;
  final List feedbacks;
  final Future<void> Function(int rating, String comment) onSubmit;
  final Future<List> Function() onFetch;

FeedbackSheet({
    super.key,
    required this.recipeId,
    required this.feedbacks,
    required this.onSubmit,
    required this.onFetch,
  });

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String _message = '';
  late List _localFeedbacks;

  @override
    void initState() {
        super.initState();
        _localFeedbacks = widget.feedbacks;
    }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFAF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Title
            const Text('Rate This Recipe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Stars
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      star <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: star <= _selectedRating
                          ? const Color(0xFFFFB800)
                          : Colors.grey[300],
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Comment
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0D0)),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts... (optional)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_message.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ade80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4ade80).withOpacity(0.3)),
                ),
                child: Text(_message,
                    style: const TextStyle(color: Color(0xFF276749), fontSize: 13)),
              ),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Feedback',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
              ),
            ),

            const Divider(height: 32),

            // Reviews list
            const Text('User Reviews',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            widget.feedbacks.isEmpty
                ? Center(
                    child: Text('No reviews yet. Be the first!',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13)))
                : Column(
                    children: widget.feedbacks
                        .map((fb) => _buildFeedbackCard(fb))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      setState(() => _message = 'Please select a rating first!');
      return;
    }
    setState(() { _isSubmitting = true; _message = ''; });
    await widget.onSubmit(_selectedRating, _commentController.text.trim());
    setState(() {
      _message = 'Feedback submitted!';
      _selectedRating = 0;
      _commentController.clear();
      _isSubmitting = false;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  Widget _buildFeedbackCard(dynamic fb) {
    final rating = fb['rating'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
                child: Text(
                  (fb['username'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fb['username'] ?? 'User',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1A1A1A))),
                    Text(fb['created_at'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: i < rating ? const Color(0xFFFFB800) : Colors.grey[300],
                          size: 16,
                        )),
              ),
            ],
          ),
          if (fb['comment'] != null && fb['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(fb['comment'],
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF555555), height: 1.5)),
          ],
        ],
      ),
    );
  }
}