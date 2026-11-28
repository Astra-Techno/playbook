import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/member_fields.dart';

void main() {
  test('the member list keeps the plan and drops the phone', () {
    final rows = memberRows({
      'members': [
        {
          'user_name': 'Ada',
          'user_phone': '9999900000',
          'plan_name': 'Evening',
          'slot_type': 'evening',
          'status': 'active',
          'end_date': '2026-12-01',
        },
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.first['user_name'], 'Ada');
    expect(rows.first.containsKey('user_phone'), isFalse);
    expect(membershipSlotLabel('evening'), 'Evening peak');
    expect(membershipSlotLabel('unlimited'), 'All peak hours');
    expect(memberRows({'active': null}), isEmpty);
  });

  test('member line shows end day, visits and last visit', () {
    final now = DateTime(2026, 11, 28, 18);
    expect(
      memberVisitLine({'end_date': '2026-12-16', 'visits_this_month': 12, 'last_visit': '2026-11-25 17:00:00'}, now: now),
      startsWith('Ends '),
    );
    expect(
      memberVisitLine({'end_date': '2026-12-16', 'visits_this_month': 12, 'last_visit': '2026-11-25 17:00:00'}, now: now),
      contains('12 visits this month · last visit 3d ago'),
    );
    expect(memberVisitLine({'end_date': '2026-12-16', 'visits_this_month': 0, 'last_visit': null}, now: now),
        endsWith('0 visits this month · no visits yet'));
  });

  test('desk filters: ending soon, going quiet and frozen', () {
    final now = DateTime(2026, 11, 28, 18);
    final ending = {'end_date': '2026-12-02', 'last_visit': '2026-11-27 18:00:00'};
    final quiet = {'end_date': '2026-12-30', 'last_visit': '2026-11-10 18:00:00'};
    final never = {'end_date': '2026-12-30', 'last_visit': null};
    final frozen = {'end_date': '2026-12-30', 'last_visit': null, 'frozen_from': '2026-11-25', 'frozen_until': '2026-12-08'};
    final regular = {'end_date': '2026-12-30', 'last_visit': '2026-11-27 18:00:00'};

    expect(memberMatches(ending, MemberFilter.endingSoon, now: now), isTrue);
    expect(memberMatches(regular, MemberFilter.endingSoon, now: now), isFalse);
    expect(memberMatches(quiet, MemberFilter.goingQuiet, now: now), isTrue);
    expect(memberMatches(never, MemberFilter.goingQuiet, now: now), isTrue);
    expect(memberMatches(frozen, MemberFilter.goingQuiet, now: now), isFalse, reason: 'a frozen member is not going quiet');
    expect(memberMatches(regular, MemberFilter.goingQuiet, now: now), isFalse);
    expect(memberMatches(frozen, MemberFilter.frozen, now: now), isTrue);
    expect(memberMatches(regular, MemberFilter.frozen, now: now), isFalse);
    expect(memberVisitLine(frozen, now: now), startsWith('Frozen until '));
  });

  test('a freeze that ended is no longer frozen', () {
    final now = DateTime(2026, 11, 28);
    expect(memberFrozenUntil({'frozen_from': '2026-11-01', 'frozen_until': '2026-11-27'}, now: now), isNull);
    expect(memberFrozenUntil({'frozen_from': '2026-11-01', 'frozen_until': '2026-11-28'}, now: now), DateTime(2026, 11, 28));
  });
}
