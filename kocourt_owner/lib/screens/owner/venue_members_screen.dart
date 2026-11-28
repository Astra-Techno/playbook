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
  MemberFilter _filter = MemberFilter.all;
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
      final res = await Api().get(
        '/subscriptions/members',
        params: {'court_id': widget.courtId},
      );
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
      final res = await Api().get(
        '/plans',
        params: {'court_id': widget.courtId},
      );
      final records = res.data is Map ? res.data['records'] : null;
      if (records is List) {
        plans = records
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
    } catch (error) {
      if (!mounted) return;
      context.toastError(Api.failureMessage(error));
      return;
    }
    if (!mounted) return;
    if (plans.isEmpty) {
      context.toastInfo(
        'Create a subscription plan before recording a desk membership.',
      );
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
                        DropdownMenuItem(
                          value: plan['id'].toString(),
                          child: Text('${plan['name']}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialog(() => planId = value);
                    },
                  ),
                  PhoneField(
                    controller: phone,
                    label: 'Player mobile',
                    helperText:
                        'They must already have signed in to KoCourt with this number',
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final mobile = normalizeIndianMobile(phone.text);
                      await Api().post(
                        '/subscriptions/desk',
                        data: {'plan_id': int.parse(planId), 'phone': mobile},
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      dialogContext.toastError(
                        error is PhoneFieldError
                            ? error.message
                            : Api.failureMessage(error),
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

  Future<void> _act(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await Api().post(path, data: data ?? const {});
      if (mounted) {
        context.toastSuccess(
          '${(res.data is Map ? res.data['message'] : null) ?? 'Done'}',
        );
      }
      _load();
    } catch (error) {
      if (mounted) context.toastError(Api.failureMessage(error));
    }
  }

  /// Desk actions for one member: nudge, pause, resume.
  Future<void> _memberActions(Map<String, dynamic> m) async {
    final id = m['id'];
    if (id == null) return;
    final frozen = memberFrozenUntil(m) != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${m['user_name'] ?? 'Member'}',
                style: AppFonts.display(fontSize: 18),
              ),
              subtitle: Text(memberVisitLine(m)),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send a reminder'),
              subtitle: const Text(
                'Renewal if it ends this week, otherwise "we miss you"',
              ),
              onTap: () => Navigator.pop(sheet, 'remind'),
            ),
            if (frozen)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('End the freeze today'),
                subtitle: const Text('Unused days go back to the member'),
                onTap: () => Navigator.pop(sheet, 'unfreeze'),
              )
            else
              for (final days in const [7, 14, 30])
                ListTile(
                  leading: const Icon(Icons.ac_unit_rounded),
                  title: Text('Freeze for $days days'),
                  subtitle: const Text(
                    'The end date moves out by the same days',
                  ),
                  onTap: () => Navigator.pop(sheet, 'freeze:$days'),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remind') return _act('/subscriptions/$id/remind');
    if (choice == 'unfreeze') return _act('/subscriptions/$id/unfreeze');
    final days = int.tryParse(choice.split(':').last);
    if (days != null) {
      return _act('/subscriptions/$id/freeze', data: {'days': days});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _members.where((m) => memberMatches(m, _filter)).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Members',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _desk,
            child: const Text('At the desk'),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
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
                  Text(
                    'No active members',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: shown.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in MemberFilter.values)
                            ChoiceChip(
                              label: Text(
                                '${memberFilterLabels[f]} · ${_members.where((m) => memberMatches(m, f)).length}',
                              ),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                        ],
                      ),
                    );
                  }
                  final m = shown[i - 1];
                  final isActive = m['status'] == 'active';
                  final frozen = memberFrozenUntil(m) != null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => _memberActions(m),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          TimePlate(
                            top: '${m['user_name'] ?? 'M'}'.characters.first
                                .toUpperCase(),
                            filled: isActive,
                            width: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['user_name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${m['plan_name'] ?? ''} · ${membershipSlotLabel(m['slot_type'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  memberVisitLine(m),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          frozen
                              ? const StatusTag('Frozen', tone: TagTone.brand)
                              : isActive
                              ? const StatusTag('Active', tone: TagTone.free)
                              : const StatusTag('Expired', tone: TagTone.due),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
