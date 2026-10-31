import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'schedule_fields.dart';
import 'walk_in_fields.dart';

class BookingDetailScreen extends StatefulWidget {
  final int bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    Map<String, dynamic>? booking;
    try {
      final res = await Api().get('/bookings/${widget.bookingId}');
      final raw = res.data['booking'];
      if (raw is! Map) throw const FormatException('Missing booking');
      booking = Map<String, dynamic>.from(raw);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load this booking.');
    }
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
          'This marks the booking cancelled and frees the time. If a payment is attached, the server records the refund review from the booking terms.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await Api().delete('/bookings/${widget.bookingId}');
      if (!mounted) return;
      final message = '${res.data['message'] ?? 'Booking cancelled.'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.failureMessage(caught, fallback: 'Could not cancel this booking.')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _move() async {
    final booking = _booking;
    if (booking == null) return;
    var when = DateTime.now().add(const Duration(days: 1));
    var hour = 18;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Move booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The time changes if that hour is free. The price already stored on this booking stays the same.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('d MMM yyyy').format(when)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: when,
                  );
                  if (picked != null) setDialog(() => when = picked);
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: hour,
                items: [for (var value = 0; value <= 23; value++) DropdownMenuItem(value: value, child: Text('${value.toString().padLeft(2, '0')}:00'))],
                onChanged: (value) {
                  if (value != null) setDialog(() => hour = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
            TextButton(
              onPressed: () async {
                try {
                  final date = DateFormat('yyyy-MM-dd').format(when);
                  await Api().put('/bookings/${widget.bookingId}', data: rescheduleBody(date: date, startHour: hour));
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (caught) {
                  if (!ctx.mounted) return;
                  final message = caught is ScheduleFieldError
                      ? caught.message
                      : Api.failureMessage(caught, fallback: 'Could not move this booking.');
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
                }
              },
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final booking = _booking;
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Booking not found.'))),
      );
    }
    final status = '${booking['status'] ?? ''}';
    final canChange = status == 'confirmed' && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(bookingPerson(booking), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${booking['court_name'] ?? ''}', style: TextStyle(color: Colors.grey[700])),
          if ('${booking['space_name'] ?? ''}'.isNotEmpty) Text('${booking['space_name']}'),
          const SizedBox(height: 16),
          Text('${booking['start_time']} – ${booking['end_time']}'),
          const SizedBox(height: 8),
          Text('Status $status'),
          Text('Payment ${booking['payment_status'] ?? ''}'),
          const SizedBox(height: 8),
          Text('₹${booking['total_price'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 18)),
          if ('${booking['notes'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${booking['notes']}'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          if (canChange) ...[
            OutlinedButton(onPressed: _move, child: const Text('Move time')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _cancel,
              child: const Text('Cancel booking', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ],
      ),
    );
  }
}
