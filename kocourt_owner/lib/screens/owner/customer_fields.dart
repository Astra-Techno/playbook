/// Owner list of players who booked a venue. Phone numbers are dropped.
List<Map<String, dynamic>> customerRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['customers'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'name': row['name'],
          'booking_count': row['booking_count'],
          'last_played': row['last_played'],
        },
  ];
}

String customerLine(Map<String, dynamic> row) {
  final count = int.tryParse('${row['booking_count']}') ?? 0;
  final visits = count == 1 ? '1 booking' : '$count bookings';
  final last = row['last_played']?.toString() ?? '';
  if (last.isEmpty) return visits;
  return '$visits · last $last';
}
