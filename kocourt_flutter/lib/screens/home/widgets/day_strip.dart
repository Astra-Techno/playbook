import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

import '../home_logic.dart';

/// Matchday availability strip: one bar per hour from 6 AM, from GET /courts/day-strip.
/// Free bars wear the sport colour, peak-price bars amber, taken bars are short
/// and grey, closed and past hours fade out. [highlightHour] gets a violet ring.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.strip, required this.tone, this.highlightHour, this.date, this.firstHour = 6});

  final String strip;
  final Color tone;
  final int? highlightHour;

  /// "YYYY-MM-DD"; hours already gone today fade out.
  final String? date;
  final int firstHour;

  static const _peak = Color(0xFFF59E0B);
  static const _taken = Color(0xFFD9D4E6);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final pastBefore = date == today ? now.hour + 1 : (date != null && date!.compareTo(today) < 0 ? 99 : 0);
    final free = [for (var i = 0; i < strip.length; i++) if ((strip[i] == 'f' || strip[i] == 'p') && firstHour + i >= pastBefore) firstHour + i];
    final summary = free.isEmpty ? 'No free hours' : 'Free at ${free.take(4).map(hourLabel).join(', ')}${free.length > 4 ? ' and more' : ''}';

    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < strip.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: _bar(strip[i], firstHour + i, pastBefore)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in [firstHour, 12, 18, firstHour + strip.length - 1])
                Text(hourLabel(h).replaceAll(' ', '').replaceAll('M', ''), style: AppFonts.score(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String state, int hour, int pastBefore) {
    final gone = hour < pastBefore || state == 'c';
    final color = switch (state) {
      'f' => tone,
      'p' => _peak,
      _ => _taken,
    };
    final short = state == 't' || state == 'c';
    return FractionallySizedBox(
      heightFactor: short ? 0.55 : 1,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gone ? color.withValues(alpha: 0.3) : color,
          borderRadius: BorderRadius.circular(2),
          border: hour == highlightHour ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
      ),
    );
  }
}
