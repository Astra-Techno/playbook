import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final int bookingId;
  final Map<String, dynamic>? booking;
  const BookingConfirmationScreen({super.key, this.bookingId = 0, this.booking});

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _booking = widget.booking;
      _loading = false;
    } else {
      _fetchBooking();
    }
  }

  Future<void> _fetchBooking() async {
    try {
      final res = await Api().get('/bookings/${widget.bookingId}');
      setState(() {
        _booking = Map<String, dynamic>.from(res.data['booking'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final booking = _booking ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 40, color: AppColors.secondary),
              ),
              const SizedBox(height: 24),
              const Text('Booking Confirmed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Your slot has been reserved', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    _detailRow(AppIcons.mapPin, 'Venue', booking['court_name'] ?? ''),
                    const Divider(height: 20),
                    _detailRow(AppIcons.calendarDays, 'Date', booking['date'] ?? ''),
                    const Divider(height: 20),
                    _detailRow(AppIcons.clock, 'Time', '${booking['start_time'] ?? ''} - ${booking['end_time'] ?? ''}'),
                    if (booking['sub_court_name'] != null) ...[
                      const Divider(height: 20),
                      _detailRow(AppIcons.layoutGrid, 'Space', booking['sub_court_name']),
                    ],
                    if (booking['amount'] != null) ...[
                      const Divider(height: 20),
                      _detailRow(Icons.receipt_long, 'Amount', '\u20B9${booking['amount']}'),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('View My Bookings', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
