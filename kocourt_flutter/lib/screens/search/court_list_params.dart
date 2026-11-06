/// Query for `GET /courts` on the all-venues screen.
///
/// An empty search with sport All asks for the public list. A typed place
/// is sent as `location`. A sport other than All is sent as `type`.
Map<String, dynamic> courtListParams({String query = '', String type = 'All'}) {
  final params = <String, dynamic>{};
  final place = query.trim();
  if (place.isNotEmpty) params['location'] = place;
  if (type != 'All') params['type'] = type;
  return params;
}
