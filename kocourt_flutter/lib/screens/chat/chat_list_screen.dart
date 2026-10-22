import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'group_chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/chat/groups');
      _groups = List<Map<String, dynamic>>.from(
        (res.data['groups'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _openNewChat() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (result != null && mounted) {
      _load();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: result)),
      );
    }
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
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewChat,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _groups.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100], indent: 76),
                    itemBuilder: (_, i) => _buildGroupTile(_groups[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No conversations yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text('Tap + to start a new chat', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final isDm = group['type'] == 'dm';
    final unread = int.tryParse('${group['unread_count'] ?? 0}') ?? 0;
    final hasUnread = unread > 0;
    final memberCount = int.tryParse('${group['member_count'] ?? 0}') ?? 0;

    // Display name & avatar
    String name;
    String? avatarUrl;
    if (isDm && group['dm_user'] != null) {
      name = group['dm_user']['name'] ?? 'User';
      avatarUrl = group['dm_user']['avatar_url'];
    } else {
      name = group['name'] ?? 'Group';
      avatarUrl = group['icon_url'];
    }

    final lastMsg = group['last_message'] ?? '';
    final lastAt = group['last_message_at'];
    final lastSender = group['last_message_sender'] ?? '';
    final lastImage = group['last_message_image'];

    String subtitle;
    if (lastMsg.toString().isNotEmpty) {
      subtitle = isDm ? lastMsg : '$lastSender: $lastMsg';
    } else if (lastImage != null && lastImage.toString().isNotEmpty) {
      subtitle = isDm ? '📷 Photo' : '$lastSender: 📷 Photo';
    } else {
      subtitle = isDm ? 'Start chatting' : 'No messages yet';
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: group['id'])),
        ).then((_) => _load());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: isDm ? Colors.grey[200] : AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? isDm
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                        )
                      : const Icon(Icons.group_rounded, color: AppColors.primary, size: 24)
                  : null,
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(fontSize: 15, fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isDm) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('$memberCount', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lastAt != null)
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (group['muted'] == 1) ...[
                        Icon(Icons.notifications_off_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
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
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
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
