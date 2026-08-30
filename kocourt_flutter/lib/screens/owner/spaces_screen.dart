import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class SpacesScreen extends StatefulWidget {
  final int courtId;
  const SpacesScreen({super.key, required this.courtId});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Map<String, dynamic>> _spaces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/sub-courts', params: {'court_id': widget.courtId});
      _spaces = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addSpace() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Space', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'e.g. Court 1, Lane A'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await Api().post('/sub-courts', data: {'court_id': widget.courtId, 'name': result});
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add space'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteSpace(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Space?'),
        content: const Text('This will remove the space and its bookings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api().delete('/sub-courts/$id');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Spaces', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _addSpace, icon: const Icon(AppIcons.plus)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _spaces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.layoutGrid, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No spaces yet', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Add courts, lanes, or rooms', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addSpace,
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('Add Space'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _spaces.length,
                    itemBuilder: (_, i) {
                      final s = _spaces[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(s['name'] ?? 'Space ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                            IconButton(
                              onPressed: () => _deleteSpace(s['id']),
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400]),
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
