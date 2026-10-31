import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'venue_access.dart';
import 'venue_detail_screen.dart';
import 'edit_venue_screen.dart';
import '../../widgets/sheets/claim_venue_sheet.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<Map<String, dynamic>> _owned = [];
  List<Map<String, dynamic>> _assigned = [];
  List<Map<String, dynamic>> _ghostPlaces = [];
  bool _loading = true;
  String? _ownedError;
  String? _staffError;

  List<VenueListing> get _listings => mergeVenueListings(owned: _owned, assigned: _assigned);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _courtMap(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    map.remove('owner_phone');
    return map;
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final venues = context.read<VenueProvider>();
    String? ownedError;
    String? staffError;
    List<Map<String, dynamic>>? owned;
    List<Map<String, dynamic>>? assigned;

    try {
      final res = await Api().get('/courts', params: {'owner_id': auth.userId});
      owned = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map(_courtMap),
      );
    } catch (error) {
      ownedError = Api.failureMessage(error, fallback: 'Couldn’t load your venues.');
    }

    try {
      final res = await Api().get('/court-staff/my-courts');
      assigned = List<Map<String, dynamic>>.from(
        (res.data['courts'] ?? []).map(_courtMap),
      );
    } catch (error) {
      staffError = Api.failureMessage(error, fallback: 'Couldn’t load venues assigned to you.');
    }

    try {
      await venues.fetchGhostPlaces(userId: auth.userId);
      if (mounted) _ghostPlaces = venues.ghostPlaces;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      if (owned != null) _owned = owned;
      if (assigned != null) _assigned = assigned;
      _ownedError = ownedError;
      _staffError = staffError;
      _loading = false;
    });
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
              child: _venueList(),
            ),
    );
  }

  Widget _venueList() {
    final listings = _listings;
    final owned = listings.where((venue) => venue.isOwner).toList();
    final assigned = listings.where((venue) => !venue.isOwner).toList();
    final loadFailed = _ownedError != null || _staffError != null;
    final showEmpty = listings.isEmpty && _ghostPlaces.isEmpty && !loadFailed;

    if (showEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (loadFailed) ...[
          _loadErrorCard(),
          const SizedBox(height: 16),
        ],
        if (listings.isNotEmpty) ...[
          _portfolioHero(owned.length, assigned.length),
          const SizedBox(height: 18),
        ],
        if (owned.isNotEmpty) ...[
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
          ...owned.map(_venueCard),
        ],
        if (assigned.isNotEmpty) ...[
          if (owned.isNotEmpty) const SizedBox(height: 12),
          const Text(
            'ASSIGNED TO YOU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...assigned.map(_venueCard),
        ],
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
    );
  }

  Widget _loadErrorCard() {
    final messages = <String>[
      ?_ownedError,
      ?_staffError,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn’t refresh venues',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(messages.join('\n'), style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () {
              setState(() => _loading = true);
              _load();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _portfolioHero(int ownedCount, int assignedCount) {
    final total = ownedCount + assignedCount;
    final venueLabel = total == 1 ? 'active venue' : 'active venues';
    final subtitle = ownedCount > 0 && assignedCount > 0
        ? '$ownedCount owned · $assignedCount assigned'
        : assignedCount > 0
            ? 'Venues the owner has shared with you.'
            : 'Your venue portfolio is ready to manage.';
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
                    '$total $venueLabel',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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

  Widget _venueCard(VenueListing venue) {
    final c = venue.court;
    final img = getVenueImage(c);
    final courtId = venue.id;
    return TactileSurface(
      onTap: courtId == null
          ? null
          : () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VenueDetailScreen(courtId: courtId),
              )).then((_) => _load()),
      margin: const EdgeInsets.only(bottom: 12),
      radius: 16,
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
                  Text(venue.accessLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 2),
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
