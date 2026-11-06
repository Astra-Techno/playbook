import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'booking_ticket.dart';

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
  String? _error;

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
      final raw = res.data['booking'] ?? res.data;
      if (raw is! Map) throw const FormatException('Booking was not returned.');
      _booking = Map<String, dynamic>.from(raw);
    } catch (caught) {
      _error = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not load this booking.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Booking not found.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/bookings'), child: const Text('My bookings')),
              ],
            ),
          ),
        ),
      );
    }

    final ticket = ticketFromBooking(_booking!);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F9),
        title: const Text('Booking', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.secondary),
            const SizedBox(height: 8),
            const Text('Booking confirmed', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Your slot is reserved', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.venue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        if (ticket.place.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(ticket.place, style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _line('Date', ticket.date),
                        _line('Time', ticket.time),
                        if (ticket.space.isNotEmpty) _line('Space', ticket.space),
                        if (ticket.amount.isNotEmpty) _line('Amount paid', ticket.amount),
                        _line('Booking ID', ticket.id > 0 ? '${ticket.id}' : '—'),
                        _line('Status', ticket.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/bookings'),
              child: const Text('View my bookings', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
