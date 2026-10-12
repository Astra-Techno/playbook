import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'group_info_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _group;
  bool _loading = true;
  bool _sending = false;
  int? _replyToId;
  String? _replyToContent;
  String? _replyToSender;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadGroup();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    try {
      final res = await Api().get('/chat/groups/${widget.groupId}');
      if (mounted) setState(() => _group = Map<String, dynamic>.from(res.data['group'] ?? {}));
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final res = await Api().get('/chat/groups/${widget.groupId}/messages');
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await Api().post('/chat/groups/${widget.groupId}/messages', data: {
        'content': text,
        if (_replyToId != null) 'reply_to': _replyToId,
      });
      HapticFeedback.lightImpact();
      _clearReply();
      await _loadMessages();
      _scrollToBottom();
    } catch (_) {}

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null) return;

    try {
      final formData = FormData.fromMap({'image': await MultipartFile.fromFile(file.path)});
      final res = await Api().dio.post('${Api.baseUrl}/upload', data: formData);
      final url = res.data['url']?.toString() ?? '';
      if (url.isEmpty) return;

      await Api().post('/chat/groups/${widget.groupId}/messages', data: {
        'content': '',
        'image_url': url,
      });
      await _loadMessages();
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _toggleReaction(int messageId, String emoji) async {
    try {
      await Api().post('/chat/messages/$messageId/reactions', data: {'emoji': emoji});
      HapticFeedback.selectionClick();
      _loadMessages();
    } catch (_) {}
  }

  void _setReply(Map<String, dynamic> msg) {
    setState(() {
      _replyToId = msg['id'];
      _replyToContent = msg['content']?.toString() ?? '📷 Photo';
      _replyToSender = msg['sender_name']?.toString() ?? '';
    });
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToContent = null;
      _replyToSender = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDm = _group?['type'] == 'dm';
    final members = List<Map<String, dynamic>>.from(_group?['members'] ?? []);

    // Title
    String title;
    String? subtitle;
    if (isDm) {
      final other = members.where((m) => m['id'] != auth.userId).firstOrNull;
      title = other?['name'] ?? 'Chat';
    } else {
      title = _group?['name'] ?? 'Group Chat';
      subtitle = '${members.length} members';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (_group != null) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => GroupInfoScreen(groupId: widget.groupId),
              )).then((_) => _loadGroup());
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!isDm)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(groupId: widget.groupId),
                )).then((_) => _loadGroup());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textDisabled),
                            const SizedBox(height: 12),
                            const Text('No messages yet', style: TextStyle(color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            const Text('Say hello! 👋', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
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
                          final showSender = !isDm && !isMe && (
                            i == 0 || _messages[i - 1]['sender_id'] != msg['sender_id']
                          );
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _dateBadge(msg['created_at']),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              _MessageBubble(
                                message: msg,
                                isMe: isMe,
                                showSender: showSender,
                                formatTime: _formatTime,
                                onReply: () => _setReply(msg),
                                onReact: (emoji) => _toggleReaction(msg['id'], emoji),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Reply preview
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyToSender ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        Text(_replyToContent ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReply,
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(color: Colors.white, boxShadow: AppShadows.bottomBar),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _sendImage,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.image_rounded, color: Colors.grey[500], size: 24),
                  ),
                ),
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
                        hintText: 'Type a message...',
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
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showSender;
  final String Function(String?) formatTime;
  final VoidCallback onReply;
  final void Function(String emoji) onReact;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.formatTime,
    required this.onReply,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content']?.toString() ?? '';
    final imageUrl = message['image_url']?.toString();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final reactions = List<Map<String, dynamic>>.from(message['reactions'] ?? []);

    // Group reactions by emoji
    final reactionMap = <String, List<String>>{};
    for (final r in reactions) {
      final emoji = r['emoji']?.toString() ?? '';
      reactionMap.putIfAbsent(emoji, () => []).add(r['user_name']?.toString() ?? '');
    }

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                  if (showSender && message['sender_name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message['sender_name'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.primary,
                        ),
                      ),
                    ),
                  // Reply quote
                  if (message['reply_content'] != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isMe ? Colors.white54 : AppColors.primary, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['reply_sender_name'] ?? '',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isMe ? Colors.white70 : AppColors.primary),
                          ),
                          Text(
                            message['reply_content'],
                            style: TextStyle(fontSize: 12, color: isMe ? Colors.white60 : Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  // Image
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl.startsWith('http') ? imageUrl : '${Api.baseUrl}/$imageUrl',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 48),
                        ),
                      ),
                    ),
                  // Text
                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    formatTime(message['created_at']),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textDisabled),
                  ),
                ],
              ),
            ),
            // Reactions
            if (reactionMap.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  children: reactionMap.entries.map((e) {
                    return GestureDetector(
                      onTap: () => onReact(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReact(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            if (message['content']?.toString().isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message['content']));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
