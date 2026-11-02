import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/occupancy_figures.dart';

void main() {
  test('occupancy rows stay keyed by venue', () {
    final rows = occupancyByVenue({
      'venues': [
        {'court_id': 4, 'booked_minutes': 90, 'open_minutes': 960, 'confirmed_count': 2},
        {'court_id': '8', 'booked_minutes': 0, 'open_minutes': 480, 'confirmed_count': 0},
      ],
    });
    expect(rows[4]!.bookedMinutes, 90);
    expect(rows[8]!.openMinutes, 480);
    expect(occupancyByVenue({'total_earned': 10}), isEmpty);
  });

  test('the line is booked time against open time', () {
    expect(
      occupancyLine(const TodayOccupancy(courtId: 1, bookedMinutes: 90, openMinutes: 960, confirmedCount: 2)),
      '1.5h booked of 16h open today',
    );
    expect(
      occupancyLine(const TodayOccupancy(courtId: 1, bookedMinutes: 0, openMinutes: 0, confirmedCount: 3)),
      '3 confirmed today',
    );
  });
}
