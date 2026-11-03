/// Coaching and equipment can be hidden. Booking screens stay available.
class ReleaseFlags {
  final bool coaching;
  final bool equipment;

  const ReleaseFlags({this.coaching = true, this.equipment = true});

  bool shows(String feature) {
    switch (feature) {
      case 'coaching':
        return coaching;
      case 'equipment':
        return equipment;
      default:
        return true;
    }
  }
}

const releaseFlags = ReleaseFlags();
