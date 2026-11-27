import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/profile/profile_logic.dart';

void main() {
  test('player card stats', () {
    final full = playerCardStats({'hours': 38.0, 'games': 30, 'show_up_rate': 96, 'squad_mates': 12});
    expect(full.map((s) => '${s.value} ${s.label}'), ['38 hours this season', '96% show-up rate', '12 squad mates']);
    final early = playerCardStats({'hours': 4.5, 'games': 3, 'show_up_rate': null, 'squad_mates': 1});
    expect(early.map((s) => s.value), ['4.5', '3', '1']);
    expect(early[1].label, 'games played');
    expect(early[2].label, 'squad mate');
    expect(playerCardStats({'games': 0}), isEmpty);
    expect(playerCardStats(null), isEmpty);
  });
}
