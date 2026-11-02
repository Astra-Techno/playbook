import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/report_figures.dart';

void main() {
  test('a venue report keeps booking prices apart from collected money', () {
    final report = venueReport({
      'from': '2026-10-04',
      'to': '2026-11-02',
      'report': {
        'booking_gross': 190,
        'collected': 120.5,
        'confirmed_count': 3,
        'cancelled_count': 1,
        'cancel_rate': 25,
        'unique_players': 1,
        'repeat_players': 1,
        'paid_out': 999,
      },
    });
    expect(report, isNotNull);
    expect(report!.bookingGross, 190);
    expect(report.collected, 120.5);
    expect(report.cancelRate, 25);
    expect(report.repeatPlayers, 1);
    expect(reportMoney(report.collected), 'Rs 120.50');
    expect(venueReport({'summary': {'total': 190}}), isNull);
  });
}
