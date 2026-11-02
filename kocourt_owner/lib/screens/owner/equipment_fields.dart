/// A venue equipment rental. Quantity and deposit stay off bookings and payments.
List<Map<String, dynamic>> equipmentRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['items'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'name': row['name'],
          'quantity_on_hand': row['quantity_on_hand'],
          'deposit_rupees': row['deposit_rupees'],
          'status': row['status'],
          'out_quantity': row['out_quantity'],
          'rentals': [
            for (final rental in (row['rentals'] is List ? row['rentals'] as List : const []))
              if (rental is Map)
                {
                  'id': rental['id'],
                  'display_name': rental['display_name'],
                  'quantity': rental['quantity'],
                  'deposit_status': rental['deposit_status'],
                  'state': rental['state'],
                },
          ],
        },
  ];
}

Map<String, dynamic>? equipmentBody({
  required String name,
  required String quantity,
  required String deposit,
}) {
  final item = name.trim();
  final stock = int.tryParse(quantity.trim());
  final rupees = int.tryParse(deposit.trim());
  if (item.isEmpty || item.length > 80) return null;
  if (stock == null || stock < 1 || stock > 200) return null;
  if (rupees == null || rupees < 0 || rupees > 50000) return null;
  return {
    'name': item,
    'quantity_on_hand': stock,
    'deposit_rupees': rupees,
  };
}

Map<String, dynamic>? rentalBody(String name, String quantity) {
  final player = name.trim();
  final count = int.tryParse(quantity.trim());
  if (player.isEmpty || player.length > 80) return null;
  if (count == null || count < 1) return null;
  return {'display_name': player, 'quantity': count};
}

Map<String, String>? returnBody(String depositStatus) {
  if (depositStatus != 'returned' && depositStatus != 'kept') return null;
  return {'deposit_status': depositStatus};
}

String equipmentLine(Map<String, dynamic> row) {
  final stock = int.tryParse('${row['quantity_on_hand']}') ?? 0;
  final out = int.tryParse('${row['out_quantity']}') ?? 0;
  final deposit = int.tryParse('${row['deposit_rupees']}') ?? 0;
  return 'Active · $out of $stock out · Deposit Rs $deposit';
}
