import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/staff_fields.dart';

void main() {
  test('staff rows keep the two roles and the invite sends a phone', () {
    final rows = staffRows({
      'records': [
        {'id': 1, 'name': 'Ada', 'role': 'staff'},
      ],
      'staff': [
        {'id': 4, 'name': 'Ada', 'phone': '9999900000', 'role': 'manager'},
        {'id': 5, 'name': 'Bo', 'phone': '9999900001', 'role': 'viewer'},
        {'id': 6, 'name': 'Cy', 'role': 'staff'},
      ],
    });
    expect(rows, hasLength(2));
    expect(rows.first['role'], 'manager');
    expect(staffRole('staff'), isNull);
    expect(
      staffInviteBody(courtId: 9, phone: ' 9999900000 ', role: 'staff'),
      {'court_id': 9, 'phone': '9999900000', 'role': 'viewer'},
    );
    expect(staffRoleBody('manager'), {'role': 'manager'});
    expect(staffPermissionLine('viewer'), contains('Calendar and bookings'));
    expect(staffPermissionLine('manager'), contains('walk-ins'));
    expect(staffRoleLabel('manager'), 'Manager');
  });
}
