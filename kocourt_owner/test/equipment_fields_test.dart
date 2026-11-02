import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/equipment_fields.dart';

void main() {
  test('an item keeps quantity and deposit and drops a phone number', () {
    final rows = equipmentRows({
      'items': [
        {
          'id': 4,
          'name': 'Racket',
          'quantity_on_hand': 10,
          'deposit_rupees': 200,
          'status': 'active',
          'out_quantity': 2,
          'rentals': [
            {'id': 8, 'display_name': 'Bo', 'quantity': 2, 'phone': '9999900000', 'deposit_status': 'held', 'state': 'out'},
          ],
        },
      ],
    });
    expect(rows, hasLength(1));
    expect(equipmentLine(rows.first), 'Active · 2 of 10 out · Deposit Rs 200');
    final rentals = rows.first['rentals'] as List;
    expect((rentals.first as Map).containsKey('phone'), isFalse);
    expect(equipmentBody(name: ' Racket ', quantity: '10', deposit: '200')?['deposit_rupees'], 200);
    expect(equipmentBody(name: 'Ball', quantity: '0', deposit: '0'), isNull);
    expect(rentalBody(' Bo ', '2'), {'display_name': 'Bo', 'quantity': 2});
    expect(returnBody('returned'), {'deposit_status': 'returned'});
    expect(returnBody('held'), isNull);
  });
}
