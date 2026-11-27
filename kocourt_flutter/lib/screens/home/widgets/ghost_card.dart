import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// Matchday "Not on KoCourt yet" card: compact, swipeable, sport-tinted.
/// One tap registers interest so we can bring the place on board.
class GhostCard extends StatelessWidget {
  const GhostCard({super.key, required this.place, required this.onInterest});

  final Map<String, dynamic> place;
  final VoidCallback onInterest;

  @override
  Widget build(BuildContext context) {
    final type = place['type'];
    final tint = sportTint(type);
    final interested = int.tryParse('${place['request_count'] ?? 0}') ?? 0;
    final mine = place['user_requested'] == true;
    final rating = num.tryParse('${place['rating'] ?? ''}');
    return Container(
      width: 232,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint.bg, Colors.white], stops: const [0, 0.75]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: SportIcon(type, size: 22, tint: tint.bg, fallback: Icons.place_outlined),
              ),
              const Spacer(),
              if (rating != null && rating > 0)
                Row(children: [
                  const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: AppFonts.score(fontSize: 14, color: AppColors.textPrimary)),
                ]),
            ],
          ),
          const SizedBox(height: 10),
          Text('${place['name'] ?? 'Nearby place'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppFonts.display(fontSize: 15, height: 1.2)),
          const SizedBox(height: 2),
          Text(
            interested == 0 ? 'Be the first to ask for it' : '$interested ${interested == 1 ? 'person wants' : 'people want'} it on KoCourt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: mine ? null : onInterest,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                side: BorderSide(color: mine ? AppColors.border : AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
              ),
              child: Text(mine ? "You're on the list ✓" : "I'm interested", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
