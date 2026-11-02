import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:intl/intl.dart';
import 'booking_price_export.dart';

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
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    Map<String, dynamic>? summary;
    List<Map<String, dynamic>>? transactions;
    try {
      final res = await Api().get('/earnings/venue', params: {'court_id': widget.courtId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final raw = data['summary'];
      if (raw is! Map || !raw.containsKey('total')) {
        throw const FormatException('Venue booking prices were incomplete.');
      }
      summary = Map<String, dynamic>.from(raw);
      transactions = List<Map<String, dynamic>>.from(
        (data['transactions'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (caught) {
      error = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not load booking prices.');
    }
    if (!mounted) return;
    setState(() {
      if (summary != null) {
        _summary = summary;
        _transactions = transactions ?? [];
      }
      _error = error;
      _loading = false;
    });
  }

  Future<void> _export() async {
    final spec = bookingPriceExport(courtId: widget.courtId);
    if (spec == null || _exporting) return;
    setState(() => _exporting = true);
    String message;
    try {
      final res = await Api().dio.get(
        '/earnings/export',
        queryParameters: spec.query,
        options: Options(headers: {'Accept': 'text/csv'}),
      );
      final body = res.data is String ? res.data as String : '';
      if (!bookingPriceCsv(body)) {
        throw const FormatException('The export was not a booking-price file.');
      }
      await Clipboard.setData(ClipboardData(text: body));
      message = 'Booking prices copied. Paste them into a spreadsheet.';
    } catch (caught) {
      message = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not export booking prices.');
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCurrency(dynamic val) {
    final num = double.tryParse('${val ?? 0}') ?? 0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(num);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Booking prices', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_summary != null)
            TextButton(
              onPressed: _exporting ? null : _export,
              child: Text(_exporting ? 'Exporting' : 'Export'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _summary == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'No booking prices yet', textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
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
                        if (_error != null) ...[
                          Text(_error!, style: const TextStyle(color: AppColors.error)),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'These are confirmed booking prices, including walk-ins. They are not payments collected and not payouts.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _statCard('Booking prices', _formatCurrency(_summary!['total']), AppColors.primary, Icons.receipt_long)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Today', _formatCurrency(_summary!['today']), AppColors.secondary, Icons.calendar_today_outlined)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _statCard('This week', _formatCurrency(_summary!['this_week']), Colors.blue, Icons.trending_up)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('This month', _formatCurrency(_summary!['this_month']), Colors.teal, Icons.calendar_month_outlined)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Bookings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                Text(t['guest_name'] ?? t['user_name'] ?? 'Booking', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${t['space_name'] ?? ''} ${t['start_time'] != null ? '· ${t['start_time']}' : ''}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(t['total_price']),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
