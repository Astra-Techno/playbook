import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/matches/match_roster.dart';

void main() {
  test('another player can join a match the host just created', () {
    expect(matchSpotsLeft(1, 1), 1);
    expect(matchIsFull(1, 1), isFalse);
    expect(matchIsFull(1, 2), isTrue);
    expect(matchSpotsLeft(2, 1), 2);
  });

  test('user ids from the api match the signed-in player', () {
    expect(sameUser('4', 4), isTrue);
    expect(sameUser('4', 9), isFalse);
    expect(sameUser(null, 4), isFalse);
  });

  test('a string match id can be joined', () {
    expect(matchId('12'), 12);
    expect(matchId(0), isNull);
  });
}
