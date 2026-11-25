import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: isExpiring && isActive ? AppColors.warning : AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['court_name'] ?? '', style: GoogleFonts.archivo(fontWeight: FontWeight.w900, fontSize: 18)),
                                      const SizedBox(height: 4),
                                      isActive ? const StatusTag('Active', tone: TagTone.free) : const StatusTag('Expired', tone: TagTone.due),
                                    ],
                                  ),
                                ),
                                // Season-pass countdown over the last 30 days.
                                if (isActive && s['days_remaining'] != null)
                                  SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: CustomPaint(
                                      painter: StopwatchRingPainter(
                                        progress: (daysRemaining / 30).clamp(0.0, 1.0),
                                        color: isExpiring ? AppColors.warning : context.brand.primary,
                                      ),
                                      child: Center(
                                        child: Text('${daysRemaining}d',
                                            style: GoogleFonts.archivo(fontSize: 13, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(s['plan_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('${s['start_date'] ?? ''} → ${s['end_date'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            if (isExpiring && isActive) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warningDark),
                                  const SizedBox(width: 4),
                                  Text('Expiring in $daysRemaining days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningDark)),
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
