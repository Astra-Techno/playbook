import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:provider/provider.dart';

import '../../matches/matches_screen.dart';
import '../home_logic.dart';

const _tileHeight = 118.0;

/// v5 bento tile: your next booking with a countdown ring, or a nudge to book.
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
    final left = start?.difference(DateTime.now());
    final has = next != null && start != null && left != null && !left.isNegative;
    final tint = sportTint(next?['court_type'] ?? 'cricket');
    final weekday = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _BentoTile(
      color: tint.bg,
      onTap: has ? () => context.push('/booking-confirmation/${next['id']}') : null,
      children: [
        Row(
          children: [
            Expanded(child: Text('NEXT GAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tint.fg))),
            if (has)
              SizedBox(
                width: 30,
                height: 30,
                child: CustomPaint(
                  painter: StopwatchRingPainter(
                    progress: 1 - (left.inMinutes / (24 * 60)).clamp(0.0, 1.0),
                    color: tint.fg,
                    track: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        Text(
          has ? '${weekday[start.weekday - 1]} · ${clockLabel('${start.hour}:${start.minute}')}' : 'Nothing booked',
          style: GoogleFonts.archivo(fontSize: 19, fontWeight: FontWeight.w900, height: 1.05),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          has ? '${next['court_name'] ?? 'Your game'} · in ${kickoffIn(left)}' : 'Pick a court below',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// v5 bento tile: how many open games still need players.
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
    const amber = Color(0xFFB45309);
    return _BentoTile(
      color: const Color(0xFFFFF4E5),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesScreen())),
      children: [
        const Text('PLAYERS WANTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: amber)),
        const Spacer(),
        Text(_count == null ? '—' : '$_count', style: GoogleFonts.archivo(fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 4),
        Text(
          _count == 1 ? 'game needs players' : 'games need players',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.color, required this.children, this.onTap});
  final Color color;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          height: _tileHeight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ),
    );
  }
}
