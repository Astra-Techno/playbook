import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_post_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'comments_sheet.dart';
import 'post_images.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({Map? created}) async {
    try {
      final res = await Api().get('/posts');
      if (mounted) {
        setState(() {
          final rows = List<Map<String, dynamic>>.from(
            (res.data['records'] ?? res.data['posts'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          _posts = feedWithCreated(rows, created);
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _posts = feedWithCreated(_posts, created);
        _error = _posts.isEmpty ? Api.failureMessage(error, fallback: 'Posts could not be loaded.') : null;
        _loading = false;
      });
    }
  }

  /// Like instantly; the server call runs behind it and is undone if it fails.
  Future<void> _likePost(Map<String, dynamic> post) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    final wasLiked = post['is_liked'] == true || post['user_liked'] == true;
    final count = int.tryParse('${post['likes_count'] ?? 0}') ?? 0;
    void apply(bool liked, int n) => setState(() {
          post['is_liked'] = liked;
          post['user_liked'] = liked;
          post['likes_count'] = n < 0 ? 0 : n;
        });
    apply(!wasLiked, count + (wasLiked ? -1 : 1));
    try {
      await Api().post('/posts/${post['id']}/like', data: {'user_id': auth.userId});
    } catch (_) {
      if (mounted) {
        apply(wasLiked, count);
        context.toastError('Could not update your like.');
      }
    }
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    final auth = context.read<AuthProvider>();
    final id = int.tryParse('${post['id']}');
    if (id == null) return;
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    final count = await CommentsSheet.open(context, postId: id, userId: auth.userId);
    if (count != null && mounted) setState(() => post['comment_count'] = count);
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final who = '${post['user_name'] ?? 'A player'}';
    final text = '${post['content'] ?? ''}'.trim();
    final where = post['court_name'] != null ? ' at ${post['court_name']}' : '';
    await SharePlus.instance.share(ShareParams(
      text: [
        '$who on KoCourt$where:',
        text.isEmpty ? 'See the post' : text,
        'https://www.kocourt.com/feed/${post['id']}',
      ].join('\n'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Community'),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())).then((created) {
              if (created is Map) {
                _loadPosts(created: created);
              } else if (created == true) {
                _loadPosts();
              }
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text('New post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.rss, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text(
                        _error ?? 'No posts yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      if (_error != null)
                        TextButton(onPressed: () => _loadPosts(), child: const Text('Try again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _posts.length,
                    // Everything happens in the feed: double-tap to like, comments in a sheet.
                    itemBuilder: (_, i) => _buildPostCard(_posts[i]),
                  ),
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final liked = post['is_liked'] == true || post['user_liked'] == true;
    final likeCount = post['likes_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: ClipOval(
                  child: post['avatar_url'] != null
                      ? CachedNetworkImage(
                          imageUrl: post['avatar_url'],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: Text(
                            (post['user_name'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '${post['user_name'] ?? 'Player'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (timeAgo(post['created_at']).isNotEmpty)
                        TextSpan(text: '  ·  ${timeAgo(post['created_at'])}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ])),
                    if (post['court_name'] != null)
                      Row(
                        children: [
                          Icon(AppIcons.mapPin, size: 11, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              post['court_name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Content
          if ('${post['content'] ?? ''}'.trim().isNotEmpty)
            GestureDetector(
              onDoubleTap: () {
                if (!liked) _likePost(post);
              },
              child: Text(
                '${post['content']}'.trim(),
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary),
              ),
            ),
          for (final url in postImageUrls(post)) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 200,
                  color: AppColors.surfaceDim,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Divider
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: () => _likePost(post),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: liked
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: liked ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$likeCount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: liked ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openComments(post),
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.messageCircle, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      '$commentCount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share post',
                onPressed: () => _sharePost(post),
                icon: Icon(AppIcons.share, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
