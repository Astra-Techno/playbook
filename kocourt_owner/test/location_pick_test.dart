import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/location_pick.dart';

void main() {
  test('a search result becomes a place only when it has coordinates', () {
    final place = placeFromSearch({
      'lat': '13.08',
      'lon': '80.27',
      'address': {'city': 'Chennai', 'state': 'Tamil Nadu'},
    });
    expect(place?.label, 'Chennai, Tamil Nadu');
    expect(place?.lat, 13.08);
    expect(place?.lng, 80.27);
    expect(placeFromSearch({'display_name': 'Anna Nagar'}), isNull);
  });

  test('a typed area is not enough without coordinates', () {
    expect(locationReady('Anna Nagar', null, null), isFalse);
    expect(locationReady('Chennai, Tamil Nadu', 13.08, 80.27), isTrue);
    expect(locationReady('  ', 13.08, 80.27), isFalse);
  });
}
