import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:provider/provider.dart';

import '../home_logic.dart';

/// "Your next game" strip with a stopwatch ring counting down the last 24 hours.
/// Hidden when signed out or when nothing is booked ahead.
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
      // The card is optional; Home still works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final start = next == null ? null : DateTime.tryParse('${next['start_time']}');
    if (next == null || start == null) return const SizedBox.shrink();
    final left = start.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();

    final brand = context.brand.primary;
    final within24h = 1 - (left.inMinutes / (24 * 60)).clamp(0.0, 1.0);
    final where = [next['court_name'], next['space_name']]
        .where((v) => '${v ?? ''}'.trim().isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/booking-confirmation/${next['id']}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CustomPaint(
                    painter: StopwatchRingPainter(progress: within24h, color: brand),
                    child: Center(
                      child: Icon(Icons.timer_outlined, size: 18, color: brand),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR NEXT GAME · KICK-OFF IN ${kickoffIn(left).toUpperCase()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        where.isEmpty ? 'Your booking' : where,
                        style: GoogleFonts.archivo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Pass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brand)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
