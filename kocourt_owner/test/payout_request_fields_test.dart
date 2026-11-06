import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/payout_request_fields.dart';

void main() {
  test('a payout request sends an amount and does not send a blank note', () {
    expect(payoutRequestBody(amountText: '250.5', note: '  bank  '), {'amount': 250.5, 'note': 'bank'});
    expect(payoutRequestBody(amountText: '10'), {'amount': 10});
    expect(() => payoutRequestBody(amountText: '0'), throwsA(isA<PayoutRequestError>()));
  });

  test('an open request is the one still marked requested', () {
    final open = openPayoutRequest([
      {'id': 1, 'status': 'paid', 'amount': 10},
      {'id': 2, 'status': 'requested', 'amount': 40},
    ]);
    expect(open?['id'], 2);
    expect(openPayoutRequest([{'status': 'paid'}]), isNull);
  });
}
