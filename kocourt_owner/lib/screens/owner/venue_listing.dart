/// Owner-only venue actions and the listing labels the customer app already uses.
///
/// Public search shows a venue when `claim_status` is null or `approved`.
/// `is_verified` is a KoCourt badge. Owners cannot set it.
int? asVenueId(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

bool venueOwnedBy(Map<String, dynamic> court, int? userId) {
  if (userId == null) return false;
  return asVenueId(court['owner_id']) == userId;
}

bool venueIsVerified(dynamic value) {
  return value == true || value == 1 || value == '1';
}

/// What the player app does with this venue. Not a control the owner can flip.
String venueListingLabel(dynamic claimStatus) {
  switch (claimStatus) {
    case 'pending':
      return 'Not listed for players. This claim is waiting for review.';
    case 'rejected':
      return 'Not listed for players. This claim was rejected.';
    case 'approved':
    case null:
      return 'Listed for players.';
    default:
      return 'Not listed for players.';
  }
}

String venueVerificationLabel(dynamic isVerified) {
  if (venueIsVerified(isVerified)) return 'Verified by KoCourt.';
  return 'Not verified. Only KoCourt can verify a venue.';
}

Map<String, dynamic> courtPhotoBody({
  required int courtId,
  required String url,
  required int sortOrder,
}) {
  final trimmed = url.trim();
  if (courtId <= 0 || trimmed.isEmpty) {
    throw ArgumentError('court id and photo url are required');
  }
  return {
    'court_id': courtId,
    'url': trimmed,
    'sort_order': sortOrder < 0 ? 0 : sortOrder,
  };
}
