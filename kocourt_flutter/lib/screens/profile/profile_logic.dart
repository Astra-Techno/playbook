import 'package:kocourt_shared/kocourt_shared.dart';

/// Player card tiles from GET /players/stats: hours this season, show-up rate
/// (games played until a venue has marked one), squad mates. Empty before the first game.
List<KoStat> playerCardStats(Map<String, dynamic>? stats) {
  if (stats == null) return const [];
  final games = (stats['games'] as num?)?.toInt() ?? 0;
  if (games == 0) return const [];
  final hours = (stats['hours'] as num?)?.toDouble() ?? 0;
  final rate = (stats['show_up_rate'] as num?)?.toInt();
  final mates = (stats['squad_mates'] as num?)?.toInt() ?? 0;
  return [
    KoStat(hours == hours.roundToDouble() ? '${hours.round()}' : hours.toStringAsFixed(1), 'hours this season'),
    rate == null ? KoStat('$games', games == 1 ? 'game played' : 'games played') : KoStat('$rate%', 'show-up rate'),
    KoStat('$mates', mates == 1 ? 'squad mate' : 'squad mates'),
  ];
}
