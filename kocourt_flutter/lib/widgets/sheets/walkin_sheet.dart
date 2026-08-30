import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/theme.dart';

class WalkInSheet extends StatefulWidget {
  final int courtId;
  final int ownerId;
  final String date;
  final String? startTime;
  final int? spaceId;

  const WalkInSheet({
    super.key,
    required this.courtId,
    required this.ownerId,
    required this.date,
    this.startTime,
    this.spaceId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int courtId,
    required int ownerId,
    required String date,
    String? startTime,
    int? spaceId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalkInSheet(
        courtId: courtId,
        ownerId: ownerId,
        date: date,
        startTime: startTime,
        spaceId: spaceId,
      ),
    );
  }

  @override
  State<WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<WalkInSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _startTime;
  late String _endTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final hour = widget.startTime != null
        ? int.tryParse(widget.startTime!.split(':').first) ?? DateTime.now().hour
        : DateTime.now().hour;
    _startTime = '${hour.toString().padLeft(2, '0')}:00';
    _endTime = '${(hour + 1).toString().padLeft(2, '0')}:00';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await Api().post('/bookings', data: {
        'court_id': widget.courtId,
        'user_id': widget.ownerId,
        'date': widget.date,
        'start_time': _startTime,
        'end_time': _endTime,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        if (widget.spaceId != null) 'sub_court_id': widget.spaceId,
        'walk_in': true,
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
          const Text('Walk-in Booking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${widget.date} \u00B7 $_startTime - $_endTime', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Guest Name (optional)'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Guest Phone (optional)'),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Add Walk-in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
