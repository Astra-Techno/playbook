import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/release_flags.dart';

void main() {
  test('optional venue tools can be hidden while bookings stay available', () {
    const off = ReleaseFlags(coaching: false, equipment: false);
    expect(off.shows('coaching'), isFalse);
    expect(off.shows('equipment'), isFalse);
    expect(off.shows('bookings'), isTrue);
    expect(off.shows('calendar'), isTrue);
    expect(releaseFlags.shows('coaching'), isTrue);
    expect(releaseFlags.shows('equipment'), isTrue);
  });
}
