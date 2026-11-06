/// Body for POST /reviews. The signed-in player is taken from the token.
Map<String, dynamic> reviewRequestBody({
  required int courtId,
  required int rating,
  String comment = '',
  int? bookingId,
  int? userId,
}) {
  return {
    'court_id': courtId,
    'rating': rating,
    'comment': comment.trim(),
    if (userId != null && userId > 0) 'user_id': userId,
    if (bookingId != null && bookingId > 0) 'booking_id': bookingId,
  };
}

/// My Reviews lists the signed-in player. A positive court id lists that venue.
Map<String, dynamic> reviewListParams({int? courtId}) {
  if (courtId != null && courtId > 0) {
    return {'court_id': courtId};
  }
  return {'mine': 1};
}

int? positiveId(dynamic value) {
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null || parsed < 1) return null;
  return parsed;
}
