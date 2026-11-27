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

  test('free label reads the free hour', () {
    expect(freeLabel({'free_from': '2026-11-25 19:00:00'}), 'Free 7 PM');
    expect(freeLabel({'id': 1}), 'Open now');
    expect(freeHour({'free_from': '2026-11-25 07:00:00'}), 7);
    expect(freeHour({'id': 1}), isNull);
  });

  test('time chips pick the right day and hour', () {
    final at = DateTime(2026, 11, 25, 16, 20);
    expect(playTarget(PlayTime.now, at), (date: '2026-11-25', hour: 17));
    expect(playTarget(PlayTime.tonight, at), (date: '2026-11-25', hour: 19));
    expect(playTarget(PlayTime.tonight, DateTime(2026, 11, 25, 20, 30)), (date: '2026-11-25', hour: 21));
    expect(playTarget(PlayTime.tomorrowMorning, DateTime(2026, 11, 30, 22)), (date: '2026-12-01', hour: 7));
  });

  test('day strip gives the next free hour and sorts venues by it', () {
    //            6 7 8 9 ...
    const strip = 'cttfttttttttttpft';
    expect(nextFreeHour(strip, 6), 9);
    expect(nextFreeHour(strip, 10), 20);
    expect(nextFreeHour(strip, 23), isNull);
    expect(nextFreeHour(null, 6), isNull);
    expect(hourLabel(20), '8 PM');
    expect(hourLabel(12), '12 PM');
    expect(hourLabel(0), '12 AM');
    final venues = [
      {'id': 1, 'name': 'Late'},
      {'id': 2, 'name': 'Early'},
      {'id': 3, 'name': 'Full'},
    ];
    final target = (date: '2026-11-25', hour: 8);
    expect(withStrips(venues, null, target), venues);
    final out = withStrips(venues, {'1': strip, '2': 'ftffffffffffffff', '3': 'ttttttttttttttttt'}, target);
    expect(out.map((v) => v['name']), ['Early', 'Late']);
    expect(out.first['free_from'], '2026-11-25 08:00:00');
    expect(freeLabel(out.last), 'Free 9 AM');
  });
}
