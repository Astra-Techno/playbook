import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/attendance_fields.dart';

void main() {
  test('arrival labels stay off the booking status', () {
    expect(attendanceLabel('checked_in'), 'Checked in');
    expect(attendanceLabel('no_show'), 'No-show');
    expect(attendanceLabel(null), isNull);
    expect(attendanceLabel('confirmed'), isNull);
  });

  test('only an unmarked confirmed booking can be marked from the screen', () {
    expect(attendanceUnmarked({'status': 'confirmed', 'attendance': null}), isTrue);
    expect(attendanceUnmarked({'status': 'confirmed', 'attendance': 'checked_in'}), isFalse);
    expect(attendanceUnmarked({'status': 'cancelled'}), isFalse);
  });
}
