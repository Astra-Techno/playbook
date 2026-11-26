import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/bookings/booking_ticket.dart';

void main() {
  final start = DateTime(2026, 11, 26, 18);
  final end = DateTime(2026, 11, 26, 20);

  test('pass countdown before, during and after the game', () {
    expect(passCountdown(start, end, DateTime(2026, 11, 25, 15, 4)), 'Kick-off in 1d 2h');
    expect(passCountdown(start, end, DateTime(2026, 11, 26, 19, 26)), 'Live now · ends in 34m');
    expect(passCountdown(start, end, DateTime(2026, 11, 26, 21)), 'Full time');
    expect(passCountdown(null, end, DateTime(2026, 11, 26)), '');
  });
}
