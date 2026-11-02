/// A venue coaching class. The instructor is a name. Court time is closed by the server.
List<Map<String, dynamic>> coachingRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['sessions'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'title': row['title'],
          'instructor_name': row['instructor_name'],
          'capacity': row['capacity'],
          'start_time': row['start_time'],
          'end_time': row['end_time'],
          'status': row['status'],
          'enrollments': [
            for (final player in (row['enrollments'] is List ? row['enrollments'] as List : const []))
              if (player is Map)
                {
                  'id': player['id'],
                  'display_name': player['display_name'],
                  'attendance': player['attendance'],
                  'state': player['state'],
                },
          ],
        },
  ];
}

final _classClock = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

Map<String, dynamic>? coachingBody({
  required String title,
  required String instructor,
  required String capacity,
  required String start,
  required String end,
}) {
  final name = title.trim();
  final coach = instructor.trim();
  final seats = int.tryParse(capacity.trim());
  final startTrim = start.trim();
  final endTrim = end.trim();
  if (name.isEmpty || name.length > 120 || coach.isEmpty || coach.length > 80) return null;
  if (seats == null || seats < 1 || seats > 200) return null;
  if (!_classClock.hasMatch(startTrim) || !_classClock.hasMatch(endTrim) || endTrim.compareTo(startTrim) <= 0) return null;
  return {
    'title': name,
    'instructor_name': coach,
    'capacity': seats,
    'start_time': startTrim,
    'end_time': endTrim,
  };
}

Map<String, String>? enrollmentBody(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.length > 80) return null;
  return {'display_name': trimmed};
}

Map<String, String>? attendanceBody(String mark) {
  if (mark != 'present' && mark != 'absent') return null;
  return {'attendance': mark};
}

String coachingLine(Map<String, dynamic> row) {
  final seats = int.tryParse('${row['capacity']}') ?? 0;
  final players = row['enrollments'] is List ? (row['enrollments'] as List).length : 0;
  final status = row['status'] == 'cancelled' ? 'Cancelled' : 'Scheduled';
  return '$status · ${row['instructor_name']} · $players of $seats · ${row['start_time']}';
}
