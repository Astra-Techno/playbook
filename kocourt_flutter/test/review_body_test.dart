import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:kocourt/screens/reviews/past_booking.dart';

void main() {
  test('review body sends the venue and rating without a zero booking', () {
    final body = reviewRequestBody(
      courtId: 12,
      rating: 5,
      comment: '  Smooth court  ',
      userId: 0,
      bookingId: 0,
    );
    expect(body['court_id'], 12);
    expect(body['rating'], 5);
    expect(body['comment'], 'Smooth court');
    expect(body.containsKey('user_id'), isFalse);
    expect(body.containsKey('booking_id'), isFalse);
  });

  test('my reviews ask for the player, not a court', () {
    expect(reviewListParams(), {'mine': 1});
    expect(reviewListParams(courtId: 0), {'mine': 1});
    expect(reviewListParams(courtId: 6), {'court_id': 6});
  });

  test('a completed booking at the venue is attached', () {
    final id = pastBookingId([
      {'id': '4', 'court_id': '9', 'status': 'confirmed', 'start_time': '2026-11-01 18:00:00'},
      {'id': '8', 'court_id': '9', 'status': 'confirmed', 'start_time': '2026-11-06 18:00:00'},
      {'id': '9', 'court_id': '9', 'status': 'cancelled', 'start_time': '2026-11-07 18:00:00'},
    ], 9, DateTime(2026, 11, 7, 12));
    expect(id, 8);
  });
}
