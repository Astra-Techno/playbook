import 'package:kocourt_shared/kocourt_shared.dart';

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
          'visits_this_month': row['visits_this_month'],
          'last_visit': row['last_visit'],
        },
  ];
}

/// "Ends Wed 26 Nov · 12 visits this month · last in 3d" (or "no visits yet").
String memberVisitLine(Map<String, dynamic> m, {DateTime? now}) {
  final ends = DateTime.tryParse('${m['end_date'] ?? ''}');
  final visits = int.tryParse('${m['visits_this_month'] ?? ''}');
  final last = '${m['last_visit'] ?? ''}';
  return [
    if (ends != null) 'Ends ${friendlyDay(ends, now: now)}',
    if (visits != null) '$visits ${visits == 1 ? 'visit' : 'visits'} this month',
    if (last.isEmpty) 'no visits yet' else _lastVisit(timeAgo(last, now: now)),
  ].join(' · ');
}

/// "3d" reads "last visit 3d ago"; an older date reads "last visit Wed 19 Nov".
String _lastVisit(String ago) => RegExp(r'^\d+[mhd]$').hasMatch(ago) ? 'last visit $ago ago' : 'last visit $ago';

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
