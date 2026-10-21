import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'venue_detail_screen.dart';
import 'edit_venue_screen.dart';
import '../../widgets/sheets/claim_venue_sheet.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<Map<String, dynamic>> _courts = [];
  List<Map<String, dynamic>> _ghostPlaces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final venues = context.read<VenueProvider>();
    try {
      final res = await Api().get('/courts', params: {'owner_id': auth.userId});
      _courts = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    // Load unclaimed nearby places
    try {
      await venues.fetchGhostPlaces(userId: auth.userId);
      _ghostPlaces = venues.ghostPlaces;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Venues', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const EditVenueScreen(),
            )).then((_) => _load()),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _courts.isEmpty && _ghostPlaces.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              Icon(AppIcons.layoutGrid, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No venues yet', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const EditVenueScreen(),
                                )).then((_) => _load()),
                                icon: const Icon(AppIcons.plus, size: 16),
                                label: const Text('Add Your First Venue'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // My venues
                        if (_courts.isNotEmpty) ...[
                          _portfolioHero(),
                          const SizedBox(height: 18),
                          const Text(
                            'YOUR VENUES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._courts.map((c) => _venueCard(c)),
                        ],

                        // Discover & Claim section
                        if (_ghostPlaces.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'DISCOVER & CLAIM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[400],
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nearby venues not yet on KoCourt',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 12),
                          ..._ghostPlaces.map((place) => _ghostPlaceCard(place)),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _portfolioHero() {
    final venueLabel = _courts.length == 1 ? 'active venue' : 'active venues';
    return TactileSurface(
      radius: 22,
      accentColor: AppColors.primary,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_courts.length} $venueLabel',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your venue portfolio is ready to manage.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _venueCard(Map<String, dynamic> c) {
    final img = getVenueImage(c);
    return TactileSurface(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => VenueDetailScreen(courtId: c['id']),
      )).then((_) => _load()),
      margin: const EdgeInsets.only(bottom: 12),
      radius: 16,
      child: Container(
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
                    Text(c['location'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(AppIcons.chevronRight, size: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ghostPlaceCard(Map<String, dynamic> place) {
    final rawImg = place['image_url'];
    final imageUrl = (rawImg is String && rawImg.isNotEmpty) ? rawImg : venueImages['other']!;
    final requestCount = place['request_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.6, 0.2, 0.1, 0, 20,
                0.2, 0.6, 0.1, 0, 20,
                0.2, 0.2, 0.5, 0, 20,
                0, 0, 0, 1, 0,
              ]),
              child: Image.network(imageUrl, width: 100, height: 88, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    place['address'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (requestCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$requestCount interested',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  final uid = auth.userId;
                  if (uid == null) return;
                  ClaimVenueSheet.show(context, place, uid).then((claimed) {
                    if (claimed == true) _load();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('Claim'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
