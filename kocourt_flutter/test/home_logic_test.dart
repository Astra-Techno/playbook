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
}
