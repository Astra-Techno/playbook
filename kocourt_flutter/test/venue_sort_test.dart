import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('nearby keeps the closest venue first', () {
    final rows = sortVenueRows([
      {'name': 'Far', 'distance_km': 8, 'avg_rating': 5},
      {'name': 'Near', 'distance_km': 1.2, 'avg_rating': 3},
      {'name': 'Unknown'},
    ], 'distance');
    expect(rows.map((row) => row['name']), ['Near', 'Far', 'Unknown']);
  });

  test('best review keeps the highest rating first', () {
    final rows = sortVenueRows([
      {'name': 'Quiet', 'avg_rating': 3, 'review_count': 20, 'distance_km': 1},
      {'name': 'Loved', 'avg_rating': 4.8, 'review_count': 2, 'distance_km': 9},
      {'name': 'Also loved', 'avg_rating': 4.8, 'review_count': 10, 'distance_km': 4},
    ], 'rating');
    expect(rows.map((row) => row['name']), ['Also loved', 'Loved', 'Quiet']);
  });
}
