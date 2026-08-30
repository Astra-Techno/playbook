import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class SlotChatScreen extends StatefulWidget {
  final int courtId;
  final String date;
  final String time;
  final String? courtName;
  final String? slotLabel;

  const SlotChatScreen({
    super.key,
    required this.courtId,
    required this.date,
    required this.time,
    this.courtName,
    this.slotLabel,
  });

  @override
  State<SlotChatScreen> createState() => _SlotChatScreenState();
}

class _SlotChatScreenState extends State<SlotChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMembers();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await Api().get('/slot-chat/messages', params: {
        'court_id': widget.courtId,
        'date': widget.date,
        'time': widget.time,
      });
      final msgs = List<Map<String, dynamic>>.from(
        (res.data['messages'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      if (mounted) {
        final wasAtBottom = !_scrollController.hasClients ||
            _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50;
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        if (wasAtBottom && msgs.isNotEmpty) _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await Api().get('/slot-chat/members', params: {
        'court_id': widget.courtId,
        'date': widget.date,
        'time': widget.time,
      });
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(
            (res.data['members'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await Api().post('/slot-chat/messages', data: {
        'court_id': widget.courtId,
        'date': widget.date,
        'time': widget.time,
        'body': text,
      });
      HapticFeedback.lightImpact();
      await _loadMessages();
      _scrollToBottom();
    } catch (_) {}

    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(
              'Players in this slot',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              '${_members.length} member${_members.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ..._members.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: m['avatar_url'] != null && m['avatar_url'].toString().isNotEmpty
                        ? NetworkImage(m['avatar_url'])
                        : null,
                    child: m['avatar_url'] == null || m['avatar_url'].toString().isEmpty
                        ? Text(
                            (m['name'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        if (m['skill_level'] != null && m['skill_level'].toString().isNotEmpty)
                          Text(
                            m['skill_level'],
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (m['member_type'] == 'owner')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Owner',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final h = date.hour;
    final m = date.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }

  bool _differentDay(String? a, String? b) {
    if (a == null || b == null) return true;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return true;
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final title = widget.courtName ?? 'Slot Chat';
    final subtitle = widget.slotLabel ?? '${widget.date} ${widget.time}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          GestureDetector(
            onTap: _showMembers,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${_members.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Members strip
          if (_members.isNotEmpty)
            Container(
              height: 52,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final m = _members[i];
                  final name = m['name'] ?? '?';
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: m['avatar_url'] != null && m['avatar_url'].toString().isNotEmpty
                              ? NetworkImage(m['avatar_url'])
                              : null,
                          child: m['avatar_url'] == null || m['avatar_url'].toString().isEmpty
                              ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name.split(' ').first,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            const Text('No messages yet', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text(
                              'Say hi to your fellow players!',
                              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isMe = msg['sender_id'] == auth.userId;
                          final showDate = i == 0 || _differentDay(
                            _messages[i - 1]['created_at'],
                            msg['created_at'],
                          );
                          // Show sender name for group: show if different from previous sender
                          final showName = !isMe && (i == 0 || _messages[i - 1]['sender_id'] != msg['sender_id']);
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _dateBadge(msg['created_at']),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600),
                                  ),
                                ),
                              _GroupMessageBubble(
                                message: msg,
                                isMe: isMe,
                                showName: showName,
                                formatTime: _formatTime,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: AppShadows.bottomBar,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Message the group...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateBadge(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showName;
  final String Function(String?) formatTime;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    required this.showName,
    required this.formatTime,
  });

  // Generate a stable color from sender name
  Color _senderColor(String name) {
    final colors = [
      const Color(0xFF1976D2),
      const Color(0xFF388E3C),
      const Color(0xFFE64A19),
      const Color(0xFF7B1FA2),
      const Color(0xFF00838F),
      const Color(0xFFC62828),
      const Color(0xFF4527A0),
      const Color(0xFF00695C),
    ];
    final hash = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final senderName = message['sender_name'] ?? 'Unknown';
    final color = _senderColor(senderName);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 4, top: showName ? 8 : 0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: isMe ? null : AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            Text(
              message['body'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatTime(message['created_at']),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
