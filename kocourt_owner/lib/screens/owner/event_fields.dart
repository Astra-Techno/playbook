/// Bodies and labels for the organizer event screens.
library;

final _clock = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

List<Map<String, dynamic>> eventRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['tournaments'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}

List<Map<String, dynamic>> categoryRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['categories'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}

List<Map<String, dynamic>> registrationRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['registrations'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}

String registrationLabel(Object? state) {
  switch (state?.toString()) {
    case 'pending':
      return 'Pending';
    case 'pending_approval':
      return 'Pending approval';
    case 'confirmed':
      return 'Confirmed';
    case 'waitlisted':
      return 'Waitlisted';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}

String registrationLine(Map<String, dynamic> entry) {
  var line = 'Player ${entry['captain_user_id']} · ${registrationLabel(entry['state'])} · fee ${entry['fee_amount'] ?? 0}';
  final code = entry['check_in_code'];
  if (code != null && code.toString().trim().isNotEmpty) {
    line = '$line · $code';
  }
  final partners = entry['partners'];
  if (partners is List && partners.isNotEmpty) {
    line = '$line · with ${partners.join(', ')}';
  }
  final arrived = entry['checked_in_at'];
  if (arrived == null || arrived.toString().trim().isEmpty) return line;
  return '$line · Checked in';
}

final _doorCode = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

Map<String, dynamic>? checkInCodeBody(String code) {
  final value = code.trim().toUpperCase();
  if (!_doorCode.hasMatch(value)) return null;
  return {'code': value};
}

bool registrationCanCheckIn(Map<String, dynamic> entry) {
  final arrived = entry['checked_in_at'];
  final marked = arrived != null && arrived.toString().trim().isNotEmpty;
  return entry['state']?.toString() == 'confirmed' && !marked;
}

Map<String, dynamic>? announcementBody({required String title, required String body}) {
  final trimmedTitle = title.trim();
  final trimmedBody = body.trim();
  if (trimmedTitle.isEmpty || trimmedBody.isEmpty) return null;
  if (trimmedTitle.length > 120 || trimmedBody.length > 500) return null;
  return {'title': trimmedTitle, 'body': trimmedBody};
}

List<Map<String, dynamic>> announcementRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['announcements'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}

const participantExportHeader = 'Category,Player,State,Fee,Code,"Checked in"';

bool participantCsv(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return false;
  final firstLine = trimmed.split(RegExp(r'\r?\n')).first.trim();
  return firstLine == participantExportHeader;
}

String eventStatusLabel(Object? status) {
  switch (status?.toString()) {
    case 'draft':
      return 'Draft';
    case 'published':
      return 'Published';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}

/// `publish`, `unpublish`, or null when the screen has no status action.
String? eventAction(Object? status) {
  switch (status?.toString()) {
    case 'draft':
      return 'publish';
    case 'published':
      return 'unpublish';
    default:
      return null;
  }
}

Map<String, dynamic>? eventDraftBody({
  required String title,
  required String sport,
  String visibility = 'private',
  String courtId = '',
  String start = '',
  String end = '',
  String sponsor = '',
}) {
  final trimmedTitle = title.trim();
  final trimmedSport = sport.trim();
  if (trimmedTitle.isEmpty || trimmedSport.isEmpty) return null;
  if (trimmedTitle.length > 160 || trimmedSport.length > 60) return null;
  if (visibility != 'private' && visibility != 'public') return null;

  final body = <String, dynamic>{
    'title': trimmedTitle,
    'sport': trimmedSport,
    'visibility': visibility,
  };
  final court = courtId.trim();
  if (court.isNotEmpty) {
    final id = int.tryParse(court);
    if (id == null || id <= 0) return null;
    body['court_id'] = id;
  }
  final startTrim = start.trim();
  final endTrim = end.trim();
  if (startTrim.isNotEmpty) {
    if (!_clock.hasMatch(startTrim)) return null;
    body['start_time'] = startTrim;
  }
  if (endTrim.isNotEmpty) {
    if (!_clock.hasMatch(endTrim)) return null;
    body['end_time'] = endTrim;
  }
  if (startTrim.isNotEmpty && endTrim.isNotEmpty && endTrim.compareTo(startTrim) <= 0) {
    return null;
  }
  final sponsorTrim = sponsor.trim();
  if (sponsorTrim.length > 120) return null;
  if (sponsorTrim.isNotEmpty) body['sponsor_name'] = sponsorTrim;
  return body;
}

Map<String, dynamic>? categoryBody({
  required String name,
  String format = 'singles',
  String fee = '',
  String capacity = '',
  bool waitlist = false,
  bool approval = false,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.length > 120) return null;
  if (format != 'singles' && format != 'doubles' && format != 'team') return null;
  final body = <String, dynamic>{
    'name': trimmed,
    'format': format,
    'waitlist': waitlist,
    'approval': approval,
  };
  if (fee.trim().isNotEmpty) {
    final amount = double.tryParse(fee.trim());
    if (amount == null || amount < 0) return null;
    body['fee'] = amount;
  }
  if (capacity.trim().isNotEmpty) {
    final seats = int.tryParse(capacity.trim());
    if (seats == null || seats < 0) return null;
    body['capacity'] = seats;
  }
  return body;
}

List<Map<String, dynamic>> matchRows(Object? data) {
  if (data is! Map) return const [];
  final rows = data['matches'];
  if (rows is! List) return const [];
  return [
    for (final row in rows)
      if (row is Map)
        {
          'id': row['id'],
          'status': row['status'],
          'round_label': row['round_label'],
          'home_registration_id': row['home_registration_id'],
          'away_registration_id': row['away_registration_id'],
          'winner_registration_id': row['winner_registration_id'],
          'home_score': row['home_score'],
          'away_score': row['away_score'],
        },
  ];
}

Map<String, int>? matchBody({required int homeId, required int awayId}) {
  if (homeId <= 0 || awayId <= 0 || homeId == awayId) return null;
  return {'home_registration_id': homeId, 'away_registration_id': awayId};
}

Map<String, int>? resultBody({
  required int homeId,
  required int awayId,
  required String homeScore,
  required String awayScore,
}) {
  final home = int.tryParse(homeScore.trim());
  final away = int.tryParse(awayScore.trim());
  if (home == null || away == null || home < 0 || away < 0 || home == away) return null;
  if (homeId <= 0 || awayId <= 0 || homeId == awayId) return null;
  return {
    'home_score': home,
    'away_score': away,
    'winner_registration_id': home > away ? homeId : awayId,
  };
}

int? bracketChampion(Object? data) {
  if (data is! Map) return null;
  final raw = data['champion_registration_id'];
  if (raw == null) return null;
  final id = int.tryParse('$raw');
  if (id == null || id <= 0) return null;
  return id;
}

String championLine(int entryId) => 'Entry $entryId wins the category';

String matchLine(Map<String, dynamic> row) {
  final home = row['home_registration_id'];
  final away = row['away_registration_id'];
  final rawRound = row['round_label'];
  final round = rawRound == null ? '' : '$rawRound'.trim();
  final prefix = round.isEmpty ? '' : '$round · ';
  if (row['status'] == 'bye') {
    return '${prefix}Entry $home has a bye';
  }
  if (row['status'] == 'completed') {
    return '${prefix}Entry $home vs entry $away · ${row['home_score']}-${row['away_score']} · winner ${row['winner_registration_id']}';
  }
  return '${prefix}Entry $home vs entry $away · Scheduled';
}
