/// Whether a block row returned by `GET /blocked-slots` covers one hour.
///
/// Uses `applies_start` / `applies_end` when the server placed an annual
/// template on the requested date. This does not decide capacity.
DateTime? parseSqlDateTime(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.contains('T') ? text : text.replaceFirst(' ', 'T'));
}

bool intervalsOverlap({
  required String appliesStart,
  required String appliesEnd,
  required String slotStart,
  required String slotEnd,
}) {
  final blockStart = parseSqlDateTime(appliesStart);
  final blockEnd = parseSqlDateTime(appliesEnd);
  final start = parseSqlDateTime(slotStart);
  final end = parseSqlDateTime(slotEnd);
  if (blockStart == null || blockEnd == null || start == null || end == null) {
    return false;
  }
  return blockStart.isBefore(end) && blockEnd.isAfter(start);
}

/// A slot on today whose start is already behind [now] cannot be chosen.
bool slotStartHasPassed(String date, int hour, DateTime now) {
  final parts = date.split('-');
  if (parts.length != 3) return false;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return false;
  final start = DateTime(year, month, day, hour);
  return start.isBefore(now);
}

bool blockCoversSlot({
  required String appliesStart,
  required String appliesEnd,
  required String slotStart,
  required String slotEnd,
}) {
  return intervalsOverlap(
    appliesStart: appliesStart,
    appliesEnd: appliesEnd,
    slotStart: slotStart,
    slotEnd: slotEnd,
  );
}
