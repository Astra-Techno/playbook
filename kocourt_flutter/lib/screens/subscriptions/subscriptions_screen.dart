import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Map<String, dynamic>> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await Api().get('/subscriptions', params: {'user_id': userId});
      _subs = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _renew(Map<String, dynamic> sub) async {
    final price = double.tryParse('${sub['plan_price'] ?? 0}') ?? 0;
    if (price <= 0) {
      // Free plan or missing price — renew directly
      try {
        await Api().post('/subscriptions/renew', data: {'subscription_id': sub['id']});
        _load();
        if (mounted) context.toastSuccess('Renewed!');
      } catch (_) {
        if (mounted) context.toastError('Renewal failed');
      }
      return;
    }

    final result = await PaymentService.processPayment(
        context: context,
      amount: price,
      type: 'subscription',
      payload: {
        'plan_id': sub['plan_id'],
        'court_id': sub['court_id'],
        'slot_type': sub['slot_type'] ?? 'full_day',
        'duration_days': sub['duration_days'] ?? 30,
      },
    );

    if (!mounted) return;

    if (result.success) {
      context.toastSuccess('Subscription renewed!');
      _load();
    } else {
      context.toastError(result.error ?? 'Renewal failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('My Memberships', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _subs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.award, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text('No memberships', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Subscribe to a venue plan to get started', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _subs.length,
                    itemBuilder: (_, i) {
                      final s = _subs[i];
                      final isActive = s['status'] == 'active';
                      final daysRemaining = int.tryParse('${s['days_remaining'] ?? 100}') ?? 100;
                      final isExpiring = s['days_remaining'] != null && daysRemaining <= 7;
                      final ends = DateTime.tryParse('${s['end_date'] ?? ''}');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: KoCard(
                          kicker: isActive ? 'Membership' : 'Membership ended',
                          title: '${s['court_name'] ?? ''}',
                          meta: '${s['plan_name'] ?? ''}',
                          badge: isActive && s['days_remaining'] != null ? '${daysRemaining}d' : null,
                          stats: [
                            if (isActive && s['days_remaining'] != null) KoStat('$daysRemaining', 'days left'),
                            if (ends != null) KoStat('${ends.day}/${ends.month}', isActive ? 'renews or ends' : 'ended'),
                          ],
                          middle: Row(
                            children: [
                              isActive ? const StatusTag('Active', tone: TagTone.free) : const StatusTag('Expired', tone: TagTone.due),
                              if (isExpiring && isActive) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text('Expiring in $daysRemaining days',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningDark)),
                                ),
                              ],
                            ],
                          ),
                          actionLabel: !isActive || isExpiring ? 'Renew' : null,
                          onAction: () => _renew(s),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
