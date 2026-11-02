import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Members', style: TextStyle(fontWeight: FontWeight.w800))),
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
                      Icon(AppIcons.award, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No active members', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text((m['user_name'] ?? 'M')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('${m['plan_name'] ?? ''} · ${membershipSlotLabel(m['slot_type'])}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  Text('Expires: ${m['end_date'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'EXPIRED',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isActive ? AppColors.secondary : AppColors.error),
                              ),
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
