import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/schedule_fields.dart';

void main() {
  test('pricing rule body uses the stored columns', () {
    expect(
      pricingRuleBody(
        courtId: 4,
        spaceId: 8,
        name: ' Weekend peak ',
        dayType: 'weekend',
        startHour: 18,
        endHour: 22,
        price: 1200,
        priority: 2,
      ),
      {
        'court_id': 4,
        'sub_court_id': 8,
        'name': 'Weekend peak',
        'day_type': 'weekend',
        'start_hour': 18,
        'end_hour': 22,
        'price': 1200,
        'priority': 2,
      },
    );
    expect(
      () => pricingRuleBody(
        courtId: 4,
        name: 'Bad',
        dayType: 'peak',
        startHour: 18,
        endHour: 22,
        price: 1,
      ),
      throwsA(isA<ScheduleFieldError>()),
    );
  });

  test('block body is a real range for one facility', () {
    final body = blockRangeBody(
      courtId: 4,
      spaceId: 8,
      start: DateTime(2026, 10, 31, 22),
      end: DateTime(2026, 11, 1, 2),
      reason: 'Holiday',
      blockKind: 'holiday',
      repeatAnnually: true,
    );
    expect(body['start_time'], '2026-10-31 22:00:00');
    expect(body['end_time'], '2026-11-01 02:00:00');
    expect(body['sub_court_id'], 8);
    expect(body['block_kind'], 'holiday');
    expect(body['repeat_annually'], 1);
  });

  test('a venue block omits the facility id', () {
    final body = blockRangeBody(
      courtId: 4,
      start: DateTime(2026, 10, 31, 9),
      end: DateTime(2026, 10, 31, 12),
    );
    expect(body.containsKey('sub_court_id'), isFalse);
    expect(body['block_kind'], 'other');
  });
}
