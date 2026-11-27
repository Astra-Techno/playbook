import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart' show rupees;
import 'package:kocourt/screens/court_details/slot_timeline.dart';

Map<String, dynamic> slot(int h, {bool booked = false, bool past = false}) => {
      'start': '${h.toString().padLeft(2, '0')}:00',
      'end': '${(h + 1).toString().padLeft(2, '0')}:00',
      'key': '$h',
      'booked': booked,
      'blocked': false,
      'past': past,
    };

void main() {
  final slots = [slot(16, past: true), slot(17), slot(18), slot(19, booked: true), slot(20), slot(21)];
  final prices = {16: 300.0, 17: 300.0, 18: 300.0, 19: 300.0, 20: 450.0, 21: 450.0};

  test('price band groups equal hours and flags the dearer run as peak', () {
    final bands = priceBands(slots, prices, 300);
    expect(bands.map((b) => b.hours), [4, 2]);
    expect(bands.map((b) => b.peak), [false, true]);
    expect(priceBands(slots, const {}, 300).single.hours, 6);
  });

  test('drag stops at the first taken hour in either direction', () {
    expect(dragRange(slots, 1, 5), {'17', '18'});
    expect(dragRange(slots, 2, 0), {'18', '17'});
    expect(dragRange(slots, 4, 5), {'20', '21'});
  });

  test('quick lengths need every hour free', () {
    expect(extendFrom(slots, 1, 2), {'17', '18'});
    expect(extendFrom(slots, 1, 3), isNull);
    expect(extendFrom(slots, 5, 2), isNull);
  });

  test('total uses each hour price; label reads like a fixture', () {
    expect(selectionTotal(slots, {'18', '20'}, prices, 300), 750);
    expect(selectionLabel(slots, {'17', '18'}), '5 – 7 PM · 2 hrs');
    expect(selectionLabel(slots, {'17', '20'}), '2 hrs');
    expect(rupees(450), '₹450');
    expect(rupees(99.5), '₹99.50');
  });
}
