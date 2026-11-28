/// A venue row on the owner home list, either owned or assigned as staff.
class VenueListing {
  final Map<String, dynamic> court;
  final bool isOwner;
  final String? staffRole;

  const VenueListing({
    required this.court,
    required this.isOwner,
    this.staffRole,
  });

  int? get id => venueId(court);

  String get accessLabel {
    if (isOwner) return 'Owner';
    switch (staffRole) {
      case 'manager':
        return 'Staff · Manager';
      case 'viewer':
        return 'Staff · Viewer';
      default:
        return 'Staff';
    }
  }
}

/// What the signed-in user may do at a venue. Mirrors the server's StaffAccess:
/// managers run the desk; viewers only read the calendar and bookings;
/// venue settings, pricing, plans, staff and money stay with the owner.
class VenueAbilities {
  final bool owner;
  final bool manager;

  VenueAbilities({required this.owner, String? staffRole}) : manager = owner || staffRole == 'manager';

  /// Walk-ins, check-ins, blocks, customers, members, coaching and equipment.
  bool get desk => manager;

  /// Edit or delete the venue, pricing, plans, cancellation terms, staff, earnings and reports.
  bool get settings => owner;
}

int? venueId(Map<String, dynamic> court) {
  final raw = court['id'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

/// Owned venues win when the same court is also returned as a staff assignment.
List<VenueListing> mergeVenueListings({
  required List<Map<String, dynamic>> owned,
  required List<Map<String, dynamic>> assigned,
}) {
  final listings = <VenueListing>[];
  final seen = <int>{};

  for (final court in owned) {
    final id = venueId(court);
    if (id == null || id <= 0 || !seen.add(id)) continue;
    listings.add(VenueListing(court: court, isOwner: true));
  }

  for (final court in assigned) {
    final id = venueId(court);
    if (id == null || id <= 0 || !seen.add(id)) continue;
    listings.add(VenueListing(
      court: court,
      isOwner: false,
      staffRole: court['role']?.toString(),
    ));
  }

  return listings;
}
