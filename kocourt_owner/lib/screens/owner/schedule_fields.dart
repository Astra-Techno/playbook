/// Payloads for the existing pricing-rule and blocked-slot APIs.
///
/// Availability stays on the server. These helpers only shape what the
/// owner app is allowed to send.
const pricingDayTypes = ['all', 'weekday', 'weekend'];

const blockKinds = [
  'maintenance',
  'holiday',
  'private_event',
  'tournament',
  'coaching',
  'other',
];

class ScheduleFieldError implements Exception {
  final String message;
  const ScheduleFieldError(this.message);
}

int? asScheduleId(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

String pricingDayLabel(String dayType) {
  switch (dayType) {
    case 'weekday':
      return 'Weekdays';
    case 'weekend':
      return 'Weekends';
    default:
      return 'Every day';
  }
}

String blockKindLabel(String kind) {
  switch (kind) {
    case 'maintenance':
      return 'Maintenance';
    case 'holiday':
      return 'Holiday';
    case 'private_event':
      return 'Private event';
    case 'tournament':
      return 'Tournament';
    case 'coaching':
      return 'Coaching';
    default:
      return 'Other';
  }
}

String sqlDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

/// One hour starting at [date] and [startHour]. Hour 23 ends at the next midnight.
({String start, String end}) hourWindow(String date, int startHour) {
  final parts = date.split('-');
  if (parts.length != 3 || startHour < 0 || startHour > 23) {
    throw const ScheduleFieldError('Choose an hour from 0 to 23.');
  }
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  final start = DateTime(year, month, day, startHour);
  final end = startHour == 23 ? DateTime(year, month, day + 1) : DateTime(year, month, day, startHour + 1);
  return (start: sqlDateTime(start), end: sqlDateTime(end));
}

Map<String, dynamic> pricingRuleBody({
  required int courtId,
  int? spaceId,
  required String name,
  required String dayType,
  required int startHour,
  required int endHour,
  required double price,
  int priority = 0,
  String? validFrom,
  String? validTo,
}) {
  final trimmed = name.trim();
  if (courtId <= 0 || trimmed.isEmpty) {
    throw const ScheduleFieldError('A venue and a rule name are required.');
  }
  if (!pricingDayTypes.contains(dayType)) {
    throw const ScheduleFieldError('Choose every day, weekdays, or weekends.');
  }
  if (startHour < 0 || startHour > 23 || endHour <= startHour || endHour > 24) {
    throw const ScheduleFieldError('The end hour must be after the start hour.');
  }
  if (price < 0) {
    throw const ScheduleFieldError('Price cannot be negative.');
  }
  return {
    'court_id': courtId,
    if (spaceId != null && spaceId > 0) 'sub_court_id': spaceId,
    'name': trimmed,
    'day_type': dayType,
    'start_hour': startHour,
    'end_hour': endHour,
    'price': price,
    'priority': priority,
    if (validFrom != null && validFrom.isNotEmpty) 'valid_from': validFrom,
    if (validTo != null && validTo.isNotEmpty) 'valid_to': validTo,
  };
}

Map<String, dynamic> blockRangeBody({
  required int courtId,
  int? spaceId,
  required DateTime start,
  required DateTime end,
  String reason = '',
  String blockKind = 'other',
  bool repeatAnnually = false,
}) {
  if (courtId <= 0 || !end.isAfter(start)) {
    throw const ScheduleFieldError('The end must be after the start.');
  }
  final kind = blockKinds.contains(blockKind) ? blockKind : 'other';
  return {
    'court_id': courtId,
    if (spaceId != null && spaceId > 0) 'sub_court_id': spaceId,
    'start_time': sqlDateTime(start),
    'end_time': sqlDateTime(end),
    'reason': reason.trim(),
    'block_kind': kind,
    'repeat_annually': repeatAnnually ? 1 : 0,
  };
}
