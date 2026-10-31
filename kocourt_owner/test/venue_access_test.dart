import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/venue_access.dart';

void main() {
  test('owned venue stays labeled owner when the same court is also assigned', () {
    final listings = mergeVenueListings(
      owned: [
        {'id': 4, 'name': 'Arena A'},
      ],
      assigned: [
        {'id': '4', 'name': 'Arena A', 'role': 'manager'},
        {'id': 9, 'name': 'Turf B', 'role': 'viewer'},
      ],
    );

    expect(listings.map((v) => v.id).toList(), [4, 9]);
    expect(listings.first.accessLabel, 'Owner');
    expect(listings.last.accessLabel, 'Staff · Viewer');
    expect(listings.last.isOwner, isFalse);
  });

  test('staff-only list is kept and invalid ids are dropped', () {
    final listings = mergeVenueListings(
      owned: const [],
      assigned: [
        {'id': 0, 'name': 'Bad', 'role': 'manager'},
        {'id': '12', 'name': 'Court 2', 'role': 'manager'},
      ],
    );

    expect(listings, hasLength(1));
    expect(listings.single.id, 12);
    expect(listings.single.accessLabel, 'Staff · Manager');
  });
}
