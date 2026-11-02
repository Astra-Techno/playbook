/// Today's booked time from `GET /courts/occupancy`.
class TodayOccupancy {
  final int courtId;
  final int bookedMinutes;
  final int openMinutes;
  final int confirmedCount;

  const TodayOccupancy({
    required this.courtId,
    required this.bookedMinutes,
    required this.openMinutes,
    required this.confirmedCount,
  });
}

int? _whole(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

Map<int, TodayOccupancy> occupancyByVenue(dynamic payload) {
  if (payload is! Map) return {};
  final raw = payload['venues'];
  if (raw is! List) return {};
  final venues = <int, TodayOccupancy>{};
  for (final row in raw.whereType<Map>()) {
    final courtId = _whole(row['court_id']);
    final booked = _whole(row['booked_minutes']);
    final open = _whole(row['open_minutes']);
    final count = _whole(row['confirmed_count']);
    if (courtId == null || courtId <= 0 || booked == null || open == null || count == null) continue;
    venues[courtId] = TodayOccupancy(
      courtId: courtId,
      bookedMinutes: booked,
      openMinutes: open,
      confirmedCount: count,
    );
  }
  return venues;
}

String _hours(int minutes) {
  final hours = minutes / 60;
  if (hours == hours.roundToDouble()) return '${hours.round()}h';
  return '${hours.toStringAsFixed(1)}h';
}

String occupancyLine(TodayOccupancy day) {
  if (day.openMinutes <= 0) return '${day.confirmedCount} confirmed today';
  return '${_hours(day.bookedMinutes)} booked of ${_hours(day.openMinutes)} open today';
}
