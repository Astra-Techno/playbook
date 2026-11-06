import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:intl/intl.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'earnings_figures.dart';
import 'payout_request_fields.dart';

class OwnerEarningsScreen extends StatefulWidget {
  const OwnerEarningsScreen({super.key});

  @override
  State<OwnerEarningsScreen> createState() => _OwnerEarningsScreenState();
}

class _OwnerEarningsScreenState extends State<OwnerEarningsScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (_summary == null && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    Map<String, dynamic>? summary;
    List<Map<String, dynamic>>? transactions;
    List<Map<String, dynamic>>? payouts;
    List<Map<String, dynamic>>? requests;
    try {
      final res = await Api().get('/earnings', params: {'owner_id': auth.userId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final rawSummary = data['summary'];
      if (rawSummary is! Map) {
        throw const FormatException('Earnings response was incomplete.');
      }
      summary = Map<String, dynamic>.from(rawSummary);
      transactions = List<Map<String, dynamic>>.from(
        (data['transactions'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      payouts = payoutRows(data['payouts']);
      requests = payoutRows(data['payout_requests']);
    } catch (caught) {
      error = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not load earnings.');
    }
    if (!mounted) return;
    setState(() {
      if (summary != null) {
        _summary = summary;
        _transactions = transactions ?? [];
        _payouts = payouts ?? [];
        _requests = requests ?? [];
      }
      _error = error;
      _loading = false;
    });
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
      body: _earningsBody(),
    );
  }

  Widget _earningsBody() {
    final summary = _summary;
    final phase = tabPhase(
      loading: _loading,
      failed: _error != null,
      hasData: summary != null,
    );
    if (phase == TabPhase.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              TabErrorBanner(message: _error!, onRetry: _load),
              const SizedBox(height: 16),
            ],
            if (summary == null && _error == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: TabEmptyMessage(
                  icon: AppIcons.wallet,
                  title: 'No earnings data yet',
                  subtitle: 'Collected payments will show up here',
                ),
              )
            else if (summary != null) ...[
              const Text(
                'Collected is paid and demo payments for venues you own, after successful refunds. Paid out is a separate transfer record. Walk-in prices are not in this list.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Collected', _formatCurrency(moneySplit(summary)?.collected), AppColors.primary, Icons.account_balance_wallet_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Today', _formatCurrency(summary['today']), AppColors.secondary, Icons.calendar_today_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('This week', _formatCurrency(summary['this_week']), Colors.blue, Icons.trending_up)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('This month', _formatCurrency(summary['this_month']), Colors.teal, Icons.calendar_month_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Paid out', _formatCurrency(moneySplit(summary)?.paidOut), Colors.orange, Icons.payments_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Not yet paid out', _formatCurrency(moneySplit(summary)?.notYetPaidOut), AppColors.textPrimary, Icons.hourglass_empty)),
                ],
              ),
              const SizedBox(height: 16),
              _requestPayout(summary),
              const SizedBox(height: 24),
              const Text('Payouts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (_payouts.isEmpty)
                Text('No payout has been recorded.', style: TextStyle(color: AppColors.textMuted))
              else
                ..._payouts.map(_payoutTile),
              const SizedBox(height: 24),
              const Text('Payments', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
          ],
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
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _requestPayout(Map<String, dynamic> summary) {
    final open = openPayoutRequest(_requests);
    final waiting = moneySplit(summary)?.notYetPaidOut ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'A request asks for a manual transfer. It does not mark the money as paid out.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        if (open != null)
          Text(
            'Payout requested: ${_formatCurrency(open['amount'])}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          )
        else
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: waiting > 0 ? () => _askPayout(waiting) : null,
              child: const Text('Request payout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Future<void> _askPayout(double waiting) async {
    final amount = TextEditingController(text: waiting.toStringAsFixed(2));
    final note = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var sending = false;
        String? error;
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Request payout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Note, optional'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              setSheet(() {
                                sending = true;
                                error = null;
                              });
                              try {
                                final body = payoutRequestBody(amountText: amount.text, note: note.text);
                                await Api().post('/payout-requests', data: body);
                                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                              } catch (caught) {
                                setSheet(() {
                                  sending = false;
                                  error = caught is PayoutRequestError
                                      ? caught.message
                                      : Api.failureMessage(caught, fallback: 'Could not send this request.');
                                });
                              }
                            },
                      child: const Text('Send request', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    amount.dispose();
    note.dispose();
    if (sent == true) _load();
  }

  Widget _payoutTile(Map<String, dynamic> payout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${payout['note'] ?? 'Payout'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${payout['paid_at'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(_formatCurrency(payout['amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
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
