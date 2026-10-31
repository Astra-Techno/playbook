import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/venue_listing.dart';

void main() {
  test('only the owner id can manage the venue', () {
    final court = {'owner_id': '9', 'claim_status': null, 'is_verified': 0};
    expect(venueOwnedBy(court, 9), isTrue);
    expect(venueOwnedBy(court, 4), isFalse);
    expect(venueOwnedBy(court, null), isFalse);
  });

  test('listing follows the customer search rule', () {
    expect(venueListingLabel(null), 'Listed for players.');
    expect(venueListingLabel('approved'), 'Listed for players.');
    expect(venueListingLabel('pending'), contains('waiting for review'));
    expect(venueListingLabel('rejected'), contains('rejected'));
    expect(venueIsVerified(1), isTrue);
    expect(venueIsVerified(0), isFalse);
    expect(venueVerificationLabel(false), contains('Only KoCourt'));
  });

  test('gallery photo body uses the existing court-photos fields', () {
    expect(
      courtPhotoBody(courtId: 3, url: ' https://cdn.example/a.jpg ', sortOrder: 2),
      {'court_id': 3, 'url': 'https://cdn.example/a.jpg', 'sort_order': 2},
    );
    expect(
      () => courtPhotoBody(courtId: 3, url: '  ', sortOrder: 0),
      throwsArgumentError,
    );
  });
}
