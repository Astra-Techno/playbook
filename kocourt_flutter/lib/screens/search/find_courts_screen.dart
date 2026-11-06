import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../court_details/court_details_screen.dart';
import 'court_list_params.dart';

class FindCourtsScreen extends StatefulWidget {
  const FindCourtsScreen({super.key});

  @override
  State<FindCourtsScreen> createState() => _FindCourtsScreenState();
}

class _FindCourtsScreenState extends State<FindCourtsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _searched = false;
  String? _error;
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }
    try {
      final res = await Api().get('/courts', params: courtListParams(query: _searchCtrl.text, type: _selectedType));
      _results = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (caught) {
      _results = [];
      _error = Api.failureMessage(caught, fallback: 'Could not load venues.');
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('All venues', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search by location...',
                prefixIcon: const Icon(AppIcons.search, size: 18),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(AppIcons.compass, size: 18)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          // Type chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: sportCategories.map((c) {
                final sel = _selectedType == c.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = c.id);
                      _search();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.black : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              TextButton(onPressed: _search, child: const Text('Try again')),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                    ? Center(child: Text(_searched ? 'No venues found' : 'Loading venues', style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final c = _results[i];
                          final img = getVenueImage(c);
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: c['id']))),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[100]!),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                    child: CachedNetworkImage(imageUrl: img, width: 100, height: 80, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(c['location'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                          if (c['hourly_rate'] != null)
                                            Text('₹${c['hourly_rate']}/slot', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(padding: EdgeInsets.only(right: 12), child: Icon(AppIcons.chevronRight, size: 18, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
