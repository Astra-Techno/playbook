import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'schedule_fields.dart';

class PricingScreen extends StatefulWidget {
  final int courtId;
  final int? spaceId;
  const PricingScreen({super.key, required this.courtId, this.spaceId});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;
  String? _error;
  DateTime _previewDate = DateTime.now();
  int _previewHour = 18;
  String? _previewText;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    List<Map<String, dynamic>>? rules;
    try {
      final res = await Api().get('/pricing-rules', params: {
        'court_id': widget.courtId,
        if (widget.spaceId != null) 'sub_court_id': widget.spaceId,
      });
      final raw = res.data['rules'];
      if (raw is! List) throw const FormatException('Missing rules');
      rules = raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load pricing rules.');
    }
    if (!mounted) return;
    setState(() {
      if (rules != null) _rules = rules;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _preview() async {
    setState(() => _previewing = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(_previewDate);
      final res = await Api().get('/pricing-rules/calculate', params: {
        'court_id': widget.courtId,
        'date': date,
        'hour': _previewHour,
        if (widget.spaceId != null) 'sub_court_id': widget.spaceId,
      });
      final price = res.data['effective_price'];
      final rule = res.data['rule'];
      final ruleName = rule is Map ? '${rule['name'] ?? ''}' : '';
      final source = ruleName.isEmpty ? 'Base hourly rate' : ruleName;
      if (!mounted) return;
      setState(() => _previewText = '₹$price/hr · $source');
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _previewText = Api.failureMessage(caught, fallback: 'Could not preview this hour.');
      });
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _addRule() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final priorityCtrl = TextEditingController(text: '0');
    var dayType = 'all';
    var startHour = 18;
    var endHour = 22;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add pricing rule', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A space rule is used before a venue rule. Inside one list, the higher priority wins, then the newest rule. Saved bookings keep the price already stored on them.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Name, such as Weekend peak')),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Price per hour (₹)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: dayType,
                  items: [
                    for (final day in pricingDayTypes)
                      DropdownMenuItem(value: day, child: Text(pricingDayLabel(day))),
                  ],
                  onChanged: (value) => setDialogState(() => dayType = value ?? 'all'),
                  decoration: const InputDecoration(labelText: 'Days'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _hourField('From', startHour, (value) => setDialogState(() => startHour = value))),
                    const SizedBox(width: 8),
                    Expanded(child: _hourField('Until', endHour, (value) => setDialogState(() => endHour = value), until: true)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priorityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final body = pricingRuleBody(
                    courtId: widget.courtId,
                    spaceId: widget.spaceId,
                    name: nameCtrl.text,
                    dayType: dayType,
                    startHour: startHour,
                    endHour: endHour,
                    price: double.tryParse(priceCtrl.text.trim()) ?? -1,
                    priority: int.tryParse(priorityCtrl.text.trim()) ?? 0,
                  );
                  await Api().post('/pricing-rules', data: body);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (caught) {
                  if (!ctx.mounted) return;
                  final message = caught is ScheduleFieldError
                      ? caught.message
                      : Api.failureMessage(caught, fallback: 'Could not save this rule.');
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
                }
              },
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _hourField(String label, int value, ValueChanged<int> onChanged, {bool until = false}) {
    final hours = until ? [for (var hour = 1; hour <= 24; hour++) hour] : [for (var hour = 0; hour <= 23; hour++) hour];
    return DropdownButtonFormField<int>(
      initialValue: hours.contains(value) ? value : hours.first,
      items: [for (final hour in hours) DropdownMenuItem(value: hour, child: Text('$hour:00'))],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _deleteRule(int id) async {
    try {
      await Api().delete('/pricing-rules/$id');
      _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.failureMessage(caught, fallback: 'Could not delete this rule.')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = tabPhase(loading: _loading, failed: _error != null, hasData: _rules.isNotEmpty);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.spaceId == null ? 'Venue pricing' : 'Space pricing', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _addRule, icon: const Icon(AppIcons.plus))],
      ),
      body: phase == TabPhase.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : phase == TabPhase.failed
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: TabErrorBanner(message: _error!, onRetry: _load)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_error != null) ...[
                        TabErrorBanner(message: _error!, onRetry: _load),
                        const SizedBox(height: 12),
                      ],
                      _previewCard(),
                      const SizedBox(height: 16),
                      if (_rules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: TabEmptyMessage(
                            icon: Icons.price_change_outlined,
                            title: 'No pricing rules yet',
                            subtitle: 'Hours without a rule use the hourly rate.',
                          ),
                        )
                      else
                        ..._rules.map(_ruleTile),
                    ],
                  ),
                ),
    );
  }

  Widget _previewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview one hour', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _previewDate,
                    );
                    if (picked != null) setState(() => _previewDate = picked);
                  },
                  child: Text(DateFormat('d MMM').format(_previewDate)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _previewHour,
                  items: [for (var hour = 0; hour <= 23; hour++) DropdownMenuItem(value: hour, child: Text('$hour:00'))],
                  onChanged: (value) {
                    if (value != null) setState(() => _previewHour = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _previewing ? null : _preview, child: Text(_previewing ? 'Checking…' : 'Check price')),
          if (_previewText != null) Text(_previewText!, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _ruleTile(Map<String, dynamic> rule) {
    final id = asScheduleId(rule['id']);
    final day = pricingDayLabel('${rule['day_type'] ?? 'all'}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.price_change, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rule['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '$day · ${rule['start_hour']}:00–${rule['end_hour']}:00 · ₹${rule['price']}/hr · priority ${rule['priority'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (id != null)
            IconButton(
              onPressed: () => _deleteRule(id),
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }
}
