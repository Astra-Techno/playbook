import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'notification_groups.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/notifications/list');
      _notifications = List<Map<String, dynamic>>.from(
        (res.data['notifications'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    try {
      await Api().put('/notifications/$id/read');
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx >= 0) {
        _notifications[idx]['read_at'] = DateTime.now().toIso8601String();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _isRead(Map<String, dynamic> n) {
    return n['read_at'] != null || n['is_read'] == 1 || n['is_read'] == true;
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'booking': return AppIcons.calendarDays;
      case 'subscription': return AppIcons.award;
      case 'venue': return AppIcons.mapPin;
      case 'invite': return AppIcons.users;
      default: return AppIcons.bell;
    }
  }

  String _timeAgo(String? dateStr) => timeAgo(dateStr);

  @override
  Widget build(BuildContext context) {
    final groups = groupNotifications(_notifications);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.bell, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text('You\'re all caught up', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loading = true);
                    await _load();
                  },
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      if (g.single) return _tile(g.items.first);
                      final unread = g.items.where((n) => !_isRead(n)).length;
                      // Matchday: one card per venue and day.
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KoCard(
                          kicker: groupDayLabel(g.day, DateTime.now()),
                          title: g.courtName ?? 'Updates',
                          meta: '${g.items.length} updates',
                          badge: unread > 0 ? '$unread new' : null,
                          middle: Column(
                            children: [
                              for (final n in g.items)
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _isRead(n) ? null : () {
                                    HapticFeedback.lightImpact();
                                    _markRead(n['id']);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _isRead(n) ? AppColors.border : AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${n['title'] ?? ''}', style: TextStyle(fontSize: 13.5, fontWeight: _isRead(n) ? FontWeight.w600 : FontWeight.w800)),
                                              if ('${n['body'] ?? ''}'.isNotEmpty)
                                                Text('${n['body']}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_timeAgo(n['created_at']), style: AppFonts.score(fontSize: 12, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final isRead = _isRead(n);
    return GestureDetector(
      onTap: () {
        if (!isRead) {
          HapticFeedback.lightImpact();
          _markRead(n['id']);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MenuIcon(_getIcon(n['type'])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] ?? '',
                    style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body'] ?? '',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (n['court_name'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      n['court_name'],
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(n['created_at']),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (!isRead) const StatusTag('New'),
          ],
        ),
      ),
    );
  }
}
