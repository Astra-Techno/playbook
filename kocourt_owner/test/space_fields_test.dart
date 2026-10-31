import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/space_fields.dart';

void main() {
  test('create body keeps exclusive and shared and clears a blank rate', () {
    final body = spaceWriteBody(
      courtId: 3,
      name: ' Court 1 ',
      description: ' Lane A ',
      capacityText: '20',
      hourlyRateText: '',
      bookingMode: 'shared',
    );

    expect(body['court_id'], 3);
    expect(body['name'], 'Court 1');
    expect(body['description'], 'Lane A');
    expect(body['capacity'], 20);
    expect(body['booking_mode'], 'shared');
    expect(body['hourly_rate'], '');
  });

  test('unknown booking modes are rejected', () {
    expect(
      () => spaceWriteBody(
        name: 'Pool',
        description: '',
        capacityText: '8',
        hourlyRateText: '500',
        bookingMode: 'shared_capacity',
      ),
      throwsA(isA<SpaceFieldError>()),
    );
  });

  test('capacity below 1 is rejected', () {
    expect(
      () => spaceWriteBody(
        name: 'Court',
        description: '',
        capacityText: '0',
        hourlyRateText: '100',
        bookingMode: 'exclusive',
      ),
      throwsA(isA<SpaceFieldError>()),
    );
  });

  test('detail payload is read from the space key', () {
    final record = spaceRecord({
      'space': {'id': '4', 'name': 'Pool', 'booking_mode': 'shared', 'capacity': 12},
    });

    expect(record?['name'], 'Pool');
    expect(spaceModeLabel(record?['booking_mode'], record?['capacity']), 'Shared · 12 at a time');
    expect(spaceModeLabel('exclusive', 4), 'Exclusive');
  });
}
