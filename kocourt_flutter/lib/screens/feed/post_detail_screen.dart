import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/posts/${widget.postId}');
      _post = Map<String, dynamic>.from(res.data['post'] ?? res.data);
      _comments = List<Map<String, dynamic>>.from(
        (_post!['comments'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _comment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    try {
      await Api().post('/posts/${widget.postId}/comment', data: {
        'user_id': auth.userId,
        'content': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      _load();
    } catch (_) {}
  }

  Future<void> _like() async {
    final auth = context.read<AuthProvider>();
    try {
      await Api().post('/posts/${widget.postId}/like', data: {'user_id': auth.userId});
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_post == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Post not found')));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Post', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        child: Text((_post!['user_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_post!['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(_post!['created_at'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_post!['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.5)),
                  if (_post!['image_url'] != null && _post!['image_url'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: _post!['image_url'], fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Like button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _like,
                        child: Row(
                          children: [
                            Icon(_post!['user_liked'] == true ? AppIcons.heartFilled : AppIcons.heart,
                                size: 20, color: _post!['user_liked'] == true ? AppColors.error : Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text('${_post!['likes_count'] ?? 0}', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Icon(AppIcons.messageCircle, size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text('${_comments.length}', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                    ],
                  ),
                  const Divider(height: 32),
                  // Comments
                  ..._comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[200],
                          child: Text((c['user_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(c['content'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          // Comment input
          Container(
            padding: EdgeInsets.only(left: 20, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                IconButton(onPressed: _comment, icon: const Icon(Icons.send_rounded, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
