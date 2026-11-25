import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/providers/toast_provider.dart';
import 'package:kocourt_shared/providers/venue_provider.dart';

void main() {
  final rows = [
    {'name': 'AJ Cricket', 'location': 'Sivakasi', 'type': 'cricket', 'hourly_rate': '300.00', 'avg_rating': 4.5},
    {'name': 'Mahesh Foot Ball', 'location': 'Madurai', 'type': 'turf', 'hourly_rate': '800.00', 'avg_rating': null},
  ];

  test('search matches name, location and sport label', () {
    expect(filterVenueRows(rows, query: 'aj').length, 1);
    expect(filterVenueRows(rows, query: 'madurai').single['name'], 'Mahesh Foot Ball');
    expect(filterVenueRows(rows, query: 'Football').single['type'], 'turf');
    expect(filterVenueRows(rows, query: 'zzz'), isEmpty);
  });

  test('price and rating filters apply', () {
    expect(filterVenueRows(rows, maxPrice: 500).single['name'], 'AJ Cricket');
    expect(filterVenueRows(rows, minPrice: 500).single['name'], 'Mahesh Foot Ball');
    expect(filterVenueRows(rows, minRating: 4).single['name'], 'AJ Cricket');
    expect(filterVenueRows(rows).length, 2);
  });

  test('identical toast shown once', () {
    final toasts = ToastProvider()
      ..error('No KoCourt account')
      ..error('No KoCourt account')
      ..success('No KoCourt account');
    expect(toasts.toasts.length, 2);
  });
}
