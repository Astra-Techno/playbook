import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../chat/chat_screen.dart';
import 'schedule_fields.dart';
import 'walk_in_fields.dart';
import 'attendance_fields.dart';

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

  /// Online bookings have a player account. Walk-ins only have a guest name.
  int? _playerUserId(Map<String, dynamic> booking) {
    if ('${booking['guest_name'] ?? ''}'.trim().isNotEmpty) return null;
    final id = int.tryParse('${booking['user_id'] ?? 0}') ?? 0;
    return id > 0 ? id : null;
  }

  Future<void> _messagePlayer() async {
    final booking = _booking;
    if (booking == null) return;
    final playerId = _playerUserId(booking);
    if (playerId == null) {
      context.toastInfo('Walk-in guests have no KoCourt chat account.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: widget.bookingId,
          courtName: '${booking['court_name'] ?? ''}',
          otherUserName: bookingPerson(booking),
          receiverId: playerId,
        ),
      ),
    );
  }

  Future<void> _mark(String action) async {
    setState(() => _busy = true);
    try {
      final res = await Api().post('/bookings/${widget.bookingId}/attendance', data: {'action': action});
      if (!mounted) return;
      context.toastSuccess('${res.data['message'] ?? 'Saved.'}');
      await _load();
    } catch (caught) {
      if (!mounted) return;
      context.toastError(Api.failureMessage(caught, fallback: 'Could not mark this booking.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Cancel booking?',
      body:
          'This marks the booking cancelled and frees the time. If a payment is attached, the server records the refund review from the booking terms.',
      cancelLabel: 'Keep',
      confirmLabel: 'Cancel booking',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await Api().delete('/bookings/${widget.bookingId}');
      if (!mounted) return;
      final message = '${res.data['message'] ?? 'Booking cancelled.'}';
      context.toastInfo(message);
      Navigator.pop(context, true);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.toastError(Api.failureMessage(caught, fallback: 'Could not cancel this booking.'));
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
                  ctx.toastError(message);
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
    // Server refuses changes once play has started (BookingController "Cannot cancel past bookings").
    final start = DateTime.tryParse('${booking['start_time']}');
    final started = start != null && !start.isAfter(DateTime.now());
    final canChange = status == 'confirmed' && !_busy && !started;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Booking'), backgroundColor: AppColors.surface),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summaryCard(booking, status, start),
          if (booking['addons'] is List && (booking['addons'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Kit add-ons (paid online)', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final kit in (booking['addons'] as List).whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${kit['quantity']} × ${kit['name']}'
                  '${(int.tryParse('${kit['deposit_rupees']}') ?? 0) > 0 ? ' · collect Rs ${kit['deposit_rupees']} deposit' : ''}'
                  ' · ${kit['state'] == 'reserved' ? 'hand over at check-in' : kit['state']}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
          if ('${booking['notes'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${booking['notes']}'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          if (_playerUserId(booking) != null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _messagePlayer,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Message player'),
            ),
            const SizedBox(height: 8),
          ],
          if (canChange) ...[
            OutlinedButton(onPressed: _move, child: const Text('Move time')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _cancel,
              child: const Text('Cancel booking', style: TextStyle(color: AppColors.error)),
            ),
          ],
          if (attendanceUnmarked(booking) && !_busy) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _mark('check_in'), child: const Text('Check in')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _mark('no_show'), child: const Text('No-show')),
          ],
        ],
      ),
    );
  }

  /// v4 ticket-style summary: who, where, when, and slanted status tags.
  Widget _summaryCard(Map<String, dynamic> booking, String status, DateTime? start) {
    final end = DateTime.tryParse('${booking['end_time']}');
    final space = '${booking['space_name'] ?? ''}';
    final when = start == null
        ? '${booking['start_time'] ?? ''}'
        : '${DateFormat('EEE d MMM').format(start)} · ${DateFormat('h:mm a').format(start)}'
            '${end == null ? '' : ' – ${DateFormat('h:mm a').format(end)}'}';
    final collection = collectionLabel(booking['collection_method']);
    final arrival = recordedAfterPlayLabel(booking) ?? attendanceLabel(booking['attendance']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TimePlate(
                top: start == null ? '—' : DateFormat(start.minute == 0 ? 'h a' : 'h:mm').format(start),
                bottom: start == null ? '' : DateFormat('d MMM').format(start),
                filled: status != 'cancelled',
                width: 74,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookingPerson(booking), style: AppFonts.display(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text(
                      [booking['court_name'] ?? '', space].where((v) => '$v'.isNotEmpty).join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(when, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusTag.forBooking(status),
              StatusTag.forBooking('${booking['payment_status'] ?? ''}'),
              if (collection != null) StatusTag(collection, tone: TagTone.muted),
              if (arrival != null) StatusTag(arrival, tone: TagTone.brand),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Amount', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(rupees(booking['total_price'] ?? 0), style: AppFonts.score(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
