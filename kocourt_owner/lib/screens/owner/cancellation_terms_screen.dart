import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class CancellationTermsScreen extends StatefulWidget {
  final int courtId;
  const CancellationTermsScreen({super.key, required this.courtId});

  @override
  State<CancellationTermsScreen> createState() => _CancellationTermsScreenState();
}

class _CancellationTermsScreenState extends State<CancellationTermsScreen> {
  final _full = TextEditingController();
  final _partial = TextEditingController();
  final _partialPercent = TextEditingController();
  final _latePercent = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _full.dispose();
    _partial.dispose();
    _partialPercent.dispose();
    _latePercent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/courts/${widget.courtId}/cancellation');
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
      _full.text = '${data['full_hours'] ?? 12}';
      _partial.text = '${data['partial_hours'] ?? 6}';
      _partialPercent.text = '${data['partial_percent'] ?? 50}';
      _latePercent.text = '${data['late_percent'] ?? 0}';
      _error = null;
    } catch (error) {
      _error = Api.failureMessage(error, fallback: 'Could not load cancellation terms.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api().post('/courts/${widget.courtId}/cancellation', data: {
        'full_hours': num.tryParse(_full.text.trim()) ?? 0,
        'partial_hours': num.tryParse(_partial.text.trim()) ?? 0,
        'partial_percent': num.tryParse(_partialPercent.text.trim()) ?? 0,
        'late_percent': num.tryParse(_latePercent.text.trim()) ?? 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation terms saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(error))));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Cancellation terms', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
                const Text('Players see these windows when they cancel a booking at this venue.'),
                const SizedBox(height: 16),
                _field(_full, 'Full refund if they cancel at least this many hours before play'),
                _field(_partial, 'Partial refund if they cancel at least this many hours before play'),
                _field(_partialPercent, 'Partial refund percent'),
                _field(_latePercent, 'Refund percent after the partial window'),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving' : 'Save terms'),
                ),
              ],
            ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
