import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/court_details/addons_sheet.dart';

void main() {
  test('add-on payload drops zero counts and totals the rent', () {
    final addons = [
      {'id': 1, 'name': 'Bat', 'rental_rupees': 50},
      {'id': 2, 'name': 'Bibs', 'rental_rupees': 20},
    ];
    final counts = {1: 2, 2: 0};
    expect(addonsPayload(counts), [
      {'item_id': 1, 'quantity': 2},
    ]);
    expect(addonsTotal(addons, counts), 100);
    expect(addonsPayload({}), isEmpty);
  });
}
