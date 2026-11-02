import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/customer_fields.dart';

void main() {
  test('the customer list keeps visits and drops the phone', () {
    final rows = customerRows({
      'customers': [
        {'id': 8, 'name': 'Ada', 'phone': '9999900000', 'booking_count': 3, 'last_played': '2026-11-02 18:00:00'},
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.first.containsKey('phone'), isFalse);
    expect(customerLine(rows.first), '3 bookings · last 2026-11-02 18:00:00');
    expect(customerLine({'booking_count': 1, 'last_played': ''}), '1 booking');
    expect(customerRows({'players': []}), isEmpty);
  });
}
