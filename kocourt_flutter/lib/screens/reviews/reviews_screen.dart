import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class ReviewsScreen extends StatefulWidget {
  final int? courtId; // null = my reviews
  const ReviewsScreen({super.key, this.courtId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    try {
      final params = <String, dynamic>{};
      if (widget.courtId != null) {
        params['court_id'] = widget.courtId;
      } else {
        params['user_id'] = auth.userId;
      }
      final res = await Api().get('/reviews', params: params);
      _reviews = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.courtId != null ? 'Reviews' : 'My Reviews', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _reviews.isEmpty
              ? Center(child: Text('No reviews yet', style: TextStyle(color: Colors.grey[400])))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _reviews.length,
                    itemBuilder: (_, i) {
                      final r = _reviews[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[200],
                                  child: Text((r['user_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(r['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                                Row(
                                  children: List.generate(5, (j) => Icon(
                                    j < (r['rating'] ?? 0) ? AppIcons.star : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  )),
                                ),
                              ],
                            ),
                            if (r['court_name'] != null) ...[
                              const SizedBox(height: 4),
                              Text(r['court_name'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                            const SizedBox(height: 8),
                            Text(r['comment'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                            if (r['reply'] != null && r['reply'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Owner Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(r['reply'], style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
