import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api.dart';
import '../../core/theme.dart';

class ReviewSheet extends StatefulWidget {
  final int courtId;
  final int userId;
  final String? courtName;
  final int? bookingId;

  const ReviewSheet({super.key, required this.courtId, required this.userId, this.courtName, this.bookingId});

  static Future<bool?> show(BuildContext context, {required int courtId, required int userId, String? courtName, int? bookingId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSheet(courtId: courtId, userId: userId, courtName: courtName, bookingId: bookingId),
    );
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;

    setState(() => _submitting = true);
    try {
      await Api().post('/reviews', data: {
        'court_id': widget.courtId,
        'user_id': widget.userId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        if (widget.bookingId != null) 'booking_id': widget.bookingId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rate ${widget.courtName ?? 'this venue'}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = i + 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: filled ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: filled ? AppColors.accent : AppColors.textDisabled,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _rating == 0
                  ? 'Tap to rate'
                  : ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'][_rating],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _rating == 0 ? AppColors.textMuted : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Share your experience (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _rating == 0 || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
