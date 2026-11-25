import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

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
  const StatusTag(this.label, {super.key, this.tone = TagTone.brand});
  final String label;
  final TagTone tone;

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
    final (bg, fg) = switch (tone) {
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
  const TimePlate({super.key, required this.top, this.bottom = '', this.filled = true, this.width = 62});
  final String top;
  final String bottom;
  final bool filled;
  final double width;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    return Slanted(
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? brand : brand.withValues(alpha: 0.1),
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
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: filled ? const Color(0xFFE5DAFF) : brand)),
            ],
          ],
        ),
      ),
    );
  }
}
