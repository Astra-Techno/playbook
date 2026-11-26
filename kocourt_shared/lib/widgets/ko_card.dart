import 'package:flutter/material.dart';

import '../core/fonts.dart';
import '../core/theme.dart';
import 'sport_icon.dart';
import 'sport_tags.dart';

/// One number tile on a [KoCard]: "38" over "hours this season".
class KoStat {
  const KoStat(this.value, this.label);
  final String value;
  final String label;
}

/// Matchday card: the same five parts on every page.
///  1. ground tinted by [sport] (violet when null: you, your squad)
///  2. [kicker] (with the sport icon), [title], [meta]
///  3. one [badge] chip with the key fact (time, price, level)
///  4. up to three [stats], or a custom [middle]
///  5. one [actionLabel] button
class KoCard extends StatelessWidget {
  const KoCard({
    super.key,
    required this.title,
    this.sport,
    this.kicker,
    this.meta,
    this.badge,
    this.badgeWidget,
    this.stats = const [],
    this.middle,
    this.actionLabel,
    this.onAction,
    this.secondaryAction = false,
    this.onTap,
    this.onLongPress,
  });

  final Object? sport;
  final String? kicker;
  final String title;
  final String? meta;
  final String? badge;

  /// Replaces [badge], e.g. a QR code on the pass.
  final Widget? badgeWidget;
  final List<KoStat> stats;
  final Widget? middle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Outlined action for a quieter card (Manage, Cheer).
  final bool secondaryAction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final hasSport = sport != null && '$sport'.trim().isNotEmpty && sportIconKey(sport) != null;
    final tint = hasSport ? sportTint(sport).bg : Color.alphaBlend(brand.primary.withValues(alpha: 0.09), Colors.white);
    final tone = hasSport ? sportTint(sport).fg : brand.primary;

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null) ...[
                      Row(children: [
                        if (hasSport) ...[SportIcon(sport, size: 16, tint: Colors.white), const SizedBox(width: 6)],
                        Flexible(
                          child: Text(
                            kicker!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.score(fontSize: 12, letterSpacing: 1.2, color: tone),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                    ],
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppFonts.display(fontSize: 20, height: 1.15, color: AppColors.textPrimary)),
                    if (meta != null && meta!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (badgeWidget != null || badge != null) ...[
                const SizedBox(width: 10),
                badgeWidget ??
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text(badge!, style: AppFonts.score(fontSize: 19, height: 1, color: tone)),
                    ),
              ],
            ],
          ),
          if (middle != null) ...[const SizedBox(height: 12), middle!],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < stats.length && i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _StatTile(stats[i])),
              ],
            ]),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: secondaryAction
                  ? OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(actionLabel!, style: TextStyle(color: brand.primary)),
                    )
                  : FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(actionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, Colors.white], stops: const [0, 0.7]),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, onLongPress: onLongPress, child: body),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.stat);
  final KoStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(stat.value, maxLines: 1, style: AppFonts.score(fontSize: 24, height: 1, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 3),
          Text(stat.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, height: 1.25, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
