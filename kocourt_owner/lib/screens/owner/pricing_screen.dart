import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/pricing-rules', params: {'court_id': widget.courtId});
      _rules = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addRule() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String type = 'peak';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Pricing Rule', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Rule name (e.g. Weekend Peak)')),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Price multiplier (e.g. 1.5)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'peak', child: Text('Peak')),
                  DropdownMenuItem(value: 'offpeak', child: Text('Off-Peak')),
                  DropdownMenuItem(value: 'weekend', child: Text('Weekend')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'multiplier': double.tryParse(priceCtrl.text.trim()) ?? 1.0,
                'type': type,
              }),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (result == null || result['name'].toString().isEmpty) return;
    try {
      await Api().post('/pricing-rules', data: {...result, 'court_id': widget.courtId});
      _load();
    } catch (_) {}
  }

  Future<void> _deleteRule(int id) async {
    try {
      await Api().delete('/pricing-rules/$id');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pricing Rules', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _addRule, icon: const Icon(AppIcons.plus))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.price_change_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No pricing rules', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _addRule, icon: const Icon(AppIcons.plus, size: 16), label: const Text('Add Rule')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _rules.length,
                    itemBuilder: (_, i) {
                      final r = _rules[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.price_change, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('${r['type'] ?? ''} \u2022 ${r['multiplier'] ?? 1}x', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            IconButton(onPressed: () => _deleteRule(r['id']), icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
