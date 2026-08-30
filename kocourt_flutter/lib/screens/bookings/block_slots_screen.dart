import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class BlockSlotsScreen extends StatefulWidget {
  final int courtId;
  final int? spaceId;
  const BlockSlotsScreen({super.key, required this.courtId, this.spaceId});

  @override
  State<BlockSlotsScreen> createState() => _BlockSlotsScreenState();
}

class _BlockSlotsScreenState extends State<BlockSlotsScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/blocked-slots', params: {'court_id': widget.courtId});
      _blocked = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addBlock() async {
    DateTime? startDate;
    DateTime? endDate;
    final reasonCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Block Slots', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(startDate != null ? DateFormat('MMM d, yyyy').format(startDate!) : 'Start Date'),
                trailing: const Icon(AppIcons.calendarDays, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: startDate ?? DateTime.now());
                  if (d != null) setDialogState(() => startDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(endDate != null ? DateFormat('MMM d, yyyy').format(endDate!) : 'End Date'),
                trailing: const Icon(AppIcons.calendarDays, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, firstDate: startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: endDate ?? startDate ?? DateTime.now());
                  if (d != null) setDialogState(() => endDate = d);
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Reason (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (startDate != null && endDate != null) {
                  Navigator.pop(ctx, {
                    'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
                    'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
                    'reason': reasonCtrl.text.trim(),
                  });
                }
              },
              child: const Text('Block', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await Api().post('/blocked-slots', data: {...result, 'court_id': widget.courtId});
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to block'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _removeBlock(int id) async {
    try {
      await Api().delete('/blocked-slots/$id');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Block Slots', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _addBlock, icon: const Icon(AppIcons.plus))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No blocked periods', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _addBlock, icon: const Icon(AppIcons.plus, size: 16), label: const Text('Block Period')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _blocked.length,
                    itemBuilder: (_, i) {
                      final b = _blocked[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.block, size: 18, color: AppColors.error),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${b['start_date']} → ${b['end_date']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  if (b['reason'] != null && b['reason'].toString().isNotEmpty)
                                    Text(b['reason'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeBlock(b['id']),
                              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
