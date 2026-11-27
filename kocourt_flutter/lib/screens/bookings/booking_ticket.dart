import '../home/home_logic.dart' show kickoffIn;

/// Countdown line on the pass: before, during and after the game.
String passCountdown(DateTime? start, DateTime? end, DateTime now) {
  if (start == null) return '';
  if (now.isBefore(start)) return 'Kick-off in ${kickoffIn(start.difference(now))}';
  if (end != null && now.isBefore(end)) return 'Live now · ends in ${kickoffIn(end.difference(now))}';
  return 'Full time';
}

class BookingTicket {
  final int id;
  final String venue;
  final String place;
  final String date;
  final String time;
  final String space;
  final String amount;
  final String status;

  const BookingTicket({
    required this.id,
    required this.venue,
    required this.place,
    required this.date,
    required this.time,
    required this.space,
    required this.amount,
    required this.status,
  });
}

List<int> bookingIdsFromVerify(Map<String, dynamic>? data) {
  final raw = data?['booking_ids'];
  if (raw is! List) return [];
  final ids = <int>[];
  for (final item in raw) {
    final id = int.tryParse('$item') ?? 0;
    if (id > 0) ids.add(id);
  }
  return ids;
}

String _clock(String raw) {
  final match = RegExp(r'(\d{2}):(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  var hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute $suffix';
}

String _day(String raw) {
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final month = int.tryParse(match.group(2)!) ?? 1;
  final day = int.tryParse(match.group(3)!) ?? 1;
  return '$day ${months[month - 1]} ${match.group(1)}';
}

BookingTicket ticketFromBooking(Map<String, dynamic> booking) {
  final start = '${booking['start_time'] ?? ''}';
  final end = '${booking['end_time'] ?? ''}';
  final amount = booking['total_price'] ?? booking['amount'];
  final space = '${booking['space_name'] ?? booking['sub_court_name'] ?? ''}'.trim();
  return BookingTicket(
    id: int.tryParse('${booking['id']}') ?? 0,
    venue: '${booking['court_name'] ?? 'Venue'}',
    place: '${booking['court_location'] ?? booking['location'] ?? ''}'.trim(),
    date: _day(start.isNotEmpty ? start : '${booking['date'] ?? ''}'),
    time: end.isEmpty ? _clock(start) : '${_clock(start)} – ${_clock(end)}',
    space: space,
    amount: amount == null || '$amount'.isEmpty ? '' : '₹$amount',
    status: '${booking['status'] ?? 'confirmed'}',
  );
}

/// Rounded-up share per player, or null when there is no price or nobody yet.
int? perHeadRupees(Object? totalPrice, int players) {
  final total = num.tryParse('${totalPrice ?? ''}') ?? 0;
  if (total <= 0 || players <= 0) return null;
  return (total / players).ceil();
}

/// WhatsApp invite for the squad: venue, time, share, map and join links.
String squadInviteText(BookingTicket t, {required int players, int? perHead, Object? courtId, int open = 0}) {
  final where = [t.venue, t.place].where((s) => s.isNotEmpty).join(', ');
  final map = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': where});
  return [
    'Game on: ${t.venue}${t.space.isNotEmpty ? ' (${t.space})' : ''}',
    '${t.date} · ${t.time}',
    [
      '$players in${open > 0 ? ', $open spot${open == 1 ? '' : 's'} open' : ''}',
      if (perHead != null) '₹$perHead each',
    ].join(' · '),
    'Map: $map',
    if (courtId != null) 'Join on KoCourt: https://www.kocourt.com/court/$courtId',
  ].join('\n');
}

/// Default text for an opt-in game recap post (the player edits it before posting).
String recapText(BookingTicket t, {required int players, int? minutes}) {
  final parts = [
    'Played at ${t.venue}${t.space.isNotEmpty ? ' (${t.space})' : ''}',
    if (minutes != null && minutes > 0) '$minutes min',
    if (players > 1) 'squad of $players',
  ];
  return '${parts.join(' · ')}. Good game!';
}
