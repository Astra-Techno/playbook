import 'dart:ui';
import 'package:flutter/material.dart';
import 'slot_block.dart';
import '../bookings/booking_ticket.dart';
import '../reviews/past_booking.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

int courtIdFrom(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

class CourtDetailsScreen extends StatefulWidget {
  final int courtId;
  const CourtDetailsScreen({super.key, required this.courtId});

  @override
  State<CourtDetailsScreen> createState() => _CourtDetailsScreenState();
}

class _CourtDetailsScreenState extends State<CourtDetailsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _court;
  List<Map<String, dynamic>> _spaces = [];
  int? _selectedSpaceId;
  bool _loading = true;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<Map<String, dynamic>> _slots = [];
  bool _slotsLoading = true;
  String? _slotsError;
  Set<String> _selectedSlots = {};
  bool _bookingLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  List<String> _photos = [];
  double? _avgRating;
  int _reviewCount = 0;
  String? _reviewsError;
  List<Map<String, dynamic>> _plans = [];
  bool _subscribing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourt();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourt() async {
    try {
      final res = await Api().get('/courts/${widget.courtId}');
      final court = Map<String, dynamic>.from(res.data['court'] ?? res.data);

      List<Map<String, dynamic>> spaces = [];
      try {
        final spRes = await Api().get('/sub-courts', params: {'court_id': widget.courtId});
        spaces = List<Map<String, dynamic>>.from(
          (spRes.data['sub_courts'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (_) {}

      List<Map<String, dynamic>> reviews = [];
      double? avgRating;
      int reviewCount = 0;
      try {
        final rvRes = await Api().get('/reviews', params: {'court_id': widget.courtId});
        reviews = List<Map<String, dynamic>>.from(
          (rvRes.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
        avgRating = double.tryParse('${rvRes.data['avg_rating'] ?? ''}');
        reviewCount = rvRes.data['review_count'] ?? reviews.length;
        _reviewsError = null;
      } catch (error) {
        _reviewsError = Api.failureMessage(error, fallback: 'Reviews could not be loaded.');
        if (_reviewsError == 'court_id required') {
          _reviewsError = 'Reviews for this venue could not be loaded.';
        }
      }

      // Load photo gallery
      List<String> photos = [];
      try {
        final phRes = await Api().get('/court-photos', params: {'court_id': widget.courtId});
        final photoList = phRes.data['photos'] as List? ?? [];
        photos = photoList.map((p) => p['url']?.toString() ?? '').where((u) => u.isNotEmpty).toList();
      } catch (_) {}

      // Load plans
      List<Map<String, dynamic>> plans = [];
      try {
        final plRes = await Api().get('/plans', params: {'court_id': widget.courtId});
        plans = List<Map<String, dynamic>>.from(
          (plRes.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (_) {}

      setState(() {
        _court = court;
        _spaces = spaces;
        _reviews = reviews;
        _photos = photos;
        _avgRating = avgRating;
        _reviewCount = reviewCount;
        _plans = plans;
        _loading = false;
        final spaceId = spaces.isNotEmpty ? courtIdFrom(spaces.first['id']) : 0;
        _selectedSpaceId = spaceId > 0 ? spaceId : null;
      });

      _loadSlots();
    } catch (e) {
      setState(() {
        _loading = false;
        _slotsLoading = false;
        _slotsError = 'Slots could not be loaded.';
      });
    }
  }
  int _clockHour(dynamic value, int fallback) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return fallback;
    final hour = int.tryParse(text.split(':').first);
    if (hour == null || hour < 0 || hour > 23) return fallback;
    return hour;
  }

  Future<void> _loadSlots() async {
    if (mounted) {
      setState(() {
        _slotsLoading = true;
        _slotsError = null;
      });
    }
    var bookings = <Map<String, dynamic>>[];
    final blocked = <String>{};
    try {
      final params = <String, dynamic>{
        'court_id': widget.courtId,
        'date': _selectedDate,
      };
      final spaceId = _selectedSpaceId ?? 0;
      if (spaceId > 0) params['sub_court_id'] = spaceId;

      final res = await Api().get('/bookings', params: params);
      bookings = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (error) {
      _slotsError = Api.failureMessage(error, fallback: 'Slots could not be loaded.');
    }

    try {
      final bRes = await Api().get('/blocked-slots', params: {
        'court_id': widget.courtId,
        'date': _selectedDate,
        if ((_selectedSpaceId ?? 0) > 0) 'sub_court_id': _selectedSpaceId,
      });
      final bSlots = bRes.data['blocks'] ?? [];
      for (final b in bSlots) {
        final appliesStart = '${b['applies_start'] ?? b['start_time'] ?? ''}';
        final appliesEnd = '${b['applies_end'] ?? b['end_time'] ?? ''}';
        blocked.add('$appliesStart|$appliesEnd');
      }
    } catch (_) {}

    final slots = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final openHour = _clockHour(_court?['open_time'], 6);
    final closeHour = _clockHour(_court?['close_time'], 22);
    final firstHour = closeHour > openHour ? openHour : 6;
    final lastHour = closeHour > openHour ? closeHour : 22;
    for (int h = firstHour; h < lastHour; h++) {
      final start = '${h.toString().padLeft(2, '0')}:00';
      final end = '${(h + 1).toString().padLeft(2, '0')}:00';
      final key = '$start-$end';
      final slotStart = '$_selectedDate $start:00';
      final slotEnd = '$_selectedDate $end:00';
      final isBooked = bookings.any((b) => intervalsOverlap(
        appliesStart: '${b['start_time'] ?? ''}',
        appliesEnd: '${b['end_time'] ?? ''}',
        slotStart: slotStart,
        slotEnd: slotEnd,
      ));
      final isBlocked = blocked.any((row) {
        final parts = row.split('|');
        if (parts.length != 2) return false;
        return blockCoversSlot(
          appliesStart: parts[0],
          appliesEnd: parts[1],
          slotStart: slotStart,
          slotEnd: slotEnd,
        );
      });
      slots.add({
        'start': start,
        'end': end,
        'key': key,
        'booked': isBooked,
        'blocked': isBlocked,
        'past': slotStartHasPassed(_selectedDate, h, now),
      });
    }

    if (!mounted) return;
    setState(() {
      _slots = slots;
      _selectedSlots = {};
      _slotsLoading = false;
    });
  }

  Future<void> _shareVenue() async {
    final name = _court?['name'] ?? 'KoCourt Venue';
    final location = _court?['location'] ?? '';
    final rate = _court?['hourly_rate'] ?? '';
    final text = '$name\n${location.isNotEmpty ? '$location\n' : ''}'
        '${rate.toString().isNotEmpty ? '\u20B9$rate/hr\n' : ''}'
        '\nBook now on KoCourt!\nhttps://www.kocourt.com/court/${widget.courtId}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _book() async {
    final now = DateTime.now();
    setState(() {
      _selectedSlots.removeWhere((key) => slotStartHasPassed(_selectedDate, int.tryParse(key.split(':').first) ?? 0, now));
    });
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That time has already passed'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }

    setState(() => _bookingLoading = true);

    try {
      final rate = double.tryParse('${_court!['hourly_rate'] ?? 0}') ?? 0;
      final totalPrice = rate * _selectedSlots.length;

      // Build slots array for multi-slot payment
      final slots = _selectedSlots.map((slotKey) {
        final parts = slotKey.split('-');
        return {
          'start_time': '$_selectedDate ${parts[0]}:00',
          'end_time': '$_selectedDate ${parts[1]}:00',
          'total_price': rate,
        };
      }).toList();

      final payload = {
        'court_id': widget.courtId,
        if (_selectedSpaceId != null) 'sub_court_id': _selectedSpaceId,
        'slots': slots,
        'type': 'hourly',
        'total_price': totalPrice,
      };

      final result = await PaymentService.processPayment(
        context: context,
        amount: totalPrice,
        type: 'booking',
        payload: payload,
      );

      if (!mounted) return;

      if (result.success) {
        HapticFeedback.heavyImpact();
        final bookingIds = bookingIdsFromVerify(result.verifyData);
        if (!mounted) return;
        if (bookingIds.isNotEmpty) {
          context.go('/booking-confirmation/${bookingIds.first}');
        } else {
          context.go('/bookings');
        }
        } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment did not go through. This booking was not confirmed.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_court == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Court not found')),
      );
    }

    final imageUrl = getVenueImage(_court!);
    final totalPrice = (double.tryParse('${_court!['hourly_rate'] ?? 0}') ?? 0) * _selectedSlots.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.textPrimary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _shareVenue,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo gallery or single image
                  if (_photos.length > 1)
                    PageView.builder(
                      itemCount: _photos.length,
                      itemBuilder: (_, i) => CachedNetworkImage(imageUrl: _photos[i], fit: BoxFit.cover),
                    )
                  else
                    CachedNetworkImage(imageUrl: _photos.isNotEmpty ? _photos.first : imageUrl, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                  // Photo count badge
                  if (_photos.length > 1)
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              '${_photos.length} photos',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Bottom info on image
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Row(
                      children: [
                        if (_avgRating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _avgRating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        if (_avgRating != null) const SizedBox(width: 8),
                        if (_reviewCount > 0)
                          Text(
                            '$_reviewCount reviews',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Court info card
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _court!['name'] ?? '',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
                        ),
                      ),
                      if (_court!['is_verified'] == true || _court!['is_verified'] == 1) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified_rounded, size: 22, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(AppIcons.mapPin, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _court!['location'] ?? '',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  if (_court!['hourly_rate'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\u20B9${_court!['hourly_rate']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            ' /slot',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Spaces selector
          if (_spaces.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT SPACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _spaces.length,
                        itemBuilder: (_, i) {
                          final space = _spaces[i];
                          final selected = _selectedSpaceId == courtIdFrom(space['id']);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final nextSpace = courtIdFrom(space['id']);
                                setState(() => _selectedSpaceId = nextSpace > 0 ? nextSpace : null);
                                _loadSlots();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.textPrimary : AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  space['name'] ?? 'Space ${i + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : AppColors.textSecondary,
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
              ),
            ),

          SliverToBoxAdapter(child: _buildMembershipSection()),

          // Tab bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(AppRadius.md),
                tabs: [
                  const Tab(text: 'Book Slots'),
                  Tab(text: 'Reviews ($_reviewCount)'),
                  Tab(text: 'Plans (${_plans.length})'),
                ],
              ),
            ),
          ),

          // Tab content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                if (_tabController.index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildDatePicker(),
                        const SizedBox(height: 16),
                        _buildSlotsGrid(),
                      ],
                    ),
                  );
                }
                if (_tabController.index == 2) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildPlans(),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildReviews(),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Booking bar
      bottomNavigationBar: _selectedSlots.isNotEmpty
          ? Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Price summary
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedSlots.length} slot${_selectedSlots.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${totalPrice == totalPrice.toInt() ? totalPrice.toInt() : totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Book button
                  Flexible(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _bookingLoading ? null : _book,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      child: _bookingLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Book Now',
                                maxLines: 1,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDatePicker() {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT DATE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            itemBuilder: (_, i) {
              final date = today.add(Duration(days: i));
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final selected = _selectedDate == dateStr;
              final isToday = i == 0;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDate = dateStr);
                  _loadSlots();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 56,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selected ? null : Border.all(color: AppColors.borderLight),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isToday ? 'TODAY' : DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: isToday ? 8 : 9,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
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
    );
  }

  Widget _buildSlotsGrid() {
    if (_slotsLoading && _slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
      );
    }
    if (_slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_slotsError ?? 'No slots for this day.', textAlign: TextAlign.center),
            TextButton(onPressed: _loadSlots, child: const Text('Try again')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT TIME SLOTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _slots.length,
          itemBuilder: (_, i) {
            final slot = _slots[i];
            final key = slot['key'] as String;
            final booked = slot['booked'] as bool;
            final blocked = slot['blocked'] as bool;
            final hour = int.tryParse('${slot['start']}'.split(':').first) ?? 0;
            final past = slotStartHasPassed(_selectedDate, hour, DateTime.now());
            final selected = _selectedSlots.contains(key);
            final disabled = booked || blocked || past;

            return GestureDetector(
              onTap: () {
                if (disabled) {
                  if (booked) _suggestNextOpenSlot(i);
                  return;
                }
                HapticFeedback.selectionClick();
                setState(() {
                  if (selected) {
                    _selectedSlots.remove(key);
                  } else {
                    _selectedSlots.add(key);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: disabled
                      ? AppColors.surfaceDim
                      : selected
                          ? AppColors.primary
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: disabled
                        ? AppColors.borderLight
                        : selected
                            ? AppColors.primary
                            : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot['start'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? AppColors.textDisabled
                            : selected
                                ? Colors.white
                                : AppColors.textPrimary,
                      ),
                    ),
                    if (disabled)
                      Text(
                        past ? 'Past' : booked ? 'Booked' : 'Blocked',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.check_rounded, size: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }

    setState(() => _subscribing = true);
    try {
      final price = double.tryParse('${plan['price'] ?? 0}') ?? 0;

      final payload = {
        'plan_id': plan['id'],
        'court_id': widget.courtId,
        'slot_type': plan['slot_type'] ?? 'full_day',
        'duration_days': plan['duration_days'] ?? 30,
      };

      final result = await PaymentService.processPayment(
        context: context,
        amount: price,
        type: 'subscription',
        payload: payload,
      );

      if (!mounted) return;

      if (result.success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Subscription activated!', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Subscription failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  void _suggestNextOpenSlot(int fromIndex) {
    for (var i = fromIndex + 1; i < _slots.length; i++) {
      final slot = _slots[i];
      final hour = int.tryParse('${slot['start']}'.split(':').first) ?? 0;
      final past = slotStartHasPassed(_selectedDate, hour, DateTime.now());
      if (slot['booked'] == true || slot['blocked'] == true || past) continue;
      final key = '${slot['key']}';
      final label = '${slot['start'] ?? key}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Next free slot is $label'),
          action: SnackBarAction(
            label: 'Select',
            onPressed: () => setState(() => _selectedSlots.add(key)),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No later slot is free today. Try another date.')),
    );
  }

  Widget _buildMembershipSection() {
    final plans = _plans.where((plan) => '${plan['is_active'] ?? 1}' != '0').toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Membership', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Subscription plans for this venue.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            const Text('No membership plans yet.')
          else
            ...plans.map((plan) {
              final price = double.tryParse('${plan['price'] ?? 0}') ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${plan['name'] ?? 'Plan'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('₹${price.toStringAsFixed(0)} · ${plan['duration_days'] ?? 30} days', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _subscribing ? null : () => _subscribeToPlan(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                        ),
                        child: const FittedBox(child: Text('Join', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white))),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPlans() {
    final plans = _plans.where((plan) => '${plan['is_active'] ?? 1}' != '0').toList();
    if (plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.card_membership_rounded, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No plans available', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plans.map((plan) {
        final price = double.tryParse('${plan['price'] ?? 0}') ?? 0;
        final days = plan['duration_days'] ?? 30;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan['name'] ?? 'Plan',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '$days days',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if ('${plan['benefits'] ?? plan['description'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${plan['benefits'] ?? plan['description']}'.trim(),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
                Text(
                  'Access: ${plan['slot_type']}'.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '\u20B9${price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _subscribing ? null : () => _subscribeToPlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _subscribing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _writeReview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    int? bookingId;
    try {
      final res = await Api().get('/bookings', params: {'user_id': auth.userId ?? 0});
      final records = res.data is Map ? res.data['records'] : null;
      if (records is List) {
        bookingId = pastBookingId(records, widget.courtId, DateTime.now());
      }
    } catch (_) {}
    if (!mounted) return;
    final result = await ReviewSheet.show(
      context,
      courtId: widget.courtId,
      userId: auth.userId ?? 0,
      courtName: _court?['name'],
      bookingId: bookingId,
    );
    if (result == true) _loadCourt();
  }

  Widget _buildReviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _writeReview,
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text('Write a Review'),
          ),
        ),
        const SizedBox(height: 16),
        if (_reviewsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_reviewsError!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        if (_reviews.isEmpty && _reviewsError == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Text('No reviews yet', style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
        ..._buildReviewCards(),
      ],
    );
  }

  List<Widget> _buildReviewCards() {
    if (_reviews.isEmpty) return [];

    return _reviews.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceMuted,
                    child: Text(
                      (r['user_name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['user_name'] ?? 'Anonymous',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Row(
                          children: List.generate(5, (i) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: i < (int.tryParse('${r['rating'] ?? 0}') ?? 0) ? AppColors.accent : AppColors.textDisabled,
                            ),
                          )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  r['comment'],
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ],
          ),
        );
    }).toList();
  }
}
