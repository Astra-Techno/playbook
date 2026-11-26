import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:provider/provider.dart';

import '../../matches/matches_screen.dart';
import '../home_logic.dart';


/// Matchday card: your next booking with a live countdown; hidden when nothing is booked.
class NextGameCard extends StatefulWidget {
  const NextGameCard({super.key});

  @override
  State<NextGameCard> createState() => _NextGameCardState();
}

class _NextGameCardState extends State<NextGameCard> {
  Map<String, dynamic>? _next;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.userId == null) return;
    try {
      final res = await Api().get('/bookings', params: {'user_id': auth.userId});
      final rows = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      if (mounted) setState(() => _next = nextUpcomingBooking(rows, DateTime.now()));
    } catch (_) {
      // Optional tile; Home still works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final start = next == null ? null : DateTime.tryParse('${next['start_time']}');
    final end = next == null ? null : DateTime.tryParse('${next['end_time']}');
    final left = start?.difference(DateTime.now());
    if (next == null || start == null || left == null || left.isNegative) return const SizedBox.shrink();
    const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final minutes = end?.difference(start).inMinutes;
    final price = num.tryParse('${next['total_price'] ?? ''}');
    void open() => context.push('/booking-confirmation/${next['id']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KoCard(
        sport: next['court_type'],
        kicker: 'Your next game',
        title: '${next['court_name'] ?? 'Your game'}',
        meta: '${weekday[start.weekday - 1]} ${start.day} ${month[start.month - 1]}',
        badge: clockLabel('${start.hour}:${start.minute}'),
        stats: [
          KoStat(kickoffIn(left), 'to kick-off'),
          if (minutes != null && minutes > 0) KoStat('$minutes', 'minutes'),
          if (price != null && price > 0) KoStat('₹${price.round()}', 'paid'),
        ],
        actionLabel: 'Open pass',
        onAction: open,
        onTap: open,
      ),
    );
  }
}

/// Matchday card: open games that still need players; hidden when there are none.
class PlayersWantedTile extends StatefulWidget {
  const PlayersWantedTile({super.key});

  @override
  State<PlayersWantedTile> createState() => _PlayersWantedTileState();
}

class _PlayersWantedTileState extends State<PlayersWantedTile> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/match-requests');
      final rows = List<Map<String, dynamic>>.from(
        (res.data['requests'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      if (mounted) setState(() => _count = gamesNeedingPlayers(rows));
    } catch (_) {
      // Shows a dash when matches cannot be loaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (count == null || count == 0) return const SizedBox.shrink();
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesScreen()));
    return KoCard(
      kicker: 'Players wanted',
      title: count == 1 ? '1 open game needs players' : '$count open games need players',
      meta: 'Join a game near you',
      badge: '$count',
      actionLabel: 'See open games',
      secondaryAction: true,
      onAction: open,
      onTap: open,
    );
  }
}
