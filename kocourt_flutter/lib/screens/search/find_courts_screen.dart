import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../court_details/court_details_screen.dart';
import 'court_list_params.dart';
import '../home/home_logic.dart' show isOpenNow;

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('All venues')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search venues or areas',
                prefixIcon: const Icon(AppIcons.search, size: 18),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(AppIcons.compass, size: 18)),
                filled: true,
                fillColor: Colors.white,
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
                      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: sel ? (c.id == 'All' ? AppColors.primary : sportTint(c.id).fg) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SportIcon(c.id, size: 18, tone: sel ? Colors.white : null, tint: sel ? sportTint(c.id).fg : null, fallback: c.icon),
                        const SizedBox(width: 6),
                        Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textPrimary)),
                      ]),
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
                    ? Center(child: Text(_searched ? 'No venues found' : 'Loading venues', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final c = _results[i];
                          final img = getVenueImage(c);
                          final tint = sportTint(c['type']);
                          final open = isOpenNow(c, DateTime.now());
                          final rating = num.tryParse('${c['avg_rating'] ?? ''}');
                          final place = [
                            if ('${c['location'] ?? ''}'.isNotEmpty) '${c['location']}',
                            if (c['distance_km'] != null) '${c['distance_km']} km',
                          ].join(' · ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtIdFrom(c['id'])))),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: CachedNetworkImage(
                                          imageUrl: img,
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(width: 88, height: 88, color: tint.bg, alignment: Alignment.center, child: SportIcon(c['type'], size: 36)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              SportIcon(c['type'], size: 15, tint: Colors.white),
                                              const SizedBox(width: 5),
                                              Flexible(child: Text(sportLabel(c['type']).toUpperCase(), style: AppFonts.score(fontSize: 12, letterSpacing: 1, color: tint.fg))),
                                            ]),
                                            const SizedBox(height: 3),
                                            Text('${c['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.display(fontSize: 16)),
                                            if (place.isNotEmpty)
                                              Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                            const SizedBox(height: 6),
                                            Row(children: [
                                              if (c['hourly_rate'] != null) ...[
                                                Text(rupees(c['hourly_rate']), style: AppFonts.score(fontSize: 16, color: AppColors.textPrimary)),
                                                const Text('/hr', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                                const SizedBox(width: 10),
                                              ],
                                              if (rating != null && rating > 0) ...[
                                                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                                Text(rating.toStringAsFixed(1), style: AppFonts.score(fontSize: 14, color: AppColors.textPrimary)),
                                                const SizedBox(width: 10),
                                              ],
                                              Flexible(
                                                child: Text(open ? 'Open now' : 'Closed', maxLines: 1,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: open ? AppColors.secondary : AppColors.textMuted)),
                                              ),
                                            ]),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
