/// Owner arrival alerts. The list keeps the title and the body, and drops a phone number.
List<Map<String, dynamic>> notificationRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['notifications'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'type': row['type'],
          'title': row['title'],
          'body': row['body'],
          'court_name': row['court_name'],
          'is_read': row['is_read'],
          'read_at': row['read_at'],
          'created_at': row['created_at'],
        },
  ];
}

String alertLine(Map<String, dynamic> row) {
  final title = (row['title'] ?? '').toString();
  final body = (row['body'] ?? '').toString();
  return '$title · $body';
}
