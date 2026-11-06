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
