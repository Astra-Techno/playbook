import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/walk_in_fields.dart';

void main() {
  test('walk-in body is a full datetime and a guest name', () {
    expect(
      walkInBody(
        courtId: 4,
        date: '2026-10-31',
        startHour: 18,
        guestName: ' Asha ',
        guestPhone: '9000000000',
        spaceId: 8,
        spaceRequired: true,
      ),
      {
        'court_id': 4,
        'sub_court_id': 8,
        'start_time': '2026-10-31 18:00:00',
        'end_time': '2026-10-31 19:00:00',
        'guest_name': 'Asha',
        'guest_phone': '9000000000',
        'type': 'hourly',
      },
    );
  });

  test('the last hour ends at midnight', () {
    final body = walkInBody(
      courtId: 4,
      date: '2026-10-31',
      startHour: 23,
      guestName: 'Asha',
    );
    expect(body['end_time'], '2026-11-01 00:00:00');
    expect(body.containsKey('user_id'), isFalse);
    expect(body.containsKey('date'), isFalse);
  });

  test('a venue with spaces requires one', () {
    expect(
      () => walkInBody(
        courtId: 4,
        date: '2026-10-31',
        startHour: 9,
        guestName: 'Asha',
        spaceRequired: true,
      ),
      throwsA(isA<WalkInFieldError>()),
    );
  });

  test('busy days come from busy_days', () {
    expect(busyDayNumbers({'busy_days': [1, '4', 0]}), {1, 4});
    expect(busyDayNumbers({'days': [3]}), isEmpty);
  });

  test('a move keeps the stored price off the payload', () {
    expect(
      rescheduleBody(date: '2026-11-02', startHour: 9),
      {'start_time': '2026-11-02 09:00:00', 'end_time': '2026-11-02 10:00:00'},
    );
  });

  test('week occupancy counts a start date and a yearly closure', () {
    expect(
      rowsOnDate([
        {'start_time': '2026-11-02 09:00:00'},
        {'start_time': '2026-11-02 18:00:00'},
      ], '2026-11-02'),
      2,
    );
    expect(
      rowsOnDate([
        {'start_time': '2020-11-03 18:00:00', 'repeat_annually': 1},
      ], '2026-11-03', annual: true),
      1,
    );
  });

  test('a walk-in shows the guest name', () {
    expect(bookingPerson({'guest_name': 'Asha', 'user_name': ''}), 'Asha');
    expect(bookingPerson({'user_name': 'Ravi'}), 'Ravi');
  });
}
