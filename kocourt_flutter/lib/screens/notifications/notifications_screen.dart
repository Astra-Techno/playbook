import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

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
      final res = await Api().get('/user-notifications');
      _notifications = List<Map<String, dynamic>>.from(
        (res.data['notifications'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    try {
      await Api().put('/user-notifications/$id/read');
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

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.bell, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      Text('You\'re all caught up', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
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
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
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
                            color: isRead ? Colors.grey[50] : AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: isRead ? null : Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_getIcon(n['type']), size: 18, color: AppColors.primary),
                              ),
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
                                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                    ),
                                    if (n['court_name'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        n['court_name'],
                                        style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(n['created_at']),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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
}
