import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/coaching_fields.dart';

void main() {
  test('a class keeps the instructor and drops a phone number', () {
    final rows = coachingRows({
      'sessions': [
        {
          'id': 3,
          'title': 'Morning drills',
          'instructor_name': 'Ada',
          'capacity': 2,
          'start_time': '2026-12-01 06:00:00',
          'end_time': '2026-12-01 07:00:00',
          'status': 'scheduled',
          'enrollments': [
            {'id': 1, 'display_name': 'Bo', 'phone': '9999900000', 'attendance': null, 'state': 'enrolled'},
          ],
        },
      ],
    });
    expect(rows, hasLength(1));
    expect(coachingLine(rows.first), 'Scheduled · Ada · 1 of 2 · 2026-12-01 06:00:00');
    final players = rows.first['enrollments'] as List;
    expect((players.first as Map).containsKey('phone'), isFalse);
    expect(
      coachingBody(
        title: ' Morning drills ',
        instructor: 'Ada',
        capacity: '2',
        start: '2026-12-01 06:00:00',
        end: '2026-12-01 07:00:00',
      )?['capacity'],
      2,
    );
    expect(coachingBody(title: 'Drills', instructor: 'Ada', capacity: '0', start: '2026-12-01 06:00:00', end: '2026-12-01 07:00:00'), isNull);
    expect(enrollmentBody(' Bo '), {'display_name': 'Bo'});
    expect(attendanceBody('present'), {'attendance': 'present'});
    expect(attendanceBody('late'), isNull);
  });
}
