/// Extra seats the host asked for. The host already occupies one seat.
int matchSpotsLeft(int playersNeeded, int participantCount) {
  final needed = playersNeeded < 1 ? 1 : playersNeeded;
  final others = participantCount <= 0 ? 0 : participantCount - 1;
  final left = needed - others;
  return left < 0 ? 0 : left;
}

bool matchIsFull(int playersNeeded, int participantCount) =>
    matchSpotsLeft(playersNeeded, participantCount) == 0;

bool sameUser(dynamic a, dynamic b) {
  final left = int.tryParse('$a');
  final right = int.tryParse('$b');
  return left != null && left > 0 && left == right;
}

int? matchId(dynamic value) {
  final id = int.tryParse('$value');
  if (id == null || id < 1) return null;
  return id;
}
