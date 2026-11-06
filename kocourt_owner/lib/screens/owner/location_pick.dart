class PickedPlace {
  final String label;
  final double lat;
  final double lng;

  const PickedPlace({required this.label, required this.lat, required this.lng});
}

bool locationReady(String label, double? lat, double? lng) {
  return label.trim().isNotEmpty && lat != null && lng != null;
}

String placeLabel(Map<String, dynamic> place) {
  final addr = place['address'] is Map ? Map<String, dynamic>.from(place['address'] as Map) : <String, dynamic>{};
  final city = '${addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? ''}'.trim();
  final state = '${addr['state'] ?? ''}'.trim();
  if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
  final display = '${place['display_name'] ?? ''}'.trim();
  if (display.isEmpty) return 'Selected location';
  return display.split(',').take(2).join(',').trim();
}

PickedPlace? placeFromSearch(Map<String, dynamic> place) {
  final lat = double.tryParse('${place['lat']}');
  final lng = double.tryParse('${place['lon'] ?? place['lng']}');
  if (lat == null || lng == null) return null;
  final label = placeLabel(place);
  if (label.isEmpty) return null;
  return PickedPlace(label: label, lat: lat, lng: lng);
}
