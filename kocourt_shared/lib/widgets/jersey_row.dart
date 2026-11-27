import 'package:flutter/material.dart';

import '../core/fonts.dart';
import '../core/theme.dart';

/// "AK" for "Arjun Kumar", "R" for "Ravi", "?" for blank.
String jerseyInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first.toUpperCase();
  return parts.length == 1 ? first : first + parts.last.characters.first.toUpperCase();
}

/// Matchday squad row: each player as a jersey plate with initials, open
/// spots as dashed plates, and an optional note ("₹240 each · 1 spot open").
class JerseyRow extends StatelessWidget {
  const JerseyRow({super.key, required this.names, this.open = 0, this.tone, this.note, this.max = 6});

  final List<String> names;
  final int open;
  final Color? tone;
  final String? note;

  /// Plates shown before "+n".
  final int max;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.brand.primary;
    final shownNames = names.take(max).toList();
    final shownOpen = (max - shownNames.length).clamp(0, open);
    final hidden = names.length - shownNames.length + (open - shownOpen);
    Widget plate(Widget child, {bool dashed = false}) => Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: dashed ? AppColors.textDisabled : AppColors.border, width: dashed ? 1.5 : 1),
          ),
          child: child,
        );
    return Semantics(
      label: '${names.length} in the squad${open > 0 ? ', $open open' : ''}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final n in shownNames) plate(Text(jerseyInitials(n), style: AppFonts.score(fontSize: 14, color: color))),
          for (var i = 0; i < shownOpen; i++) plate(const Icon(Icons.add, size: 16, color: AppColors.textMuted), dashed: true),
          if (hidden > 0) plate(Text('+$hidden', style: AppFonts.score(fontSize: 13, color: AppColors.textSecondary))),
          if (note != null) Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(note!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
