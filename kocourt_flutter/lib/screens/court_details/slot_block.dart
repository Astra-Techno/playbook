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
