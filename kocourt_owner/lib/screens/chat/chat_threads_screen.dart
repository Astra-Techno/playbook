import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'chat_screen.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    if (_threads.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    List<Map<String, dynamic>>? threads;
    try {
      final res = await Api().get('/messages/threads');
      threads = List<Map<String, dynamic>>.from(
        (res.data['threads'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load messages.');
    }
    if (!mounted) return;
    setState(() {
      if (threads != null) _threads = threads;
      _error = error;
      _loading = false;
    });
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _threadsBody(),
    );
  }

  Widget _threadsBody() {
    final phase = tabPhase(
      loading: _loading,
      failed: _error != null,
      hasData: _threads.isNotEmpty,
    );
    if (phase == TabPhase.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadThreads,
      color: AppColors.primary,
      child: phase == TabPhase.ready
          ? ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _threads.length + (_error != null ? 1 : 0),
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100], indent: 76),
              itemBuilder: (_, i) {
                if (_error != null && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: TabErrorBanner(message: _error!, onRetry: _loadThreads),
                  );
                }
                final thread = _threads[_error != null ? i - 1 : i];
                return _buildThread(thread);
              },
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (phase == TabPhase.failed)
                  TabErrorBanner(message: _error ?? 'Could not load messages.', onRetry: _loadThreads)
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: TabEmptyMessage(
                      icon: AppIcons.messageCircle,
                      title: 'No conversations yet',
                      subtitle: 'Messages from bookings will appear here',
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildThread(Map<String, dynamic> thread) {
    final unread = int.tryParse('${thread['unread_count'] ?? 0}') ?? 0;
    final hasUnread = unread > 0;
    final otherName = thread['other_user_name'] ?? 'Player';
    final otherAvatar = thread['other_user_avatar'];
    final courtName = thread['court_name'] ?? '';
    final lastMessage = thread['last_message'] ?? '';
    final lastAt = thread['last_at'];

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: thread['booking_id'],
              courtName: courtName,
              otherUserName: otherName,
              receiverId: thread['other_user_id'],
            ),
          ),
        ).then((_) => _loadThreads());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[200],
              backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
              child: otherAvatar == null
                  ? Text(
                      otherName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeAgo(lastAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.primary : Colors.grey[400],
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    courtName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? AppColors.textPrimary : Colors.grey[500],
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
