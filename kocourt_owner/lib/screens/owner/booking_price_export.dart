/// `GET /earnings/export` for one venue's confirmed booking prices.
class BookingPriceExport {
  static const header = 'Date,Space,Player,Start,End,Hours,Amount (Rs)';

  final int courtId;
  final String? from;
  final String? to;

  const BookingPriceExport({required this.courtId, this.from, this.to});

  Map<String, dynamic> get query {
    return {
      'court_id': courtId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
  }
}

final _exportDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

BookingPriceExport? bookingPriceExport({
  required int courtId,
  String? from,
  String? to,
}) {
  if (courtId <= 0) return null;
  if (from != null && !_exportDay.hasMatch(from)) return null;
  if (to != null && !_exportDay.hasMatch(to)) return null;
  if (from != null && to != null && from.compareTo(to) > 0) return null;
  return BookingPriceExport(courtId: courtId, from: from, to: to);
}

bool bookingPriceCsv(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return false;
  final firstLine = trimmed.split(RegExp(r'\r?\n')).first.trim();
  return firstLine == BookingPriceExport.header;
}
