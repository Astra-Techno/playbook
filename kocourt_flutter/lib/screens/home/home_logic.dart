// Pure helpers behind the Home "next game" card and open-now labels.
import '../matches/match_roster.dart' show matchSpotsLeft;

/// Earliest confirmed booking that has not started yet, or null.
Map<String, dynamic>? nextUpcomingBooking(List<Map<String, dynamic>> rows, DateTime now) {
  Map<String, dynamic>? best;
  DateTime? bestAt;
  for (final row in rows) {
    if (row['status'] != 'confirmed') continue;
    final at = DateTime.tryParse('${row['start_time']}');
    if (at == null || !at.isAfter(now)) continue;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = row;
      bestAt = at;
    }
  }
  return best;
}

/// "2d 3h", "2h 14m" or "9m" until kick-off.
String kickoffIn(Duration left) {
  if (left.inDays > 0) return '${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours > 0) return '${left.inHours}h ${left.inMinutes % 60}m';
  return '${left.inMinutes.clamp(0, 59)}m';
}

int? _minutesOf(Object? hhmmss) {
  final parts = '${hhmmss ?? ''}'.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  return h == null || m == null ? null : h * 60 + m;
}

/// Venue open right now by its open/close times; handles closing after midnight.
bool isOpenNow(Map<String, dynamic> venue, DateTime now) {
  final open = _minutesOf(venue['open_time'] ?? '06:00:00');
  final close = _minutesOf(venue['close_time'] ?? '22:00:00');
  if (open == null || close == null) return false;
  final t = now.hour * 60 + now.minute;
  return close > open ? t >= open && t < close : t >= open || t < close;
}

/// "6 AM", "10:30 PM" from "HH:MM:SS".
String clockLabel(Object? hhmmss) {
  final mins = _minutesOf(hhmmss);
  if (mins == null) return '';
  final h = (mins ~/ 60) % 24;
  final m = mins % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

/// Open games that still need players (same spot rule as the Matches tab).
int gamesNeedingPlayers(List<Map<String, dynamic>> requests) {
  var count = 0;
  for (final m in requests) {
    final needed = int.tryParse('${m['slots_needed'] ?? m['players_needed'] ?? 1}') ?? 1;
    final participants = m['participants'] is List ? (m['participants'] as List).length : 0;
    final joined = int.tryParse('${m['joined_count'] ?? participants}') ?? participants;
    if (matchSpotsLeft(needed, joined > participants ? joined : participants) > 0) count++;
  }
  return count;
}
