/// Matchday: notifications grouped per venue and day ("Kick Arena · Today · 3 updates").
/// Notifications without a venue (chat, account) stay on their own. Order follows the
/// newest notification in each group.
class NotificationGroup {
  NotificationGroup(this.courtName, this.day, this.items);
  final String? courtName;
  final String day; // "YYYY-MM-DD", or '' when unknown
  final List<Map<String, dynamic>> items;

  bool get single => items.length == 1;
}

List<NotificationGroup> groupNotifications(List<Map<String, dynamic>> list) {
  final byKey = <String, NotificationGroup>{};
  final order = <String>[];
  for (final n in list) {
    final created = '${n['created_at'] ?? ''}';
    final day = created.length >= 10 ? created.substring(0, 10) : '';
    final court = n['court_id'];
    final key = court == null || '$court'.isEmpty || day.isEmpty ? 'one:${n['id']}' : 'court:$court|$day';
    final group = byKey[key];
    if (group == null) {
      byKey[key] = NotificationGroup(n['court_name'] as String?, day, [n]);
      order.add(key);
    } else {
      group.items.add(n);
    }
  }
  return [for (final k in order) byKey[k]!];
}

/// "Today", "Yesterday" or "Tue 25 Nov" for a group's day.
String groupDayLabel(String day, DateTime now) {
  final d = DateTime.tryParse(day);
  if (d == null) return '';
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}
