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
    try {
      final res = await Api().get('/subscriptions', params: {'user_id': auth.userId});
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewed!'), backgroundColor: AppColors.secondary));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal failed'), backgroundColor: AppColors.error));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription renewed!'), backgroundColor: AppColors.secondary));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Renewal failed'), backgroundColor: AppColors.error));
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
                      Icon(AppIcons.award, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No memberships', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Subscribe to a venue plan to get started', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isExpiring ? AppColors.error.withValues(alpha: 0.3) : Colors.grey[100]!),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(s['court_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
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
                            const SizedBox(height: 8),
                            Text(s['plan_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text('${s['start_date'] ?? ''} → ${s['end_date'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            if (isExpiring && isActive) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text('Expiring in $daysRemaining days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange[700])),
                                ],
                              ),
                            ],
                            if (!isActive || isExpiring) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity, height: 40,
                                child: ElevatedButton(
                                  onPressed: () => _renew(s),
                                  child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
