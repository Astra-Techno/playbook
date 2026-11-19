import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'staff_fields.dart';

class StaffScreen extends StatefulWidget {
  final int courtId;
  const StaffScreen({super.key, required this.courtId});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    var staff = _staff;
    try {
      final res = await Api().get('/court-staff', params: {'court_id': widget.courtId});
      staff = staffRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load staff.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _staff = staff;
      _loading = false;
    });
  }

  Future<void> _addStaff() async {
    final phoneCtrl = TextEditingController();
    var role = 'viewer';
    final result = await showAppSheet<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => FormGap(
          children: [
            Text(
              'Add staff',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.brand.ink),
            ),
            PhoneField(
              controller: phoneCtrl,
              label: 'Staff mobile',
              helperText: 'They must already have signed in to KoCourt with this number',
              autofocus: true,
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'viewer', label: Text('Viewer')),
                ButtonSegment(value: 'manager', label: Text('Manager')),
              ],
              selected: {role},
              onSelectionChanged: (next) => setDialog(() => role = next.first),
            ),
            Text(staffPermissionLine(role), style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!isTenDigitMobile(phoneCtrl.text)) {
                        ctx.toastError('Enter a 10-digit mobile number');
                        return;
                      }
                      try {
                        Navigator.pop(ctx, {
                          'phone': normalizeIndianMobile(phoneCtrl.text),
                          'role': role,
                        });
                      } on PhoneFieldError catch (e) {
                        ctx.toastError(e.message);
                      }
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    phoneCtrl.dispose();
    if (result == null || (result['phone'] ?? '').isEmpty) return;
    try {
      await Api().post('/court-staff', data: staffInviteBody(
        courtId: widget.courtId,
        phone: result['phone']!,
        role: result['role'] ?? 'viewer',
      ));
      _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(
          caught is PhoneFieldError
              ? caught.message
              : Api.failureMessage(caught, fallback: 'Failed to add staff'),
        );
      }
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    final current = staffRole(member['role']) ?? 'viewer';
    final next = current == 'manager' ? 'viewer' : 'manager';
    try {
      await Api().post('/court-staff/${member['id']}/role', data: staffRoleBody(next));
      _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'Could not change the role'));
      }
    }
  }

  Future<void> _removeStaff(int id) async {
    try {
      await Api().delete('/court-staff/$id');
      _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'Could not remove staff'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _addStaff, icon: const Icon(AppIcons.plus)),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: brand.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: brand.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) TabErrorBanner(message: _error!, onRetry: _load),
                  if (_error == null && _staff.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: TabEmptyMessage(
                        icon: AppIcons.users,
                        title: 'No staff members',
                        subtitle: 'Add a manager or a viewer by their KoCourt phone number',
                      ),
                    ),
                  for (final member in _staff)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: brand.primary.withValues(alpha: 0.1),
                            child: Text(
                              ((member['name'] ?? 'S').toString().isEmpty ? 'S' : (member['name'] ?? 'S').toString())[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w800, color: brand.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((member['name'] ?? member['phone'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(staffPermissionLine(member['role']), style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _changeRole(member),
                            child: Text(staffRoleLabel(member['role'])),
                          ),
                          IconButton(
                            onPressed: () => _removeStaff(int.tryParse('${member['id']}') ?? 0),
                            icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
