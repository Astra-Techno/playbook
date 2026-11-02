/// Owner list of peak-hour members. Phone numbers are dropped.
List<Map<String, dynamic>> memberRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['members'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'user_name': row['user_name'],
          'plan_name': row['plan_name'],
          'end_date': row['end_date'],
          'status': row['status'],
          'slot_type': row['slot_type'],
        },
  ];
}

String membershipSlotLabel(Object? slot) {
  switch (slot?.toString()) {
    case 'morning':
      return 'Morning peak';
    case 'evening':
      return 'Evening peak';
    case 'full_day':
      return 'Full day';
    case 'unlimited':
      return 'All peak hours';
    default:
      return 'Peak hours';
  }
}
