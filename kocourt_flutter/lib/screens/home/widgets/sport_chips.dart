import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// Sport filter pills with the sport's icon; the selected one fills with the brand colour.
class SportChips extends StatelessWidget {
  const SportChips({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    return Consumer<VenueProvider>(
      builder: (context, venues, _) {
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: sportCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = sportCategories[index];
                final selected = venues.selectedSport == cat.id;
                final fg = selected ? Colors.white : AppColors.textPrimary;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      venues.setSport(cat.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                      decoration: BoxDecoration(
                        color: selected ? brand : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: selected ? brand : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 17, color: fg),
                          const SizedBox(width: 6),
                          Text(cat.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
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
