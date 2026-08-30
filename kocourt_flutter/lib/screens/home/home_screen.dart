import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/venue_provider.dart';
import '../../widgets/sheets/claim_venue_sheet.dart';
import '../court_details/court_details_screen.dart';
import '../notifications/notifications_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import 'widgets/venue_card.dart';
import 'widgets/ghost_card.dart';
import 'widgets/sport_chips.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _locationLabel = 'All Venues';
  bool _locating = false;

  // Owner quick stats
  int _myVenueCount = 0;
  int _todayBookings = 0;
  List<Map<String, dynamic>> _todaySchedule = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _loadOwnerStats();
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final res = await Api().get('/user-notifications');
      final list = res.data['notifications'] as List? ?? [];
      final unread = list.where((n) => n['read_at'] == null && n['is_read'] != 1).length;
      if (mounted) setState(() => _unreadNotifications = unread);
    } catch (_) {}
  }

  Future<void> _loadOwnerStats() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final res = await Api().get('/courts', params: {'owner_id': auth.userId});
      final courts = res.data['records'] as List? ?? [];
      if (courts.isEmpty) return;
      // Fetch today's bookings for owner
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final bRes = await Api().get('/bookings', params: {'owner_id': auth.userId});
      final bookings = List<Map<String, dynamic>>.from(
        (bRes.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      final todayBookings = bookings.where((b) {
        final d = b['date']?.toString() ?? b['start_time']?.toString().substring(0, 10) ?? '';
        return d == today && b['status'] != 'cancelled';
      }).toList();
      if (mounted) {
        setState(() {
          _myVenueCount = courts.length;
          _todayBookings = todayBookings.length;
          _todaySchedule = todayBookings.take(3).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _detectLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _loadVenues();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      final venues = context.read<VenueProvider>();
      venues.setLocation(pos.latitude, pos.longitude);
      // Reverse geocode to get city name
      try {
        final placemarks = await geocoding.Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '';
          final area = p.subLocality ?? '';
          if (mounted) setState(() => _locationLabel = area.isNotEmpty ? '$area, $city' : city);
        }
      } catch (_) {
        if (mounted) setState(() => _locationLabel = 'Near You');
      }
      venues.fetchVenues();
      venues.fetchGhostPlaces(userId: context.read<AuthProvider>().userId);
      _loadFavorites();
    } catch (_) {
      _loadVenues();
    } finally {
      setState(() => _locating = false);
    }
  }

  void _loadVenues() {
    context.read<VenueProvider>().fetchVenues();
  }

  void _loadFavorites() {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<VenueProvider>().fetchFavorites(auth.userId!);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Timer? _debounce;

  Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '8',
          'countrycodes': 'in',
        },
        options: Options(headers: {'User-Agent': 'KoCourt-App/1.0'}),
      );
      return List<Map<String, dynamic>>.from(
        (res.data as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  String _formatPlaceName(Map<String, dynamic> place) {
    final addr = place['address'] as Map<String, dynamic>? ?? {};
    final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
    final state = addr['state'] ?? '';
    if (city.toString().isNotEmpty && state.toString().isNotEmpty) return '$city, $state';
    final display = place['display_name'] ?? '';
    final parts = display.toString().split(',');
    return parts.take(2).join(',').trim();
  }

  void _showLocationPicker() {
    final controller = TextEditingController();
    List<Map<String, dynamic>> suggestions = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void selectPlace(Map<String, dynamic> place) {
              final lat = double.tryParse(place['lat'].toString()) ?? 0;
              final lng = double.tryParse(place['lon'].toString()) ?? 0;
              final venues = context.read<VenueProvider>();
              venues.setSearchText('');
              venues.setLocation(lat, lng);
              venues.fetchVenues();
              venues.fetchGhostPlaces(userId: context.read<AuthProvider>().userId);
              setState(() => _locationLabel = _formatPlaceName(place));
              Navigator.pop(ctx);
            }

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Change Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search city or area...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onChanged: (val) {
                        _debounce?.cancel();
                        if (val.trim().length < 2) {
                          setSheetState(() => suggestions = []);
                          return;
                        }
                        _debounce = Timer(const Duration(milliseconds: 400), () async {
                          if (!ctx.mounted) return;
                          setSheetState(() => searching = true);
                          final results = await _searchNominatim(val.trim());
                          if (ctx.mounted) {
                            setSheetState(() {
                              suggestions = results;
                              searching = false;
                            });
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Use current location
                    GestureDetector(
                      onTap: () {
                        _debounce?.cancel();
                        Navigator.pop(ctx);
                        _detectLocation();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.my_location, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Use current location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  SizedBox(height: 2),
                                  Text('Detect via GPS', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Icon(AppIcons.chevronRight, size: 16, color: AppColors.textDisabled),
                          ],
                        ),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      Divider(height: 1, color: Colors.grey[200]),
                      const SizedBox(height: 4),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (_, i) {
                            final place = suggestions[i];
                            final display = place['display_name']?.toString() ?? '';
                            final parts = display.split(',');
                            final title = parts.isNotEmpty ? parts.first.trim() : display;
                            final subtitle = parts.length > 1 ? parts.sublist(1).take(3).join(',').trim() : '';
                            final type = place['type']?.toString() ?? '';

                            return InkWell(
                              onTap: () {
                                _debounce?.cancel();
                                selectPlace(place);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        type == 'city' || type == 'town' ? Icons.location_city : AppIcons.mapPin,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                          if (subtitle.isNotEmpty)
                                            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Icon(AppIcons.chevronRight, size: 14, color: AppColors.textDisabled),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await _detectLocation();
          _loadOwnerStats();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          cacheExtent: 500,
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            if (_myVenueCount > 0) SliverToBoxAdapter(child: _buildOwnerBanner()),
            SliverToBoxAdapter(child: SportChips()),
            _buildVenueList(),
            _buildGhostSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    return SliverAppBar(
      floating: true,
      snap: true,
      toolbarHeight: 68,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Logo
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              // Name + location
              Expanded(
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        auth.isLoggedIn
                            ? auth.userName.split(' ').first
                            : 'Welcome to KoCourt',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(AppIcons.mapPin, size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _locating ? 'Detecting...' : _locationLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Notification bell with badge
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _loadNotificationCount());
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Icon(AppIcons.bell, size: 20, color: AppColors.textSecondary),
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              GestureDetector(
                onTap: () {
                  if (!auth.isLoggedIn) {
                    context.go('/login');
                  }
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: auth.isLoggedIn
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.border,
                      width: 2,
                    ),
                    boxShadow: auth.isLoggedIn
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: auth.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: auth.avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: auth.isLoggedIn
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.surfaceDim,
                            alignment: Alignment.center,
                            child: Text(
                              auth.isLoggedIn ? auth.userName[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: auth.isLoggedIn ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(AppIcons.search, size: 20, color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Search courts, sports, gyms...',
                        hintStyle: TextStyle(
                          color: AppColors.textDisabled,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onChanged: (val) {
                        context.read<VenueProvider>()
                          ..setSearchText(val)
                          ..fetchVenues();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(AppIcons.slidersHorizontal, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardScreen())).then((_) => _loadOwnerStats()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayBookings > 0
                        ? '$_todayBookings booking${_todayBookings > 1 ? 's' : ''} today'
                        : 'No bookings today',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_myVenueCount venue${_myVenueCount > 1 ? 's' : ''} managed',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_todaySchedule.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._todaySchedule.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4, height: 4,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${b['start_time']?.toString().substring(0, 5) ?? ''} - ${b['court_name'] ?? ''} ${b['user_name'] != null ? '\u2022 ${b['user_name']}' : ''}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(AppIcons.chevronRight, size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueList() {
    return Consumer<VenueProvider>(
      builder: (context, venues, _) {
        if (venues.isLoading) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(3, (_) => _buildSkeleton()),
              ),
            ),
          );
        }

        if (venues.venues.isEmpty && venues.fetched) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(AppIcons.map, size: 32, color: AppColors.textDisabled),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No venues found',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Try a different location or sport',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        if (venues.venues.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverMainAxisGroup(
          slivers: [
            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venues near you',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Handpicked for your game today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(AppIcons.chevronRight, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Venue cards — lazy built for smooth scrolling
            SliverList.builder(
              itemCount: venues.venues.length,
              itemBuilder: (context, i) {
                final venue = venues.venues[i];
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: VenueCard(
                      venue: venue,
                      index: i,
                      isFavorited: venues.favorites.contains(venue['id']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourtDetailsScreen(courtId: venue['id']),
                          ),
                        );
                      },
                      onFavorite: () {
                        final auth = context.read<AuthProvider>();
                        if (!auth.isLoggedIn) {
                          context.go('/login');
                          return;
                        }
                        venues.toggleFavorite(venue['id'], auth.userId!);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGhostSection() {
    return Consumer<VenueProvider>(
      builder: (context, venues, _) {
        if (venues.ghostPlaces.isEmpty && !venues.isGhostLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Also Nearby',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Not on KoCourt yet',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.warning,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (venues.isGhostLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: List.generate(2, (_) => _buildSkeleton())),
                ),
              ),
            SliverList.builder(
              itemCount: venues.ghostPlaces.length,
              itemBuilder: (context, i) {
                final place = venues.ghostPlaces[i];
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: GhostCard(
                      place: place,
                      onClaim: () {
                        final auth = context.read<AuthProvider>();
                        if (!auth.isLoggedIn) {
                          context.go('/login');
                          return;
                        }
                        ClaimVenueSheet.show(context, place, auth.userId!);
                      },
                      onInterest: () {
                        final auth = context.read<AuthProvider>();
                        if (!auth.isLoggedIn) {
                          context.go('/login');
                          return;
                        }
                        venues.sendInterest(place, auth.userId!);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceDim,
        highlightColor: AppColors.surface,
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
