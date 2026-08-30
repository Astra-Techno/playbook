import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final int bookingId;
  final String? courtName;
  final String? otherUserName;
  final int? receiverId;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.courtName,
    this.otherUserName,
    this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;
  int? _receiverId;

  @override
  void initState() {
    super.initState();
    _receiverId = widget.receiverId;
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

  Future<void> _loadMessages() async {
    try {
      final res = await Api().get('/messages', params: {'booking_id': widget.bookingId});
      final msgs = List<Map<String, dynamic>>.from(
        (res.data['messages'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      if (mounted) {
        // Auto-detect receiver from messages if not provided
        if (_receiverId == null && msgs.isNotEmpty) {
          final auth = context.read<AuthProvider>();
          for (final msg in msgs) {
            if (msg['sender_id'] != auth.userId) {
              _receiverId = msg['sender_id'];
              break;
            }
            if (msg['receiver_id'] != auth.userId) {
              _receiverId = msg['receiver_id'];
              break;
            }
          }
        }
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

  Future<void> _resolveReceiver() async {
    if (_receiverId != null) return;
    // Try to get the other party from the booking details
    try {
      final res = await Api().get('/bookings/${widget.bookingId}');
      final booking = res.data['booking'] ?? res.data;
      final auth = context.read<AuthProvider>();
      final bookingUserId = booking['user_id'];
      final ownerId = booking['owner_id'];
      if (bookingUserId == auth.userId) {
        _receiverId = ownerId;
      } else {
        _receiverId = bookingUserId;
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    // Resolve receiver if not known yet
    await _resolveReceiver();
    if (_receiverId == null) {
      return;
    }

    setState(() => _sending = true);
    _controller.clear();

    try {
      await Api().post('/messages', data: {
        'booking_id': widget.bookingId,
        'receiver_id': _receiverId,
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

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      final h = date.hour;
      final m = date.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final title = widget.courtName ?? widget.otherUserName ?? 'Booking #${widget.bookingId}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (widget.otherUserName != null && widget.courtName != null)
              Text(widget.otherUserName!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
                            const Text(
                              'Start a conversation about this booking',
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
                              _MessageBubble(message: msg, isMe: isMe, formatTime: _formatTime),
                            ],
                          );
                        },
                      ),
          ),
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
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String Function(String?) formatTime;

  const _MessageBubble({required this.message, required this.isMe, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
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
            if (!isMe && message['sender_name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message['sender_name'],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            Text(
              message['body'] ?? message['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message['created_at']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textDisabled,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['is_read'] == 1 ? Icons.done_all : Icons.done,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
