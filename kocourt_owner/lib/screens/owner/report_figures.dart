/// One venue's booking prices and collected payments. Payouts are not included.
class VenueReportFigures {
  final double bookingGross;
  final double collected;
  final int confirmedCount;
  final int cancelledCount;
  final double cancelRate;
  final int uniquePlayers;
  final int repeatPlayers;
  final String from;
  final String to;

  const VenueReportFigures({
    required this.bookingGross,
    required this.collected,
    required this.confirmedCount,
    required this.cancelledCount,
    required this.cancelRate,
    required this.uniquePlayers,
    required this.repeatPlayers,
    required this.from,
    required this.to,
  });
}

double _reportMoney(Object? value) => double.tryParse('$value') ?? 0;

int _reportCount(Object? value) => int.tryParse('$value') ?? 0;

VenueReportFigures? venueReport(Object? data) {
  if (data is! Map) return null;
  final report = data['report'];
  if (report is! Map) return null;
  if (!report.containsKey('booking_gross') || !report.containsKey('collected')) return null;
  return VenueReportFigures(
    bookingGross: _reportMoney(report['booking_gross']),
    collected: _reportMoney(report['collected']),
    confirmedCount: _reportCount(report['confirmed_count']),
    cancelledCount: _reportCount(report['cancelled_count']),
    cancelRate: _reportMoney(report['cancel_rate']),
    uniquePlayers: _reportCount(report['unique_players']),
    repeatPlayers: _reportCount(report['repeat_players']),
    from: '${data['from'] ?? ''}',
    to: '${data['to'] ?? ''}',
  );
}

String reportMoney(double amount) {
  final text = amount.toStringAsFixed(2);
  return 'Rs $text';
}
