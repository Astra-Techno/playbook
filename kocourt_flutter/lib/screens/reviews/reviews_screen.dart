import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class ReviewsScreen extends StatefulWidget {
  final int? courtId; // null = my reviews
  const ReviewsScreen({super.key, this.courtId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final courtId = widget.courtId;
    if (courtId == null || courtId < 1) {
      final signedIn = context.read<AuthProvider>().isLoggedIn;
      if (!signedIn) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Sign in to see your reviews.';
          });
        }
        return;
      }
    }
    try {
      final res = await Api().get('/reviews', params: reviewListParams(courtId: courtId));
      _reviews = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      _error = null;
    } catch (e) {
      final message = Api.failureMessage(e);
      _error = message == 'court_id required' ? 'Sign in to see your reviews.' : message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.courtId != null && widget.courtId! > 0 ? 'Reviews' : 'My Reviews', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null && _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
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
                                    j < (int.tryParse('${r['rating'] ?? 0}') ?? 0) ? AppIcons.star : Icons.star_border,
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
