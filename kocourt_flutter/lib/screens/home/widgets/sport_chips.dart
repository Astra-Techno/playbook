import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// v5 sport tiles: each sport in its own tint; the selected one fills with its ink.
class SportChips extends StatelessWidget {
  const SportChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VenueProvider>(
      builder: (context, venues, _) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: sportCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = sportCategories[index];
                final selected = venues.selectedSport == cat.id;
                final tint = cat.id == 'All'
                    ? SportTint(context.brand.primary.withValues(alpha: 0.1), context.brand.primary)
                    : sportTint(cat.id);
                final fg = selected ? Colors.white : tint.fg;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: cat.label,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      venues.setSport(cat.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 84,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected ? tint.fg : tint.bg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Matchday icon: white fill on the tint, sport fill when selected.
                          SportIcon(cat.id, size: 24, tone: fg, tint: selected ? tint.fg : Colors.white, fallback: cat.icon),
                          Text(cat.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
