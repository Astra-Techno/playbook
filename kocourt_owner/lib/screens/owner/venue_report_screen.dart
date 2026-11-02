import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'report_figures.dart';

class VenueReportScreen extends StatefulWidget {
  final int courtId;
  const VenueReportScreen({super.key, required this.courtId});

  @override
  State<VenueReportScreen> createState() => _VenueReportScreenState();
}

class _VenueReportScreenState extends State<VenueReportScreen> {
  bool _loading = true;
  String? _error;
  VenueReportFigures? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    VenueReportFigures? report = _report;
    try {
      final res = await Api().get('/courts/${widget.courtId}/report');
      report = venueReport(res.data);
      if (report == null) {
        throw const FormatException('The venue report was incomplete.');
      }
    } catch (caught) {
      error = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not load the report.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Report', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) TabErrorBanner(message: _error!, onRetry: _load),
                  if (report != null) ...[
                    Text('${report.from} to ${report.to}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    _figure('Booking prices', reportMoney(report.bookingGross), 'Confirmed booking prices, including walk-ins'),
                    _figure('Collected', reportMoney(report.collected), 'Paid booking and membership payments, after successful refunds'),
                    _figure('Confirmed', '${report.confirmedCount}', 'Bookings in this window'),
                    _figure('Cancelled', '${report.cancelledCount}', '${report.cancelRate}% of confirmed and cancelled bookings'),
                    _figure('Players', '${report.uniquePlayers}', '${report.repeatPlayers} booked more than once'),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _figure(String label, String value, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3)),
        ],
      ),
    );
  }
}
