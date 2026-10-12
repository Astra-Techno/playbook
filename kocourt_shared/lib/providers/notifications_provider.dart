import 'package:flutter/material.dart';
import '../core/api.dart';

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String? courtName;
  final int? courtId;
  final String? createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.courtName,
    this.courtId,
    this.createdAt,
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      courtName: json['court_name'],
      courtId: json['court_id'],
      createdAt: json['created_at'],
      isRead: json['is_read'] == 1 || json['is_read'] == true || json['read_at'] != null,
    );
  }
}

class NotificationsProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  bool _loading = false;

  List<NotificationItem> get notifications => _notifications;
  bool get loading => _loading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetch(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await Api().get('/notifications/list');
      final list = res.data['notifications'] ?? [];
      _notifications = List<NotificationItem>.from(
        (list as List).map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e))),
      );
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> markRead(int notificationId) async {
    try {
      await Api().put('/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        _notifications[idx] = NotificationItem(
          id: _notifications[idx].id,
          title: _notifications[idx].title,
          body: _notifications[idx].body,
          courtName: _notifications[idx].courtName,
          courtId: _notifications[idx].courtId,
          createdAt: _notifications[idx].createdAt,
          isRead: true,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await Api().put('/notifications/read-all');
      _notifications = _notifications.map((n) => NotificationItem(
        id: n.id,
        title: n.title,
        body: n.body,
        courtName: n.courtName,
        courtId: n.courtId,
        createdAt: n.createdAt,
        isRead: true,
      )).toList();
      notifyListeners();
    } catch (_) {}
  }

  void clear() {
    _notifications = [];
    notifyListeners();
  }
}
