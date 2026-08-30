import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class StaffScreen extends StatefulWidget {
  final int courtId;
  const StaffScreen({super.key, required this.courtId});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/court-staff', params: {'court_id': widget.courtId});
      _staff = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addStaff() async {
    final phoneCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'staff');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: 'Phone number'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: roleCtrl, decoration: const InputDecoration(hintText: 'Role (e.g. staff, manager)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {'phone': phoneCtrl.text.trim(), 'role': roleCtrl.text.trim()}),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result['phone']!.isEmpty) return;
    try {
      // First search for user by phone
      final userRes = await Api().get('/users/search', params: {'phone': result['phone']});
      final userId = userRes.data['user']?['id'];
      if (userId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found'), backgroundColor: AppColors.error));
        return;
      }
      await Api().post('/court-staff', data: {'court_id': widget.courtId, 'user_id': userId, 'role': result['role']});
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add staff'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _removeStaff(int id) async {
    try {
      await Api().delete('/court-staff/$id');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _addStaff, icon: const Icon(AppIcons.plus)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _staff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.users, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No staff members', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _addStaff, icon: const Icon(AppIcons.plus, size: 16), label: const Text('Add Staff')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _staff.length,
                    itemBuilder: (_, i) {
                      final s = _staff[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text((s['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name'] ?? s['phone'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text((s['role'] ?? 'staff').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeStaff(s['id']),
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
