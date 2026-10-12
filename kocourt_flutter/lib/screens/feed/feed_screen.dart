import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final res = await Api().get('/posts');
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(
            (res.data['posts'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _likePost(Map<String, dynamic> post) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    try {
      await Api().post('/posts/${post['id']}/like', data: {'user_id': auth.userId});
      _loadPosts();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Community', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())).then((created) { if (created == true) _loadPosts(); }),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
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
                      Icon(AppIcons.rss, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No posts yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: _posts[i]['id']))),
                      child: _buildPostCard(_posts[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final liked = post['user_liked'] == true;
    final likeCount = post['likes_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
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
                    Text(
                      post['user_name'] ?? 'Anonymous',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
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
              Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          // Content
          if (post['content'] != null)
            Text(
              post['content'],
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
            ),
          if (post['image_url'] != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: post['image_url'],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
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
              Container(
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
              const Spacer(),
              Icon(AppIcons.share, size: 18, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}
