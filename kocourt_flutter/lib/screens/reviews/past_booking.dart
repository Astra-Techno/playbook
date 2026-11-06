import 'package:kocourt_shared/kocourt_shared.dart';

/// Latest confirmed booking at this venue whose start time has passed.
int? pastBookingId(List<dynamic> records, int courtId, DateTime now) {
  int? bestId;
  DateTime? bestStart;
  for (final raw in records) {
    if (raw is! Map) continue;
    final court = positiveId(raw['court_id']);
    final id = positiveId(raw['id']);
    if (court != courtId || id == null) continue;
    if ('${raw['status'] ?? ''}' != 'confirmed') continue;
    final start = DateTime.tryParse('${raw['start_time']}'.replaceFirst(' ', 'T'));
    if (start == null || start.isAfter(now)) continue;
    if (bestStart == null || start.isAfter(bestStart)) {
      bestId = id;
      bestStart = start;
    }
  }
  return bestId;
}
