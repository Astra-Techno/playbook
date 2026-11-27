import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

import '../home_logic.dart';

/// "When are you playing?" chips. The choice lives in [playTimeChoice], so
/// every screen showing these chips agrees.
class PlayTimeChips extends StatelessWidget {
  const PlayTimeChips({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    return ValueListenableBuilder<PlayTime>(
      valueListenable: playTimeChoice,
      builder: (context, choice, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in PlayTime.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(playTimeLabel(t)),
                  selected: choice == t,
                  showCheckmark: false,
                  selectedColor: brand,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: choice == t ? brand : AppColors.border),
                  shape: const StadiumBorder(),
                  labelStyle: AppFonts.body(fontSize: 14, fontWeight: FontWeight.w700, color: choice == t ? Colors.white : AppColors.textPrimary),
                  onSelected: (_) => playTimeChoice.value = t,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
