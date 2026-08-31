import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    context.read<AuthProvider>();
    try {
      final res = await Api().get('/payments/history');
      _payments = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'subscription':
        return AppIcons.award;
      default:
        return AppIcons.calendarDays;
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'paid':
        return AppColors.secondary;
      case 'demo':
        return Colors.blue;
      case 'created':
        return Colors.orange;
      case 'refund_pending':
        return Colors.deepOrange;
      case 'failed':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'paid':
        return 'PAID';
      case 'demo':
        return 'DEMO';
      case 'created':
        return 'PENDING';
      case 'refund_pending':
        return 'REFUND';
      case 'failed':
        return 'FAILED';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.wallet, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No payments yet', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Your payment history will appear here', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loading = true);
                    await _load();
                  },
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _payments.length,
                    itemBuilder: (_, i) {
                      final p = _payments[i];
                      final type = p['type'] ?? 'booking';
                      final status = p['status'] ?? 'created';
                      final amount = double.tryParse('${p['amount'] ?? 0}') ?? 0;
                      final statusColor = _colorForStatus(status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[100]!),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_iconForType(type), size: 20, color: statusColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          type == 'subscription' ? 'Subscription' : 'Booking',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      Text(
                                        '\u20B9${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _labelForStatus(status),
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDate(p['created_at']),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (p['cf_order_id'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order: ${p['cf_order_id']}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[350]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
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
