import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'space_fields.dart';

class SpaceFormScreen extends StatefulWidget {
  final int courtId;
  final int? spaceId;
  final Map<String, dynamic>? initial;

  const SpaceFormScreen({
    super.key,
    required this.courtId,
    this.spaceId,
    this.initial,
  });

  @override
  State<SpaceFormScreen> createState() => _SpaceFormScreenState();
}

class _SpaceFormScreenState extends State<SpaceFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _rate;
  late String _mode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: '${initial?['name'] ?? ''}');
    _description = TextEditingController(text: '${initial?['description'] ?? ''}');
    _capacity = TextEditingController(text: '${initial?['capacity'] ?? 1}');
    final rate = initial?['hourly_rate'];
    _rate = TextEditingController(text: rate == null || '$rate'.isEmpty ? '' : '$rate');
    final mode = '${initial?['booking_mode'] ?? 'exclusive'}';
    _mode = spaceBookingModes.contains(mode) ? mode : 'exclusive';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _capacity.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Map<String, dynamic> body;
    try {
      body = spaceWriteBody(
        courtId: widget.spaceId == null ? widget.courtId : null,
        name: _name.text,
        description: _description.text,
        capacityText: _capacity.text,
        hourlyRateText: _rate.text,
        bookingMode: _mode,
      );
    } on SpaceFieldError catch (error) {
      setState(() => _error = error.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.spaceId == null) {
        await Api().post('/sub-courts', data: body);
      } else {
        await Api().put('/sub-courts/${widget.spaceId}', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = Api.failureMessage(error, fallback: 'Could not save this space.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.spaceId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(editing ? 'Edit space' : 'Add space', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Court 1, Lane A, Pool'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Hourly rate', hintText: 'Leave blank to use the venue rate'),
          ),
          const SizedBox(height: 20),
          const Text('BOOKING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'exclusive', label: Text('Exclusive')),
              ButtonSegment(value: 'shared', label: Text('Shared')),
            ],
            selected: {_mode},
            onSelectionChanged: _saving ? null : (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == 'shared'
                ? 'Overlapping bookings are allowed until capacity is reached. Each booking uses one place.'
                : 'One confirmed booking at a time. Capacity is stored but not used for exclusive spaces.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Capacity'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : (editing ? 'Save space' : 'Add space')),
          ),
        ],
      ),
    );
  }
}
