import 'schedule_fields.dart';

class WalkInFieldError implements Exception {
  final String message;
  const WalkInFieldError(this.message);
}

/// Body for `POST /bookings` as a walk-in.
///
/// The server treats a non-empty guest name as a walk-in and stores the
/// start and end as datetimes. The date field and the owner id are not sent.
Map<String, dynamic> walkInBody({
  required int courtId,
  required String date,
  required int startHour,
  required String guestName,
  String guestPhone = '',
  int? spaceId,
  bool spaceRequired = false,
}) {
  final name = guestName.trim();
  final parts = date.split('-');
  if (courtId <= 0 || parts.length != 3 || name.isEmpty) {
    throw const WalkInFieldError('A guest name and a date are required.');
  }
  if (startHour < 0 || startHour > 23) {
    throw const WalkInFieldError('Choose an hour from 0 to 23.');
  }
  if (spaceRequired && (spaceId == null || spaceId <= 0)) {
    throw const WalkInFieldError('Choose a space.');
  }
  final window = hourWindow(date, startHour);
  return {
    'court_id': courtId,
    if (spaceId != null && spaceId > 0) 'sub_court_id': spaceId,
    'start_time': window.start,
    'end_time': window.end,
    'guest_name': name,
    'guest_phone': guestPhone.trim(),
    'type': 'hourly',
  };
}

Map<String, String> rescheduleBody({required String date, required int startHour}) {
  final window = hourWindow(date, startHour);
  return {'start_time': window.start, 'end_time': window.end};
}

int rowsOnDate(List<Map<String, dynamic>> rows, String day, {bool annual = false}) {
  var count = 0;
  for (final row in rows) {
    final start = '${row['start_time'] ?? ''}';
    if (start.length < 10 || day.length < 10) continue;
    final repeats = annual && (row['repeat_annually'] == 1 || row['repeat_annually'] == '1' || row['repeat_annually'] == true);
    if (repeats) {
      if (start.substring(5, 10) == day.substring(5, 10)) count++;
    } else if (start.substring(0, 10) == day) {
      count++;
    }
  }
  return count;
}

Set<int> busyDayNumbers(dynamic payload) {
  if (payload is! Map) return {};
  final raw = payload['busy_days'];
  if (raw is! List) return {};
  return raw.map((day) => int.tryParse('$day') ?? 0).where((day) => day > 0).toSet();
}

String bookingPerson(Map<String, dynamic> booking) {
  final guest = '${booking['guest_name'] ?? ''}'.trim();
  if (guest.isNotEmpty) return guest;
  final user = '${booking['user_name'] ?? ''}'.trim();
  if (user.isNotEmpty) return user;
  return 'Player';
}
