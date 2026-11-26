import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// v5: every sport has its own light tint (bg) and readable ink (fg).
/// Tiles, tags, time plates and the pass header follow the venue's sport.
class SportTint {
  const SportTint(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

SportTint sportTint(Object? type) => switch ('${type ?? ''}'.trim().toLowerCase()) {
      'turf' || 'football' => const SportTint(Color(0xFFE7F8F0), Color(0xFF047857)),
      'cricket' => const SportTint(Color(0xFFF3EEFF), Color(0xFF5521B5)),
      'shuttle' || 'badminton' => const SportTint(Color(0xFFFFF4E5), Color(0xFFB45309)),
      'tennis' => const SportTint(Color(0xFFE8F0FE), Color(0xFF1D4ED8)),
      'swimming' => const SportTint(Color(0xFFE0F2FE), Color(0xFF0369A1)),
      'basket' || 'basketball' => const SportTint(Color(0xFFFFEDE5), Color(0xFFC2410C)),
      'boxing' => const SportTint(Color(0xFFFEECEC), Color(0xFFB91C1C)),
      'gym' => const SportTint(Color(0xFFF1F2F6), Color(0xFF374151)),
      _ => const SportTint(Color(0xFFF3EEFF), Color(0xFF5521B5)),
    };

/// "Football" for "turf"; empty when the type is unknown or blank.
String sportLabel(Object? type) {
  final id = '${type ?? ''}'.trim();
  for (final c in sportCategories) {
    if (c.id == id && c.id != 'All') return c.label;
  }
  return id.isEmpty ? '' : id[0].toUpperCase() + id.substring(1);
}

/// Leans a widget like a jersey number plate (v4 sports touch).
class Slanted extends StatelessWidget {
  const Slanted({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Transform(transform: Matrix4.skewX(-0.17), alignment: Alignment.center, child: child);
}

enum TagTone { brand, free, ending, due, muted }

/// Slanted status tag: In play, Free, Ending, Due, Cancelled…
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.tone = TagTone.brand, this.tint});
  final String label;
  final TagTone tone;

  /// Overrides [tone] with a sport's colours.
  final SportTint? tint;

  /// Slanted "CRICKET" tag in the sport's colours; nothing when the type is unknown.
  static Widget sport(Object? type) {
    final label = sportLabel(type);
    if (label.isEmpty) return const SizedBox.shrink();
    return StatusTag(label.toUpperCase(), tint: sportTint(type));
  }

  /// Booking status → tag, shared by both apps' booking lists.
  factory StatusTag.forBooking(String status, {Key? key}) {
    final s = status.toLowerCase();
    final tone = switch (s) {
      'confirmed' || 'paid' || 'checked_in' => TagTone.free,
      'pending' || 'pay_at_venue' => TagTone.ending,
      'cancelled' || 'failed' || 'no_show' => TagTone.due,
      _ => TagTone.muted,
    };
    final text = s.isEmpty ? 'Unknown' : (s[0].toUpperCase() + s.substring(1)).replaceAll('_', ' ');
    return StatusTag(text, key: key, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tint != null ? (tint!.bg, tint!.fg) : switch (tone) {
      TagTone.brand => (context.brand.primary.withValues(alpha: 0.1), context.brand.primaryDark),
      TagTone.free => (const Color(0xFFE7F8F0), const Color(0xFF047857)),
      TagTone.ending => (const Color(0xFFFFF4E5), const Color(0xFFB45309)),
      TagTone.due => (const Color(0xFFFEECEC), const Color(0xFFB91C1C)),
      TagTone.muted => (AppColors.surfaceDim, AppColors.textSecondary),
    };
    return Slanted(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}

/// Slanted kick-off plate: big time on top, small line under (date or AM/PM).
class TimePlate extends StatelessWidget {
  const TimePlate({super.key, required this.top, this.bottom = '', this.filled = true, this.width = 62, this.tint});
  final String top;
  final String bottom;
  final bool filled;
  final double width;

  /// Sport colours: soft plates use the tint, filled ones its ink.
  final SportTint? tint;

  @override
  Widget build(BuildContext context) {
    final brand = tint?.fg ?? context.brand.primary;
    return Slanted(
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? brand : (tint?.bg ?? brand.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top,
                style: GoogleFonts.archivo(fontSize: 17, fontWeight: FontWeight.w900, height: 1, color: filled ? Colors.white : brand)),
            if (bottom.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(bottom,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: filled ? (tint == null ? const Color(0xFFE5DAFF) : Colors.white.withValues(alpha: 0.85)) : brand)),
            ],
          ],
        ),
      ),
    );
  }
}
