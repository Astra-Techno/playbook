/// Owner staff list. Roles stay manager or viewer.
List<Map<String, dynamic>> staffRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['staff'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map && (row['role'] == 'manager' || row['role'] == 'viewer'))
        {
          'id': row['id'],
          'name': row['name'],
          'phone': row['phone'],
          'role': row['role'],
        },
  ];
}

String? staffRole(Object? value) {
  final role = value?.toString().trim() ?? '';
  if (role == 'manager' || role == 'viewer') return role;
  return null;
}

Map<String, dynamic> staffInviteBody({required int courtId, required String phone, required String role}) {
  return {
    'court_id': courtId,
    'phone': phone.trim(),
    'role': staffRole(role) ?? 'viewer',
  };
}

Map<String, String> staffRoleBody(String role) {
  return {'role': staffRole(role) ?? 'viewer'};
}

String staffRoleLabel(Object? role) {
  return role == 'manager' ? 'Manager' : 'Viewer';
}

String staffPermissionLine(Object? role) {
  if (role == 'manager') {
    return 'Calendar, bookings, walk-ins, attendance, closures, and customers at this venue';
  }
  return 'Calendar and bookings at this venue';
}
