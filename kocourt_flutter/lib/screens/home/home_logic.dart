// Pure helpers behind the Home "next game" card and open-now labels.
import 'package:flutter/foundation.dart' show ValueNotifier;
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

/// Hour of a venue's `free_from` ("YYYY-MM-DD HH:00:00"), or null.
int? freeHour(Map<String, dynamic> venue) {
  final from = '${venue['free_from'] ?? ''}';
  return from.length >= 13 ? int.tryParse(from.substring(11, 13)) : null;
}

/// Badge text for a venue in the stack: "Free 7 PM" when known, else "Open now".
String freeLabel(Map<String, dynamic> venue) {
  final from = '${venue['free_from'] ?? ''}';
  return from.length >= 19 ? 'Free ${clockLabel(from.substring(11))}' : 'Open now';
}

// ── Matchday phase 1: "When are you playing?" chips and the day strip ──

/// The time chips at the top of Home and the venue list.
enum PlayTime { now, tonight, tomorrowMorning }

String playTimeLabel(PlayTime t) => switch (t) {
      PlayTime.now => 'Now',
      PlayTime.tonight => 'Tonight',
      PlayTime.tomorrowMorning => 'Tomorrow 7 AM',
    };

/// The chosen time, shared by every screen that shows the chips (kept for the session).
final playTimeChoice = ValueNotifier<PlayTime>(PlayTime.now);

String _sqlDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The day and first hour a chip asks for. "Now" is the next full hour;
/// "Tonight" is 7 PM (or the next hour once it is later than that).
({String date, int hour}) playTarget(PlayTime t, DateTime now) {
  final nextHour = now.hour + (now.minute > 0 || now.second > 0 ? 1 : 0);
  switch (t) {
    case PlayTime.now:
      return (date: _sqlDate(now), hour: nextHour);
    case PlayTime.tonight:
      return (date: _sqlDate(now), hour: nextHour > 19 ? nextHour : 19);
    case PlayTime.tomorrowMorning:
      return (date: _sqlDate(now.add(const Duration(days: 1))), hour: 7);
  }
}

/// First hour at or after [fromHour] that a day strip marks free ('f' or 'p').
int? nextFreeHour(String? strip, int fromHour, {int firstHour = 6}) {
  if (strip == null) return null;
  for (var i = 0; i < strip.length; i++) {
    final hour = firstHour + i;
    if (hour >= fromHour && (strip[i] == 'f' || strip[i] == 'p')) return hour;
  }
  return null;
}

/// "7 PM", "12 PM", "6 AM".
String hourLabel(int hour) {
  final h = hour % 24;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12 ${h < 12 ? 'AM' : 'PM'}';
}

/// Venues tagged with their strip and next free hour for the chosen time,
/// soonest first; venues with nothing free are dropped. Before strips load
/// ([strips] null) the list is returned as it is.
List<Map<String, dynamic>> withStrips(List<Map<String, dynamic>> venues, Map<String, String>? strips, ({String date, int hour}) target) {
  if (strips == null) return venues;
  final out = <Map<String, dynamic>>[];
  for (final v in venues) {
    final strip = strips['${v['id']}'];
    final hour = nextFreeHour(strip, target.hour);
    if (hour == null) continue;
    out.add({...v, 'strip': strip, 'free_from': '${target.date} ${hour.toString().padLeft(2, '0')}:00:00'});
  }
  out.sort((a, b) => '${a['free_from']}'.compareTo('${b['free_from']}'));
  return out;
}

// ── Matchday phase 2: your crew ──

/// "Wed 7 PM" for a slot start; "7:30 PM" style when not on the hour.
String slotDayLabel(DateTime start) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final time = start.minute == 0 ? hourLabel(start.hour) : '${start.hour % 12 == 0 ? 12 : start.hour % 12}:${start.minute.toString().padLeft(2, '0')} ${start.hour < 12 ? 'AM' : 'PM'}';
  return '${days[start.weekday - 1]} $time';
}

/// "with Arjun", "with Arjun and Ravi", "with Arjun +3".
String crewWith(List<String> names) {
  if (names.isEmpty) return '';
  final first = names.first.trim().split(RegExp(r'\s+')).first;
  if (names.length == 1) return 'with $first';
  if (names.length == 2) return 'with $first and ${names[1].trim().split(RegExp(r'\s+')).first}';
  return 'with $first +${names.length - 1}';
}
