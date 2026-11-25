import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/home/home_logic.dart';

void main() {
  final now = DateTime(2026, 11, 25, 15, 4);

  test('next game is the earliest confirmed booking still ahead', () {
    final rows = [
      {'id': 1, 'status': 'confirmed', 'start_time': '2026-11-25 14:00:00'},
      {'id': 2, 'status': 'cancelled', 'start_time': '2026-11-25 16:00:00'},
      {'id': 3, 'status': 'confirmed', 'start_time': '2026-11-27 18:00:00'},
      {'id': 4, 'status': 'confirmed', 'start_time': '2026-11-26 18:00:00'},
    ];
    expect(nextUpcomingBooking(rows, now)?['id'], 4);
    expect(nextUpcomingBooking(const [], now), isNull);
  });

  test('kick-off countdown text', () {
    expect(kickoffIn(const Duration(days: 1, hours: 2, minutes: 56)), '1d 2h');
    expect(kickoffIn(const Duration(hours: 2, minutes: 14)), '2h 14m');
    expect(kickoffIn(const Duration(minutes: 9)), '9m');
  });

  test('open now, including venues that close after midnight', () {
    expect(isOpenNow({'open_time': '06:00:00', 'close_time': '22:00:00'}, now), isTrue);
    expect(isOpenNow({'open_time': '06:00:00', 'close_time': '14:00:00'}, now), isFalse);
    expect(isOpenNow({'open_time': '18:00:00', 'close_time': '02:00:00'}, DateTime(2026, 11, 25, 1)), isTrue);
    expect(clockLabel('22:00:00'), '10 PM');
    expect(clockLabel('06:30:00'), '6:30 AM');
  });

  test('games needing players counts only open spots', () {
    expect(gamesNeedingPlayers([
      {'slots_needed': 2, 'participants': [{}, {}]},
      {'slots_needed': 1, 'participants': [{}, {}]},
      {'players_needed': 3, 'joined_count': 1},
    ]), 2);
    expect(gamesNeedingPlayers(const []), 0);
  });

  test('free right now uses the next full hour and real free slots', () {
    expect(nextFullHourSql(DateTime(2026, 11, 25, 19, 20)), '2026-11-25 20:00:00');
    expect(nextFullHourSql(DateTime(2026, 11, 25, 19)), '2026-11-25 19:00:00');
    expect(nextFullHourSql(DateTime(2026, 11, 25, 23, 5)), '2026-11-26 00:00:00');
    final open = [
      {'id': 1, 'name': 'A'},
      {'id': 2, 'name': 'B'},
    ];
    expect(withFreeFrom(open, null), open);
    final free = withFreeFrom(open, {'2': '2026-11-25 19:00:00'});
    expect(free.map((v) => v['name']), ['B']);
    expect(freeLabel(free.single), 'Free 7 PM');
    expect(freeLabel(open.first), 'Open now');
  });
}
