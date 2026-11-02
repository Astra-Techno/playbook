String? attendanceLabel(dynamic raw) {
  switch ('$raw') {
    case 'checked_in':
      return 'Checked in';
    case 'no_show':
      return 'No-show';
    default:
      return null;
  }
}

bool attendanceUnmarked(Map<String, dynamic> booking) {
  final status = '${booking['status'] ?? ''}';
  final mark = '${booking['attendance'] ?? ''}'.trim();
  return status == 'confirmed' && mark.isEmpty;
}
