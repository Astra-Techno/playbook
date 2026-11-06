class PayoutRequestError implements Exception {
  final String message;
  const PayoutRequestError(this.message);
}

Map<String, dynamic> payoutRequestBody({required String amountText, String note = ''}) {
  final amount = double.tryParse(amountText.trim());
  if (amount == null || amount <= 0) {
    throw const PayoutRequestError('Enter an amount greater than zero.');
  }
  final trimmed = note.trim();
  if (trimmed.length > 200) {
    throw const PayoutRequestError('Keep the note to 200 characters.');
  }
  return {
    'amount': amount,
    if (trimmed.isNotEmpty) 'note': trimmed,
  };
}

Map<String, dynamic>? openPayoutRequest(dynamic raw) {
  if (raw is! List) return null;
  for (final row in raw) {
    if (row is Map && '${row['status']}' == 'requested') {
      return Map<String, dynamic>.from(row);
    }
  }
  return null;
}
