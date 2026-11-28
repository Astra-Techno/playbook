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

  test('membership passes go to the members endpoint', () {
    expect(checkInEndpoint('KOCOURT-MEMBER:12:ABCD2345'), '/subscriptions/check-in-scan');
    expect(checkInEndpoint(' KOCOURT-MEMBER:12:ABCD2345 '), '/subscriptions/check-in-scan');
    expect(checkInEndpoint('KOCOURT-CHECKIN:7:ABCD2345'), '/bookings/check-in-scan');
    expect(checkInEndpoint('anything else'), '/bookings/check-in-scan');
  });

  test('member line shows plan, days left and visits', () {
    expect(memberScanLine({'plan': 'Monthly', 'days_left': 18, 'visits_this_month': 12}), 'Monthly · 18 days left · 12 visits this month');
    expect(memberScanLine({'plan': 'Monthly', 'days_left': 1, 'visits_this_month': 1}), 'Monthly · 1 day left · 1 visit this month');
    expect(memberScanLine({'plan': 'Monthly', 'days_left': 0}), 'Monthly');
  });
}
