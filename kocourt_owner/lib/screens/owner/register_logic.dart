// Pure rules behind the Court register (tested in test/register_logic_test.dart).
// Rows come from `GET /courts/:id/calendar?date=…` (day view).

DateTime? _at(Object? raw) => DateTime.tryParse('${raw ?? ''}');

double _money(Object? raw) => double.tryParse('${raw ?? ''}') ?? 0;

bool _confirmed(Map<String, dynamic> b) => '${b['status'] ?? 'confirmed'}' == 'confirmed';

bool _blank(Object? v) => v == null || '$v'.trim().isEmpty;

/// Pay at venue and not yet marked paid.
bool paymentDue(Map<String, dynamic> b) =>
    b['collection_method'] == 'pay_at_venue' && b['payment_status'] != 'paid';

String playerName(Map<String, dynamic> b) {
  for (final key in ['user_name', 'guest_name']) {
    if (!_blank(b[key])) return '${b[key]}'.trim();
  }
  return 'Player';
}

class TillTotals {
  const TillTotals({this.cash = 0, this.upi = 0, this.online = 0, this.toCollect = 0});
  final double cash;
  final double upi;
  final double online;
  final double toCollect;
}

/// Today's money by how it was taken. Online = paid in the app.
TillTotals tillTotals(List<Map<String, dynamic>> bookings) {
  var cash = 0.0, upi = 0.0, online = 0.0, due = 0.0;
  for (final b in bookings.where(_confirmed)) {
    final price = _money(b['total_price']);
    switch (b['collection_method']) {
      case 'cash':
        cash += price;
      case 'external_upi':
        upi += price;
      case 'pay_at_venue':
        b['payment_status'] == 'paid' ? cash += price : due += price;
      default:
        if (b['payment_status'] == 'paid') online += price;
    }
  }
  return TillTotals(cash: cash, upi: upi, online: online, toCollect: due);
}

enum TileKind { inPlay, ending, collect, free, closed }

class CourtTile {
  const CourtTile({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.clock = '',
    this.progress = 0,
    this.booking,
  });
  final TileKind kind;
  final String title;
  final String subtitle;
  final String clock;

  /// Share of the current game still to play, 0–1.
  final double progress;
  final Map<String, dynamic>? booking;
}

/// Minutes before the end when a court shows as ending.
const endingMinutes = 10;

/// A row belongs to a space when it names it, or names no space (whole venue).
bool _forSpace(Map<String, dynamic> row, int? spaceId) =>
    spaceId == null || _blank(row['sub_court_id']) || '${row['sub_court_id']}' == '$spaceId';

String _clock(DateTime at) {
  final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final mins = at.minute == 0 ? '' : ':${at.minute.toString().padLeft(2, '0')}';
  return '$h12$mins ${at.hour < 12 ? 'AM' : 'PM'}';
}

/// What one court is doing right now.
CourtTile courtTile({
  required List<Map<String, dynamic>> bookings,
  required List<Map<String, dynamic>> blocks,
  required int? spaceId,
  required DateTime now,
}) {
  final mine = bookings.where((b) => _confirmed(b) && _forSpace(b, spaceId)).toList();
  final myBlocks = blocks.where((b) => _forSpace(b, spaceId)).toList();

  bool covers(Map<String, dynamic> row) {
    final start = _at(row['start_time']);
    final end = _at(row['end_time']);
    return start != null && end != null && !now.isBefore(start) && now.isBefore(end);
  }

  for (final block in myBlocks) {
    if (covers(block)) {
      final end = _at(block['end_time'])!;
      return CourtTile(
        kind: TileKind.closed,
        title: 'Closed',
        subtitle: '${_blank(block['reason']) ? 'Blocked' : block['reason']} · till ${_clock(end)}',
      );
    }
  }

  for (final b in mine) {
    if (!covers(b)) continue;
    final start = _at(b['start_time'])!;
    final end = _at(b['end_time'])!;
    final left = end.difference(now);
    final total = end.difference(start).inSeconds;
    final progress = total <= 0 ? 0.0 : left.inSeconds / total;
    final clock = left.inMinutes >= 60 ? '${left.inHours}h' : '${left.inMinutes < 1 ? 1 : left.inMinutes}m';
    if (paymentDue(b)) {
      return CourtTile(kind: TileKind.collect, title: playerName(b), subtitle: 'Pay at venue · due', clock: clock, progress: progress, booking: b);
    }
    if (left.inMinutes < endingMinutes) {
      final next = _nextStart(mine, myBlocks, end);
      return CourtTile(
        kind: TileKind.ending,
        title: playerName(b),
        subtitle: next == null ? 'Ends ${_clock(end)} · then free' : 'Next at ${_clock(next.$1)}',
        clock: clock,
        progress: progress,
        booking: b,
      );
    }
    return CourtTile(kind: TileKind.inPlay, title: playerName(b), subtitle: 'Till ${_clock(end)} · ${b['payment_status'] == 'paid' || !_blank(b['collection_method']) ? 'Paid' : 'Booked'}', clock: clock, progress: progress, booking: b);
  }

  final next = _nextStart(mine, myBlocks, now);
  return CourtTile(
    kind: TileKind.free,
    title: 'Add walk-in',
    subtitle: next == null ? 'Free for the rest of today' : 'Free till ${_clock(next.$1)}',
  );
}

/// Earliest booking or block starting at or after [from].
(DateTime, Map<String, dynamic>)? _nextStart(List<Map<String, dynamic>> bookings, List<Map<String, dynamic>> blocks, DateTime from) {
  (DateTime, Map<String, dynamic>)? best;
  for (final row in [...bookings, ...blocks]) {
    final start = _at(row['start_time']);
    if (start == null || start.isBefore(from)) continue;
    if (best == null || start.isBefore(best.$1)) best = (start, row);
  }
  return best;
}

/// Confirmed bookings not yet marked, still running or ahead, soonest first.
List<Map<String, dynamic>> arrivingNext(List<Map<String, dynamic>> bookings, DateTime now, {int limit = 4}) {
  final rows = bookings.where((b) {
    final end = _at(b['end_time']);
    return _confirmed(b) && _blank(b['attendance']) && end != null && now.isBefore(end);
  }).toList()
    ..sort((a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'));
  return rows.take(limit).toList();
}

/// Check-in opens 30 minutes before the start (same rule as the server's Attendance).
bool checkInOpen(Map<String, dynamic> booking, DateTime now) {
  final start = _at(booking['start_time']);
  return start != null && !now.isBefore(start.subtract(const Duration(minutes: 30)));
}

String startClock(Map<String, dynamic> booking) {
  final start = _at(booking['start_time']);
  return start == null ? '' : _clock(start);
}
