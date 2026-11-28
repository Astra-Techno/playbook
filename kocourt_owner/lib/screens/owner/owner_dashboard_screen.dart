import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'dashboard_load.dart';
import 'venue_access.dart';
import 'venue_detail_screen.dart';
import 'edit_venue_screen.dart';
import 'earnings_figures.dart';
import 'occupancy_figures.dart';
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
  DayCollected? _collected;
  String? _collectedError;
  Map<int, TodayOccupancy> _occupancy = {};
  String? _occupancyError;

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
    final ownerId = auth.userId;
    if (ownerId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ownedError = 'Please sign in again.';
        _staffError = 'Please sign in again.';
      });
      return;
    }
    final together = await loadTogether(
      owned: () async {
        try {
          final res = await Api().get('/courts', params: {'owner_id': ownerId});
          return (
            rows: List<Map<String, dynamic>>.from((res.data['records'] ?? []).map(_courtMap)),
            error: null as String?,
          );
        } catch (error) {
          return (rows: null as List<Map<String, dynamic>>?, error: Api.failureMessage(error, fallback: 'Couldn’t load your venues.'));
        }
      }(),
      staff: () async {
        try {
          final res = await Api().get('/court-staff/my-courts');
          return (
            rows: List<Map<String, dynamic>>.from((res.data['courts'] ?? []).map(_courtMap)),
            error: null as String?,
          );
        } catch (error) {
          return (rows: null as List<Map<String, dynamic>>?, error: Api.failureMessage(error, fallback: 'Couldn’t load venues assigned to you.'));
        }
      }(),
      ghosts: () async {
        try {
          await venues.fetchGhostPlaces(userId: ownerId);
          return venues.ghostPlaces;
        } catch (_) {
          return null;
        }
      }(),
    );
    final owned = together.owned.rows;
    final ownedError = together.owned.error;
    final assigned = together.staff.rows;
    final staffError = together.staff.error;
    if (together.ghosts != null) _ghostPlaces = together.ghosts!;

    DayCollected? collected;
    String? collectedError;
    final showCollections = owned != null && owned.isNotEmpty;
    if (showCollections) {
      try {
        final res = await Api().get('/earnings', params: {'owner_id': ownerId});
        final raw = res.data is Map ? res.data['summary'] : null;
        if (raw is! Map) {
          throw const FormatException('Collections response was incomplete.');
        }
        collected = dayCollected(Map<String, dynamic>.from(raw));
        if (collected == null) {
          throw const FormatException('Collections response was incomplete.');
        }
      } catch (error) {
        collectedError = error is FormatException
            ? error.message
            : Api.failureMessage(error, fallback: 'Couldn’t load today’s collections.');
      }
    }

    Map<int, TodayOccupancy>? occupancy;
    String? occupancyError;
    final hasVenue = (owned != null ? owned.isNotEmpty : _owned.isNotEmpty) ||
        (assigned != null ? assigned.isNotEmpty : _assigned.isNotEmpty);
    if (hasVenue && auth.userId != null) {
      try {
        final res = await Api().get('/courts/occupancy');
        occupancy = occupancyByVenue(res.data);
      } catch (error) {
        occupancyError = Api.failureMessage(error, fallback: 'Couldn’t load today’s bookings.');
      }
    }

    if (!mounted) return;
    setState(() {
      if (owned != null) _owned = owned;
      if (assigned != null) _assigned = assigned;
      _ownedError = ownedError;
      _staffError = staffError;
      if (showCollections && collected != null) {
        _collected = collected;
        _collectedError = null;
      } else if (showCollections) {
        _collectedError = collectedError;
      } else if (owned != null) {
        _collected = null;
        _collectedError = null;
      }
      if (hasVenue && occupancy != null) {
        _occupancy = occupancy;
        _occupancyError = null;
      } else if (hasVenue) {
        _occupancyError = occupancyError;
      } else if (owned != null && assigned != null) {
        _occupancy = {};
        _occupancyError = null;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My venues', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Scan a booking pass',
            onPressed: () => context.push('/scan'),
            icon: Icon(Icons.qr_code_scanner_rounded, color: context.brand.primary),
          ),
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
                Icon(AppIcons.layoutGrid, size: 48, color: AppColors.textDisabled),
                const SizedBox(height: 16),
                Text('No venues yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const EditVenueScreen(),
                  )).then((_) => _load()),
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Add your first venue'),
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
          _todayCard(owned.length, assigned.length),
          for (final error in [?_collectedError, ?_occupancyError]) ...[
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 18),
        ],
        if (owned.isNotEmpty) ...[
          Text('Your venues', style: AppFonts.display(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...owned.map(_venueCard),
        ],
        if (assigned.isNotEmpty) ...[
          if (owned.isNotEmpty) const SizedBox(height: 12),
          Text('Assigned to you', style: AppFonts.display(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...assigned.map(_venueCard),
        ],
        if (_ghostPlaces.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Claim your venue', style: AppFonts.display(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            'Nearby venues not yet on KoCourt',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
        color: const Color(0xFFFEECEC),
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
          Text(messages.join('\n'), style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
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

  Widget _todayCard(int ownedCount, int assignedCount) {
    final total = ownedCount + assignedCount;
    final collected = _collected;
    final bookings = _occupancy.values.fold<int>(0, (sum, day) => sum + day.confirmedCount);
    return KoCard(
      kicker: 'Today',
      title: collected != null ? '${rupees(collected.today)} collected' : '$bookings booking${bookings == 1 ? '' : 's'} today',
      meta: ownedCount > 0 && assignedCount > 0
          ? '$ownedCount owned · $assignedCount assigned'
          : collected != null
              ? 'Paid bookings at venues you own, after refunds'
              : 'Venues the owner has shared with you',
      stats: [
        if (collected != null) KoStat(rupees(collected.thisWeek), 'This week'),
        KoStat('$bookings', 'Bookings'),
        KoStat('$total', total == 1 ? 'Venue' : 'Venues'),
      ],
    );
  }

  Widget _venueCard(VenueListing venue) {
    final c = venue.court;
    final courtId = venue.id;
    final day = courtId == null ? null : _occupancy[courtId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KoCard(
        sport: c['type'],
        kicker: venue.accessLabel,
        title: '${c['name'] ?? ''}',
        meta: '${c['location'] ?? ''}',
        stats: [
          if (day != null) KoStat('${day.confirmedCount}', 'Bookings today'),
          if (day != null && day.openMinutes > 0)
            KoStat('${(day.bookedMinutes * 100 / day.openMinutes).round()}%', 'Booked today'),
        ],
        onTap: courtId == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => VenueDetailScreen(courtId: courtId, openedAsOwner: venue.isOwner),
                )).then((_) => _load()),
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
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  backgroundColor: AppColors.primary,
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
