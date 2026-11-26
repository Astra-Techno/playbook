import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/scan_check_in_screen.dart';

void main() {
  test('typed booking number and code become the pass payload', () {
    expect(manualCheckInPayload('#42', 'abcd 2345'), 'KOCOURT-CHECKIN:42:ABCD2345');
    expect(manualCheckInPayload('42', 'ABCD234'), isNull);
    expect(manualCheckInPayload('42', 'ABCD234O'), isNull);
    expect(manualCheckInPayload('x', 'ABCD2345'), isNull);
    expect(manualCheckInPayload('0', 'ABCD2345'), isNull);
  });

  test('scan result time range', () {
    expect(checkInTimeRange('2026-11-25 14:00:00', '2026-11-25 15:00:00'), '2 – 3 PM');
    expect(checkInTimeRange('2026-11-25 11:30:00', '2026-11-25 13:00:00'), '11:30 AM – 1 PM');
    expect(checkInTimeRange(null, null), '');
  });
}
