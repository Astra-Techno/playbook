import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/alert_fields.dart';

void main() {
  test('an arrival alert keeps the message and drops a phone number', () {
    final rows = notificationRows({
      'notifications': [
        {
          'id': 5,
          'type': 'venue_alert',
          'title': 'Arrival due',
          'body': 'Ada is due at 09:30.',
          'phone': '9999900000',
          'court_name': 'Arena',
          'is_read': 0,
          'read_at': null,
          'created_at': '2026-12-01 09:00:00',
        },
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.first.containsKey('phone'), isFalse);
    expect(alertLine(rows.first), 'Arrival due · Ada is due at 09:30.');
  });
}
