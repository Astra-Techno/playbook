import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class VenueEarningsScreen extends StatefulWidget {
  final int courtId;
  const VenueEarningsScreen({super.key, required this.courtId});

  @override
  State<VenueEarningsScreen> createState() => _VenueEarningsScreenState();
}

class _VenueEarningsScreenState extends State<VenueEarningsScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    try {
      final params = <String, dynamic>{'owner_id': auth.userId};
      if (widget.courtId > 0) params['court_id'] = widget.courtId;

      final res = await Api().get('/earnings', params: params);
      final data = Map<String, dynamic>.from(res.data);
      _summary = data['summary'] != null
          ? Map<String, dynamic>.from(data['summary'])
          : data; // fallback if no summary wrapper
      _transactions = List<Map<String, dynamic>>.from(
        (data['transactions'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatCurrency(dynamic val) {
    final num = double.tryParse('${val ?? 0}') ?? 0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(num);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _summary == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.wallet, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 12),
                      Text('No earnings data yet', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary cards — 2×2 grid
                        Row(
                          children: [
                            Expanded(child: _statCard('Total Earned', _formatCurrency(_summary!['total_earned']), AppColors.primary, Icons.account_balance_wallet_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('This Month', _formatCurrency(_summary!['this_month']), AppColors.secondary, Icons.calendar_today_outlined)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _statCard('This Week', _formatCurrency(_summary!['this_week']), Colors.blue, Icons.trending_up)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Pending', _formatCurrency(_summary!['pending_payout']), Colors.orange, Icons.hourglass_empty)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Recent Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        if (_transactions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, size: 40, color: AppColors.textDisabled),
                                const SizedBox(height: 8),
                                Text('No transactions yet', style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          )
                        else
                          ..._transactions.map((t) => _transactionTile(t)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> t) {
    final type = t['type']?.toString() ?? 'booking';
    final isSubscription = type == 'subscription';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isSubscription ? Colors.purple : AppColors.secondary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSubscription ? AppIcons.award : Icons.receipt_long,
              size: 18,
              color: isSubscription ? Colors.purple : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['customer_name'] ?? t['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${t['court_name'] ?? ''} ${t['slot_time'] != null ? '\u2022 ${t['slot_time']}' : ''}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(t['amount']),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
