import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/bookings/booking_ticket.dart';

void main() {
  test('a verify response yields booking ids', () {
    expect(bookingIdsFromVerify({'booking_ids': [12, '13', 0, 'no']}), [12, 13]);
    expect(bookingIdsFromVerify({'message': 'ok'}), isEmpty);
  });

  test('a booking row becomes a ticket', () {
    final ticket = ticketFromBooking({
      'id': 12,
      'court_name': 'KO Arena',
      'court_location': 'Anna Nagar, Chennai',
      'space_name': 'Court 1',
      'start_time': '2026-11-07 18:00:00',
      'end_time': '2026-11-07 19:00:00',
      'total_price': '500.00',
      'status': 'confirmed',
    });
    expect(ticket.venue, 'KO Arena');
    expect(ticket.place, 'Anna Nagar, Chennai');
    expect(ticket.date, '7 Nov 2026');
    expect(ticket.time, '6:00 PM – 7:00 PM');
    expect(ticket.space, 'Court 1');
    expect(ticket.amount, '₹500.00');
    expect(ticket.id, 12);
  });
}
