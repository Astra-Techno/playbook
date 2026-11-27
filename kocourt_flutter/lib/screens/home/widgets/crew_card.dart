import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:provider/provider.dart';

import '../../bookings/booking_ticket.dart' show bookingIdsFromVerify;
import '../home_logic.dart';

/// Matchday "Your crew": people you play with (GET /players/crew) and one-tap
/// rebook of your last squad game at the next same weekday and time.
/// Rebook pays through the normal checkout, then re-adds the same squad.
class CrewCard extends StatefulWidget {
  const CrewCard({super.key});

  @override
  State<CrewCard> createState() => _CrewCardState();
}

class _CrewCardState extends State<CrewCard> {
  List<Map<String, dynamic>> _mates = const [];
  Map<String, dynamic>? _rebook;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<AuthProvider>().isLoggedIn) return;
    try {
      final res = await Api().get('/players/crew');
      final mates = List<Map<String, dynamic>>.from((res.data['mates'] ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
      final rebook = res.data['rebook'] is Map ? Map<String, dynamic>.from(res.data['rebook'] as Map) : null;
      if (!mounted) return;
      setState(() {
        _mates = mates;
        _rebook = rebook;
      });
    } catch (_) {
      // Optional card; Home works without it.
    }
  }

  Future<void> _doRebook(Map<String, dynamic> r, DateTime start) async {
    setState(() => _busy = true);
    try {
      final result = await PaymentService.processPayment(
        context: context,
        amount: 0, // the server quote sets the real price
        type: 'booking',
        payload: {
          'court_id': r['court_id'],
          if (r['sub_court_id'] != null) 'sub_court_id': r['sub_court_id'],
          'slots': [
            {'start_time': r['start_time'], 'end_time': r['end_time'], 'total_price': 0},
          ],
          'type': 'hourly',
          'total_price': 0,
        },
      );
      if (!mounted || !result.success) return;
      final ids = bookingIdsFromVerify(result.verifyData);
      final bookingId = ids.isEmpty ? null : ids.first;
      if (bookingId == null) {
        context.go('/bookings');
        return;
      }
      try {
        await Api().post('/booking-players', data: {'booking_id': bookingId, 'user_ids': r['player_ids']});
      } catch (_) {
        if (mounted) context.toastInfo('Booked. Add your squad from the pass.');
      }
      if (mounted) context.go('/booking-confirmation/$bookingId');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mates.isEmpty) return const SizedBox.shrink();
    final r = _rebook;
    final start = r == null ? null : DateTime.tryParse('${r['start_time']}'.replaceFirst(' ', 'T'));
    final names = r == null ? <String>[] : List<String>.from((r['player_names'] as List?) ?? const []);
    final games = _mates.fold<int>(0, (sum, m) => sum + ((m['games'] as num?)?.toInt() ?? 0));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: KoCard(
        kicker: 'Your crew',
        title: r != null && start != null ? '${r['court_name']}' : '${_mates.length} people you play with',
        meta: r != null && start != null ? 'Usually ${slotDayLabel(start)} · ${crewWith(names)}' : 'From your last 6 months of games',
        badge: '×$games',
        middle: JerseyRow(names: [for (final m in _mates) '${m['name'] ?? ''}'], max: 6),
        actionLabel: r != null && start != null ? (_busy ? 'Booking…' : 'Rebook ${slotDayLabel(start)} · same squad') : null,
        onAction: r != null && start != null && !_busy ? () => _doRebook(r, start) : null,
      ),
    );
  }
}
