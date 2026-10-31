/// Values the owner app may write onto `sub_courts`.
///
/// The API only accepts `exclusive` and `shared`. Other names stay out of
/// the payload so a new label cannot overwrite the stored mode.
const spaceBookingModes = ['exclusive', 'shared'];

class SpaceFieldError implements Exception {
  final String message;
  const SpaceFieldError(this.message);
}

int? asSpaceId(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

String spaceModeLabel(dynamic mode, dynamic capacity) {
  if (mode == 'shared') {
    final cap = asSpaceId(capacity) ?? 1;
    return 'Shared · $cap at a time';
  }
  return 'Exclusive';
}

Map<String, dynamic>? spaceRecord(dynamic data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final nested = map['space'] ?? map['sub_court'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  if (map['id'] != null && map['name'] != null) return map;
  return null;
}

/// Body for `POST /sub-courts` and `PUT /sub-courts/:id`.
///
/// An empty hourly rate is sent as an empty string so the API stores null.
Map<String, dynamic> spaceWriteBody({
  int? courtId,
  required String name,
  required String description,
  required String capacityText,
  required String hourlyRateText,
  required String bookingMode,
}) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    throw const SpaceFieldError('Enter a name.');
  }
  if (!spaceBookingModes.contains(bookingMode)) {
    throw const SpaceFieldError('Choose exclusive or shared.');
  }
  final capacity = int.tryParse(capacityText.trim());
  if (capacity == null || capacity < 1) {
    throw const SpaceFieldError('Capacity must be at least 1.');
  }
  final rateText = hourlyRateText.trim();
  if (rateText.isNotEmpty && double.tryParse(rateText) == null) {
    throw const SpaceFieldError('Enter a valid hourly rate.');
  }

  final body = <String, dynamic>{
    'name': trimmedName,
    'description': description.trim(),
    'capacity': capacity,
    'booking_mode': bookingMode,
    'hourly_rate': rateText.isEmpty ? '' : double.parse(rateText),
  };
  if (courtId != null) body['court_id'] = courtId;
  return body;
}
