import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
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
        return AppColors.info;
      case 'created':
        return AppColors.warningDark;
      case 'refund_pending':
        return AppColors.warningDark;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  StatusTag _tagForStatus(String status) => switch (status) {
        'paid' => const StatusTag('Paid', tone: TagTone.free),
        'demo' => const StatusTag('Demo', tone: TagTone.brand),
        'created' => const StatusTag('Pending', tone: TagTone.ending),
        'refund_pending' => const StatusTag('Refund', tone: TagTone.ending),
        'failed' => const StatusTag('Failed', tone: TagTone.due),
        _ => StatusTag.forBooking(status),
      };

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Payment History'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.wallet, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text('No payments yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Your payment history will appear here', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
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
                                        style: GoogleFonts.archivo(fontWeight: FontWeight.w900, fontSize: 17),
                                      ),
                                    ],
                                  ),
                                  if (p['refund_status'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Refund: ${p['refund_status'].toString().replaceAll('_', ' ')} · INR ${(num.tryParse(p['refund_requested_amount'].toString()) ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _tagForStatus('$status'),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDate(p['created_at']),
                                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (p['cf_order_id'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order: ${p['cf_order_id']}',
                                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
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
