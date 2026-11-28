import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../core/phone_fields.dart';
import '../../widgets/form_gap.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/tab_status.dart';
import 'member_fields.dart';

class VenueMembersScreen extends StatefulWidget {
  final int courtId;
  const VenueMembersScreen({super.key, required this.courtId});

  @override
  State<VenueMembersScreen> createState() => _VenueMembersScreenState();
}

class _VenueMembersScreenState extends State<VenueMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    var members = _members;
    try {
      final res = await Api().get('/subscriptions/members', params: {'court_id': widget.courtId});
      members = memberRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load members.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _members = members;
      _loading = false;
    });
  }

  Future<void> _desk() async {
    List<Map<String, dynamic>> plans = [];
    try {
      final res = await Api().get('/plans', params: {'court_id': widget.courtId});
      final records = res.data is Map ? res.data['records'] : null;
      if (records is List) {
        plans = records.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      }
    } catch (error) {
      if (!mounted) return;
      context.toastError(Api.failureMessage(error));
      return;
    }
    if (!mounted) return;
    if (plans.isEmpty) {
      context.toastInfo('Create a subscription plan before recording a desk membership.');
      return;
    }
    final phone = TextEditingController();
    var planId = plans.first['id'].toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Membership at the desk'),
              content: FormGap(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: planId,
                    decoration: const InputDecoration(labelText: 'Plan'),
                    items: [
                      for (final plan in plans)
                        DropdownMenuItem(value: plan['id'].toString(), child: Text('${plan['name']}')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialog(() => planId = value);
                    },
                  ),
                  PhoneField(
                    controller: phone,
                    label: 'Player mobile',
                    helperText: 'They must already have signed in to KoCourt with this number',
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    try {
                      final mobile = normalizeIndianMobile(phone.text);
                      await Api().post('/subscriptions/desk', data: {
                        'plan_id': int.parse(planId),
                        'phone': mobile,
                      });
                      if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      dialogContext.toastError(
                        error is PhoneFieldError ? error.message : Api.failureMessage(error),
                      );
                    }
                  },
                  child: const Text('Add member'),
                ),
              ],
            );
          },
        );
      },
    );
    phone.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Members', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: _loading ? null : _desk, child: const Text('At the desk')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [TabErrorBanner(message: _error!, onRetry: _load)],
                )
              : _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.award, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text('No active members', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _members.length,
                    itemBuilder: (_, i) {
                      final m = _members[i];
                      final isActive = m['status'] == 'active';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            TimePlate(top: '${m['user_name'] ?? 'M'}'.characters.first.toUpperCase(), filled: isActive, width: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('${m['plan_name'] ?? ''} · ${membershipSlotLabel(m['slot_type'])}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(memberVisitLine(m), style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            isActive ? const StatusTag('Active', tone: TagTone.free) : const StatusTag('Expired', tone: TagTone.due),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
