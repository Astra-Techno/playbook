import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/notifications/notification_groups.dart';

void main() {
  test('groups per venue and day, keeps others single', () {
    final list = [
      {'id': 5, 'court_id': 9, 'court_name': 'Kick Arena', 'created_at': '2026-11-27 18:02:00'},
      {'id': 4, 'court_id': null, 'created_at': '2026-11-27 17:50:00'},
      {'id': 3, 'court_id': 9, 'court_name': 'Kick Arena', 'created_at': '2026-11-27 17:40:00'},
      {'id': 2, 'court_id': 9, 'court_name': 'Kick Arena', 'created_at': '2026-11-26 10:00:00'},
      {'id': 1, 'court_id': 7, 'court_name': 'Ace', 'created_at': '2026-11-27 09:00:00'},
    ];
    final groups = groupNotifications(list);
    expect(groups.map((g) => g.items.map((n) => n['id']).toList()), [
      [5, 3],
      [4],
      [2],
      [1],
    ]);
    expect(groups.first.courtName, 'Kick Arena');
    expect(groups.first.single, isFalse);
    expect(groups[1].single, isTrue);
  });

  test('day labels', () {
    final now = DateTime(2026, 11, 27, 20);
    expect(groupDayLabel('2026-11-27', now), 'Today');
    expect(groupDayLabel('2026-11-26', now), 'Yesterday');
    expect(groupDayLabel('2026-11-24', now), 'Tue 24 Nov');
    expect(groupDayLabel('', now), '');
  });
}
