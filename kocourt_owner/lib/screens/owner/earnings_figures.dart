/// Collected payments and payouts from `GET /earnings`.
///
/// A venue booking-price summary does not include these keys.
class MoneySplit {
  final double collected;
  final double paidOut;
  final double notYetPaidOut;

  const MoneySplit({
    required this.collected,
    required this.paidOut,
    required this.notYetPaidOut,
  });
}

double _money(dynamic value) => double.tryParse('$value') ?? 0;

MoneySplit? moneySplit(Map<String, dynamic> summary) {
  if (!summary.containsKey('total_earned') || !summary.containsKey('total_paid_out')) {
    return null;
  }
  final collected = _money(summary['total_earned']);
  final paidOut = _money(summary['total_paid_out']);
  final remainder = summary.containsKey('not_yet_paid_out')
      ? _money(summary['not_yet_paid_out'])
      : collected - paidOut;
  return MoneySplit(collected: collected, paidOut: paidOut, notYetPaidOut: remainder);
}

/// Today's collected payments from `GET /earnings`.
///
/// A venue booking-price summary has `today` without `total_earned`, so it
/// does not count as collected money.
class DayCollected {
  final double today;
  final double thisWeek;

  const DayCollected({required this.today, required this.thisWeek});
}

DayCollected? dayCollected(Map<String, dynamic> summary) {
  if (!summary.containsKey('total_earned') ||
      !summary.containsKey('today') ||
      !summary.containsKey('this_week')) {
    return null;
  }
  return DayCollected(
    today: _money(summary['today']),
    thisWeek: _money(summary['this_week']),
  );
}

List<Map<String, dynamic>> payoutRows(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
}
