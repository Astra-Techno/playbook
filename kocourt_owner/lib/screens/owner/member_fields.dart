import 'package:kocourt_shared/kocourt_shared.dart';

/// Owner list of peak-hour members. Phone numbers are dropped.
List<Map<String, dynamic>> memberRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['members'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'user_name': row['user_name'],
          'plan_name': row['plan_name'],
          'end_date': row['end_date'],
          'status': row['status'],
          'slot_type': row['slot_type'],
          'visits_this_month': row['visits_this_month'],
          'last_visit': row['last_visit'],
          'frozen_from': row['frozen_from'],
          'frozen_until': row['frozen_until'],
        },
  ];
}

/// "Ends Wed 26 Nov · 12 visits this month · last in 3d" (or "no visits yet").
String memberVisitLine(Map<String, dynamic> m, {DateTime? now}) {
  final ends = DateTime.tryParse('${m['end_date'] ?? ''}');
  final visits = int.tryParse('${m['visits_this_month'] ?? ''}');
  final last = '${m['last_visit'] ?? ''}';
  final frozen = memberFrozenUntil(m, now: now);
  return [
    if (frozen != null) 'Frozen until ${friendlyDay(frozen, now: now)}',
    if (ends != null) 'Ends ${friendlyDay(ends, now: now)}',
    if (visits != null) '$visits ${visits == 1 ? 'visit' : 'visits'} this month',
    if (last.isEmpty) 'no visits yet' else _lastVisit(timeAgo(last, now: now)),
  ].join(' · ');
}

/// Members list filters at the desk.
enum MemberFilter { all, endingSoon, goingQuiet, frozen }

const memberFilterLabels = {
  MemberFilter.all: 'All',
  MemberFilter.endingSoon: 'Ending soon',
  MemberFilter.goingQuiet: 'Going quiet',
  MemberFilter.frozen: 'Frozen',
};

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// The last frozen day when the membership is frozen today, else null.
DateTime? memberFrozenUntil(Map<String, dynamic> m, {DateTime? now}) {
  final from = DateTime.tryParse('${m['frozen_from'] ?? ''}');
  final until = DateTime.tryParse('${m['frozen_until'] ?? ''}');
  if (from == null || until == null) return null;
  final today = _day(now ?? DateTime.now());
  return !today.isBefore(_day(from)) && !today.isAfter(_day(until)) ? until : null;
}

/// Ending soon: 7 days or fewer left. Going quiet: no visit for 14 days (or never), not frozen.
bool memberMatches(Map<String, dynamic> m, MemberFilter filter, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());
  switch (filter) {
    case MemberFilter.all:
      return true;
    case MemberFilter.frozen:
      return memberFrozenUntil(m, now: now) != null;
    case MemberFilter.endingSoon:
      final ends = DateTime.tryParse('${m['end_date'] ?? ''}');
      return ends != null && !_day(ends).isBefore(today) && _day(ends).difference(today).inDays < 7;
    case MemberFilter.goingQuiet:
      if (memberFrozenUntil(m, now: now) != null) return false;
      final last = DateTime.tryParse('${m['last_visit'] ?? ''}'.replaceFirst(' ', 'T'));
      return last == null || today.difference(_day(last)).inDays >= 14;
  }
}

/// "3d" reads "last visit 3d ago"; an older date reads "last visit Wed 19 Nov".
String _lastVisit(String ago) => RegExp(r'^\d+[mhd]$').hasMatch(ago) ? 'last visit $ago ago' : 'last visit $ago';

String membershipSlotLabel(Object? slot) {
  switch (slot?.toString()) {
    case 'morning':
      return 'Morning peak';
    case 'evening':
      return 'Evening peak';
    case 'full_day':
      return 'Full day';
    case 'unlimited':
      return 'All peak hours';
    default:
      return 'Peak hours';
  }
}
