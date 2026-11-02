import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/booking_price_export.dart';

void main() {
  test('export asks for one venue and optional days', () {
    final open = bookingPriceExport(courtId: 12);
    expect(open!.query, {'court_id': 12});

    final ranged = bookingPriceExport(courtId: 12, from: '2026-11-01', to: '2026-11-30');
    expect(ranged!.query, {'court_id': 12, 'from': '2026-11-01', 'to': '2026-11-30'});
  });

  test('a reversed or unusable range is refused', () {
    expect(bookingPriceExport(courtId: 0), isNull);
    expect(bookingPriceExport(courtId: 4, from: '11/01/2026'), isNull);
    expect(bookingPriceExport(courtId: 4, from: '2026-11-30', to: '2026-11-01'), isNull);
  });

  test('only the booking-price header counts as an export', () {
    expect(
      bookingPriceCsv('Date,Space,Player,Start,End,Hours,Amount (Rs)\n2026-11-02,Court 1,Ada,18:00:00,19:00:00,1,500'),
      isTrue,
    );
    expect(bookingPriceCsv('Date,Space,Player,Start,End,Hours,Amount (Rs)\n'), isTrue);
    expect(bookingPriceCsv('{"message":"Forbidden"}'), isFalse);
    expect(bookingPriceCsv('Date,Amount\n'), isFalse);
  });
}
