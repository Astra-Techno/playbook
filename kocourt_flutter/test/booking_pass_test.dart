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

  test('squad share and WhatsApp invite', () {
    expect(perHeadRupees('1200.00', 5), 240);
    expect(perHeadRupees(1000, 3), 334);
    expect(perHeadRupees(0, 4), isNull);
    expect(perHeadRupees('600', 0), isNull);
    const t = BookingTicket(id: 9, venue: 'Kick Arena', place: 'Anna Nagar', date: 'Wed, 2 Dec', time: '7:00 PM – 8:00 PM', space: 'Turf 2', amount: '₹1200', status: 'confirmed');
    final text = squadInviteText(t, players: 4, perHead: 300, courtId: 12, open: 1);
    expect(text, contains('Game on: Kick Arena (Turf 2)'));
    expect(text, contains('4 in, 1 spot open · ₹300 each'));
    expect(text, contains('https://www.kocourt.com/court/12'));
    expect(text, contains('query=Kick+Arena%2C+Anna+Nagar'));
    expect(squadInviteText(t, players: 1), isNot(contains('each')));
  });

  test('recap text', () {
    const t = BookingTicket(id: 9, venue: 'Kick Arena', place: '', date: 'Wed, 2 Dec', time: '7:00 PM – 8:00 PM', space: 'Turf 2', amount: '', status: 'confirmed');
    expect(recapText(t, players: 5, minutes: 60), 'Played at Kick Arena (Turf 2) · 60 min · squad of 5. Good game!');
    expect(recapText(t, players: 1), 'Played at Kick Arena (Turf 2). Good game!');
  });

  test('UPI pay-me link', () {
    expect(isUpiId('arjun@okaxis'), isTrue);
    expect(isUpiId('98765.43210@ybl'), isTrue);
    expect(isUpiId('arjun'), isFalse);
    expect(isUpiId('a@b'), isFalse);
    final link = upiPayLink('arjun@okaxis', payee: 'Arjun K', amount: 240)!;
    expect(link, startsWith('upi://pay?'));
    expect(link, contains('pa=arjun%40okaxis'));
    expect(link, contains('am=240'));
    expect(upiPayLink('bad', payee: 'A', amount: 240), isNull);
    expect(upiPayLink('arjun@okaxis', payee: 'A', amount: 0), isNull);
    const t = BookingTicket(id: 9, venue: 'Kick Arena', place: '', date: 'Wed, 2 Dec', time: '7 PM', space: '', amount: '', status: 'confirmed');
    expect(squadInviteText(t, players: 4, perHead: 240, payLink: link), contains('Pay me ₹240 on UPI: upi://pay?'));
  });
}
