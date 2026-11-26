import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/register_logic.dart';

Map<String, dynamic> booking(String start, String end, {int? space, String? method, String pay = 'pending', String? attendance, String status = 'confirmed', num price = 300, String? user}) => {
      'start_time': '2026-11-25 $start:00',
      'end_time': '2026-11-25 $end:00',
      'sub_court_id': space,
      'collection_method': method,
      'payment_status': pay,
      'attendance': attendance,
      'status': status,
      'total_price': '$price',
      'user_name': user,
      'guest_name': 'Walk-in Player',
    };

void main() {
  final now = DateTime(2026, 11, 25, 15, 4);

  test('till splits money by how it was taken', () {
    final till = tillTotals([
      booking('14:00', '15:00', method: 'cash'),
      booking('15:00', '16:00', method: 'external_upi', price: 400),
      booking('16:00', '17:00', pay: 'paid', price: 500),
      booking('17:00', '18:00', method: 'pay_at_venue', price: 350),
      booking('18:00', '19:00', method: 'pay_at_venue', pay: 'paid', price: 100),
      booking('19:00', '20:00', pay: 'paid', status: 'cancelled', price: 900),
    ]);
    expect([till.cash, till.upi, till.online, till.toCollect], [400, 400, 500, 350]);
  });

  test('court tile: in play, ending, collect, free, closed', () {
    final inPlay = courtTile(bookings: [booking('15:00', '16:00', space: 1, pay: 'paid', user: 'Mano')], blocks: const [], spaceId: 1, now: now);
    expect(inPlay.kind, TileKind.inPlay);
    expect(inPlay.title, 'Mano');
    expect(inPlay.clock, '56m');

    final ending = courtTile(bookings: [booking('14:00', '15:10', space: 1, pay: 'paid'), booking('15:10', '16:00', space: 1, user: 'HAP')], blocks: const [], spaceId: 1, now: now);
    expect(ending.kind, TileKind.ending);
    expect(ending.subtitle, 'Next at 3:10 PM');

    final collect = courtTile(bookings: [booking('14:30', '15:30', space: 1, method: 'pay_at_venue')], blocks: const [], spaceId: 1, now: now);
    expect(collect.kind, TileKind.collect);

    final free = courtTile(bookings: [booking('17:00', '18:00', space: 1), booking('15:00', '16:00', space: 2)], blocks: const [], spaceId: 1, now: now);
    expect(free.kind, TileKind.free);
    expect(free.subtitle, 'Free till 5 PM');

    final closed = courtTile(bookings: const [], blocks: [{'start_time': '2026-11-25 15:00:00', 'end_time': '2026-11-25 17:00:00', 'reason': 'Maintenance', 'sub_court_id': null}], spaceId: 1, now: now);
    expect(closed.kind, TileKind.closed);
    expect(closed.subtitle, 'Maintenance · till 5 PM');
  });

  test('arriving next skips marked, cancelled and finished bookings', () {
    final rows = arrivingNext([
      booking('17:00', '18:00'),
      booking('14:00', '15:00'),
      booking('15:00', '16:00', attendance: 'checked_in'),
      booking('16:00', '17:00', status: 'cancelled'),
      booking('15:30', '16:30'),
    ], now);
    expect(rows.map((r) => r['start_time']), ['2026-11-25 15:30:00', '2026-11-25 17:00:00']);
    expect(checkInOpen(rows.first, now), isTrue, reason: '3:30 PM opens at 3 PM');
    expect(checkInOpen(rows.last, now), isFalse, reason: '5 PM opens at 4:30 PM');
  });
}
