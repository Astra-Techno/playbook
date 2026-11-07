import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/court_details/slot_block.dart';

void main() {
  test('a stored block covers the matching hour', () {
    expect(
      blockCoversSlot(
        appliesStart: '2026-10-31 18:00:00',
        appliesEnd: '2026-10-31 20:00:00',
        slotStart: '2026-10-31 19:00:00',
        slotEnd: '2026-10-31 20:00:00',
      ),
      isTrue,
    );
    expect(
      blockCoversSlot(
        appliesStart: '2026-10-31 18:00:00',
        appliesEnd: '2026-10-31 20:00:00',
        slotStart: '2026-10-31 20:00:00',
        slotEnd: '2026-10-31 21:00:00',
      ),
      isFalse,
    );
  });

  test('today hides hours that have already started', () {
    final now = DateTime(2026, 11, 7, 19, 12);
    expect(slotStartHasPassed('2026-11-07', 18, now), isTrue);
    expect(slotStartHasPassed('2026-11-07', 19, now), isTrue);
    expect(slotStartHasPassed('2026-11-07', 20, now), isFalse);
    expect(slotStartHasPassed('2026-11-08', 8, now), isFalse);
  });

  test('an annual window placed on this year covers that evening', () {
    expect(
      blockCoversSlot(
        appliesStart: '2026-10-31 22:00:00',
        appliesEnd: '2026-11-01 02:00:00',
        slotStart: '2026-10-31 23:00:00',
        slotEnd: '2026-11-01 00:00:00',
      ),
      isTrue,
    );
  });
}
