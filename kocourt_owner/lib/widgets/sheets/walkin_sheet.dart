import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../screens/owner/walk_in_fields.dart';

class WalkInSheet extends StatefulWidget {
  final int courtId;
  final String date;
  final String? startTime;
  final int? spaceId;
  final List<Map<String, dynamic>> spaces;

  const WalkInSheet({
    super.key,
    required this.courtId,
    required this.date,
    this.startTime,
    this.spaceId,
    this.spaces = const [],
  });

  static Future<bool?> show(
    BuildContext context, {
    required int courtId,
    required String date,
    String? startTime,
    int? spaceId,
    List<Map<String, dynamic>> spaces = const [],
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalkInSheet(
        courtId: courtId,
        date: date,
        startTime: startTime,
        spaceId: spaceId,
        spaces: spaces,
      ),
    );
  }

  @override
  State<WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<WalkInSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late int _hour;
  int? _spaceId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final parsed = widget.startTime != null ? int.tryParse(widget.startTime!.split(':').first) : null;
    final hour = parsed ?? DateTime.now().hour;
    _hour = hour < 0 || hour > 23 ? 0 : hour;
    _spaceId = widget.spaceId;
    if ((_spaceId == null || _spaceId! <= 0) && widget.spaces.isNotEmpty) {
      _spaceId = int.tryParse('${widget.spaces.first['id']}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = walkInBody(
        courtId: widget.courtId,
        date: widget.date,
        startHour: _hour,
        guestName: _nameController.text,
        guestPhone: _phoneController.text,
        spaceId: _spaceId,
        spaceRequired: widget.spaces.isNotEmpty,
      );
      await Api().post('/bookings', data: body);
      if (mounted) Navigator.pop(context, true);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = caught is WalkInFieldError
            ? caught.message
            : Api.failureMessage(caught, fallback: 'Could not save this walk-in.');
      });
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
      child: SingleChildScrollView(
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
          Text('${widget.date} · $_hour:00', style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          const Text(
            'This confirms the hour for the guest. The price is calculated on the server.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (widget.spaces.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _spaceId,
              decoration: const InputDecoration(labelText: 'Space'),
              items: [
                for (final space in widget.spaces)
                  if (int.tryParse('${space['id']}') != null)
                    DropdownMenuItem(value: int.parse('${space['id']}'), child: Text('${space['name'] ?? 'Space'}')),
              ],
              onChanged: (value) => setState(() => _spaceId = value),
            ),
          DropdownButtonFormField<int>(
            initialValue: _hour,
            decoration: const InputDecoration(labelText: 'Hour'),
            items: [for (var hour = 0; hour <= 23; hour++) DropdownMenuItem(value: hour, child: Text('${hour.toString().padLeft(2, '0')}:00'))],
            onChanged: (value) {
              if (value != null) setState(() => _hour = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Guest name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Guest phone'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
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
      ),
    );
  }
}
