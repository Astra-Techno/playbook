import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/earnings_figures.dart';

void main() {
  test('collected and paid out stay separate', () {
    final split = moneySplit({
      'total_earned': 1000,
      'total_paid_out': 400,
      'not_yet_paid_out': 600,
    });
    expect(split, isNotNull);
    expect(split!.collected, 1000);
    expect(split.paidOut, 400);
    expect(split.notYetPaidOut, 600);
  });

  test('a payout above collected stays negative', () {
    final split = moneySplit({
      'total_earned': '100',
      'total_paid_out': '250',
      'not_yet_paid_out': -150,
    });
    expect(split!.notYetPaidOut, -150);
  });

  test('today collected requires the owner payment summary', () {
    final day = dayCollected({
      'total_earned': 1000,
      'today': 80,
      'this_week': 240,
    });
    expect(day!.today, 80);
    expect(day.thisWeek, 240);
    expect(dayCollected({'total': 500, 'today': 40, 'this_week': 80}), isNull);
  });

  test('booking prices are not a payout summary', () {
    expect(moneySplit({'total': 500, 'today': 40, 'this_week': 80}), isNull);
  });

  test('payout rows are their own list', () {
    expect(payoutRows([
      {'id': 1, 'amount': 400, 'note': 'October'},
    ]).single['amount'], 400);
    expect(payoutRows(null), isEmpty);
  });
}
