/// Matchday formatting shared by both apps: money without stray decimals,
/// friendly days and compact time ranges. Use these instead of raw values.
library;

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "₹500", "₹1,200", "₹99.50"; empty for null or non-numbers.
String rupees(Object? value) {
  final n = num.tryParse('${value ?? ''}'.replaceAll(',', ''));
  if (n == null) return '';
  final whole = n == n.roundToDouble();
  final fixed = whole ? n.round().toString() : n.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0].replaceFirst('-', '');
  // Indian grouping: last three digits, then pairs (1,20,000).
  var grouped = digits;
  if (digits.length > 3) {
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    grouped = '${head.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},')},$tail';
  }
  return '${n < 0 ? '-' : ''}₹$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// "Today", "Tomorrow", "Yesterday" or "Wed 26 Nov" (with the year when it differs).
String friendlyDay(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(day.year, day.month, day.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final base = '${_days[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
  return day.year == n.year ? base : '$base ${day.year}';
}

/// "6 PM", "6:30 PM" from "18:00:00", "18:30" or a DateTime.
String clock(Object? time) {
  int? h, m;
  if (time is DateTime) {
    h = time.hour;
    m = time.minute;
  } else {
    final p = '${time ?? ''}'.split(' ').last.split(':');
    if (p.length >= 2) {
      h = int.tryParse(p[0]);
      m = int.tryParse(p[1]);
    }
  }
  if (h == null || m == null) return '';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

/// "6–7 PM", "11 AM–1 PM", "6:30–8 PM".
String clockRange(Object? start, Object? end) {
  final a = clock(start), b = clock(end);
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  final sameHalf = a.substring(a.length - 2) == b.substring(b.length - 2);
  return '${sameHalf ? a.substring(0, a.length - 3) : a}–$b';
}

/// "now", "5m", "2h", "3d", then the friendly day (for posts, comments, chats).
String timeAgo(Object? when, {DateTime? now}) {
  final t = when is DateTime ? when : DateTime.tryParse('${when ?? ''}'.replaceFirst(' ', 'T'));
  if (t == null) return '';
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return friendlyDay(t, now: n);
}
