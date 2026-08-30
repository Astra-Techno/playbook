import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class ManagePlansScreen extends StatefulWidget {
  final int courtId;
  final int? spaceId;
  const ManagePlansScreen({super.key, required this.courtId, this.spaceId});

  @override
  State<ManagePlansScreen> createState() => _ManagePlansScreenState();
}

class _ManagePlansScreenState extends State<ManagePlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/plans', params: {'court_id': widget.courtId});
      _plans = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addPlan() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Plan', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Plan name (e.g. Monthly Pro)')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Price (₹)')),
            const SizedBox(height: 12),
            TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Duration (days)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameCtrl.text.trim(),
              'price': priceCtrl.text.trim(),
              'duration_days': int.tryParse(durationCtrl.text.trim()) ?? 30,
            }),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result['name'].toString().isEmpty) return;
    try {
      await Api().post('/plans', data: {...result, 'court_id': widget.courtId});
      _load();
    } catch (_) {}
  }

  Future<void> _deletePlan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api().delete('/plans/$id');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Plans', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _addPlan, icon: const Icon(AppIcons.plus))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.award, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No plans yet', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _addPlan, icon: const Icon(AppIcons.plus, size: 16), label: const Text('Create Plan')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _plans.length,
                    itemBuilder: (_, i) {
                      final p = _plans[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[100]!),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(AppIcons.award, size: 22, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('₹${p['price'] ?? 0} • ${p['duration_days'] ?? 30} days', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            IconButton(onPressed: () => _deletePlan(p['id']), icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
