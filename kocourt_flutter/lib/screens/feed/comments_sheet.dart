import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// Comments in a bottom sheet, so reading or replying never leaves the feed.
/// Returns the new comment count when closed.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.postId, required this.userId});

  final int postId;
  final Object? userId;

  static Future<int?> open(BuildContext context, {required int postId, required Object? userId}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CommentsSheet(postId: postId, userId: userId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/posts/${widget.postId}');
      final post = res.data['post'] ?? res.data;
      final rows = List<Map<String, dynamic>>.from(((post is Map ? post['comments'] : null) ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
      if (mounted) {
        setState(() {
          _comments = rows;
          _loading = false;
          _error = null;
        });
      }
    } catch (caught) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = Api.failureMessage(caught, fallback: 'Comments could not be loaded.');
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api().post('/posts/${widget.postId}/comment', data: {'user_id': widget.userId, 'content': text});
      _ctrl.clear();
      await _load();
    } catch (caught) {
      if (mounted) context.toastError(Api.failureMessage(caught, fallback: 'Could not post your comment.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _comments.length);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text('Comments', style: AppFonts.display(fontSize: 18)),
                    const SizedBox(width: 8),
                    if (!_loading) Text('${_comments.length}', style: AppFonts.score(fontSize: 16, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? Center(child: TextButton(onPressed: _load, child: Text('$_error Try again')))
                        : _comments.isEmpty
                            ? const Center(child: Text('No comments yet. Start the conversation.', style: TextStyle(color: AppColors.textSecondary)))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                                itemCount: _comments.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 14),
                                itemBuilder: (_, i) {
                                  final c = _comments[i];
                                  final name = '${c['user_name'] ?? 'Player'}';
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(jerseyInitials(name), style: AppFonts.score(fontSize: 12, color: AppColors.primary)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(TextSpan(children: [
                                              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                              TextSpan(text: '  ${timeAgo(c['created_at'])}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            ])),
                                            const SizedBox(height: 2),
                                            Text('${c['content'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Add a comment…', isDense: true),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send comment',
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
