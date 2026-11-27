import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('rupees drop stray decimals and use Indian grouping', () {
    expect(rupees('500.00'), '₹500');
    expect(rupees(1200), '₹1,200');
    expect(rupees('120000'), '₹1,20,000');
    expect(rupees('99.5'), '₹99.50');
    expect(rupees(null), '');
    expect(rupees('abc'), '');
  });

  test('friendly days', () {
    final now = DateTime(2026, 11, 27, 10);
    expect(friendlyDay(DateTime(2026, 11, 27), now: now), 'Today');
    expect(friendlyDay(DateTime(2026, 11, 28), now: now), 'Tomorrow');
    expect(friendlyDay(DateTime(2026, 11, 26), now: now), 'Yesterday');
    expect(friendlyDay(DateTime(2026, 12, 2), now: now), 'Wed 2 Dec');
    expect(friendlyDay(DateTime(2027, 1, 5), now: now), 'Tue 5 Jan 2027');
  });

  test('clocks and ranges', () {
    expect(clock('18:00:00'), '6 PM');
    expect(clock('2026-11-27 06:30:00'), '6:30 AM');
    expect(clock('00:00'), '12 AM');
    expect(clockRange('18:00:00', '19:00:00'), '6–7 PM');
    expect(clockRange('11:00', '13:00'), '11 AM–1 PM');
    expect(clockRange('18:30', '20:00'), '6:30–8 PM');
  });

  test('time ago', () {
    final now = DateTime(2026, 11, 27, 10);
    expect(timeAgo('2026-11-27 09:59:40', now: now), 'now');
    expect(timeAgo('2026-11-27 09:55:00', now: now), '5m');
    expect(timeAgo('2026-11-27 07:00:00', now: now), '3h');
    expect(timeAgo('2026-11-24 10:00:00', now: now), '3d');
    expect(timeAgo('2026-11-10 10:00:00', now: now), 'Tue 10 Nov');
    expect(timeAgo(null), '');
  });
}
