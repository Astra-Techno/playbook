import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../court_details/court_details_screen.dart';
import 'booking_ticket.dart' show passCountdown;
import '../home/home_logic.dart' show kickoffIn;
import '../court_details/slot_block.dart';
import '../chat/chat_screen.dart';
import '../chat/slot_chat_screen.dart';
import '../chat/slot_groups_screen.dart';

class BookingsScreen extends StatefulWidget {
  final bool standalone;
  const BookingsScreen({super.key, this.standalone = false});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;
  int? _loadedForUser;
  Set<String> _dismissedReviews = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedReviews();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final userId = auth.isLoggedIn ? auth.userId : null;
    if (userId == null) {
      _loadedForUser = null;
      if (_loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _loadedForUser == null) {
            setState(() => _loading = false);
          }
        });
      }
      return;
    }
    if (userId == _loadedForUser) return;
    _loadedForUser = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || context.read<AuthProvider>().userId != userId) return;
      _loadBookings();
    });
  }

  Future<void> _loadDismissedReviews() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedReviews = prefs.getStringList('dismissed_reviews')?.toSet() ?? {};
  }

  Future<void> _dismissReview(String bookingId) async {
    _dismissedReviews.add(bookingId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_reviews', _dismissedReviews.toList());
    if (mounted) setState(() {});
  }

  Future<void> _loadBookings() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (!auth.isLoggedIn || userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Api().get('/bookings', params: {'user_id': userId});
      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(
            (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = Api.failureMessage(e);
        });
      }
    }
  }

  bool _showPast = false;

  bool _ended(Map<String, dynamic> b) {
    final end = parseSqlDateTime('${b['end_time'] ?? ''}');
    return end != null && end.isBefore(DateTime.now());
  }

  /// Upcoming = confirmed and not finished, soonest first. Past = everything else, newest first.
  List<Map<String, dynamic>> get _upcoming => _bookings.where((b) => b['status'] == 'confirmed' && !_ended(b)).toList()
    ..sort((a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'));

  List<Map<String, dynamic>> get _past {
    final upcoming = _upcoming.toSet();
    return _bookings.where((b) => !upcoming.contains(b)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shown = _showPast ? _past : _upcoming;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.standalone
          ? AppBar(
              title: const Text('My Bookings'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      body: !auth.isLoggedIn
          ? _buildLoginPrompt()
          : _loading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Container(height: 28, width: 140, decoration: BoxDecoration(color: AppColors.surfaceDim, borderRadius: BorderRadius.circular(8))),
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(4, (_) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        height: 80,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
                      )),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.standalone) ...[
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Your games',
                                  style: AppFonts.display(fontSize: 30, fontWeight: FontWeight.w900),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SlotGroupsScreen()),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.forum_rounded, size: 16, color: AppColors.secondary),
                                      SizedBox(width: 5),
                                      Text('Slot Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _segmented(),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _error != null && _bookings.isEmpty
                          ? _buildLoadError()
                          : shown.isEmpty
                          ? (_bookings.isEmpty
                              ? _buildEmpty()
                              : Center(
                                  child: Text(
                                    _showPast ? 'No past games yet' : 'Nothing coming up. Book a court!',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                ))
                          : RefreshIndicator(
                              onRefresh: _loadBookings,
                              color: AppColors.primary,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                                itemCount: shown.length + (_reviewableBooking != null ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (_reviewableBooking != null) {
                                    if (i == 0) return _buildReviewPrompt(_reviewableBooking!);
                                    i -= 1;
                                  }
                                  // v5: the soonest game gets the "Next up" card.
                                  if (!_showPast && i == 0) return _buildNextUp(shown.first);
                                  return _buildBookingCard(shown[i]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.calendarDays, size: 32, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 16),
          const Text(
            'Login to see your bookings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? 'Could not load bookings', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadBookings, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.card,
            ),
            child: const Icon(AppIcons.calendarDays, size: 32, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 16),
          const Text(
            'No bookings yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Book a court to get started',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _showBookingActions(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(booking['court_name'] ?? 'Booking', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Chat with Owner', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(bookingId: booking['id'])));
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_rounded, color: AppColors.secondary),
              title: const Text('Slot Group Chat', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary)),
              subtitle: const Text('Chat with players in your time slot', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _openSlotChat(booking);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
              title: const Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _cancelBooking(booking['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(dynamic rawId) async {
    final bookingId = int.tryParse('$rawId') ?? 0;
    if (bookingId < 1) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cancel booking?',
      body: 'This follows the venue cancellation terms. Any refund is confirmed after you cancel.',
      cancelLabel: 'Keep',
      confirmLabel: 'Cancel booking',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (confirmed != true) return;

    try {
      final response = await Api().delete('/bookings/$bookingId');
      if (mounted) context.read<ToastProvider>().success(response.data['message'] ?? 'Booking cancelled');
      _loadBookings();
    } catch (error) {
      if (mounted) context.read<ToastProvider>().error(Api.failureMessage(error, fallback: 'Failed to cancel booking'));
    }
  }

  Map<String, dynamic>? get _reviewableBooking {
    for (final b in _bookings) {
      final status = b['status'] ?? '';
      if (status != 'confirmed') continue;
      final endStr = b['end_time'] ?? '';
      try {
        final endDt = DateTime.parse(endStr);
        if (!endDt.isBefore(DateTime.now())) continue;
      } catch (_) {
        continue;
      }
      final key = '${b['id']}';
      if (_dismissedReviews.contains(key)) continue;
      return b;
    }
    return null;
  }

  Widget _buildReviewPrompt(Map<String, dynamic> booking) {
    final courtName = booking['court_name'] ?? 'your venue';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How was $courtName?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _dismissReview('${booking['id']}'),
                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your review helps other players find great venues',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                final userId = auth.userId;
                if (userId == null) {
                  if (mounted) context.go('/login');
                  return;
                }
                final result = await ReviewSheet.show(
                  context,
                  courtId: positiveId(booking['court_id']) ?? 0,
                  userId: userId,
                  courtName: courtName,
                  bookingId: positiveId(booking['id']),
                );
                if (result == true) {
                  _dismissReview('${booking['id']}');
                  if (mounted) context.read<ToastProvider>().success('Review submitted!');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPastBooking(String date, String endTime) {
    try {
      final end = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
      final dt = DateTime.parse('$date ${end.padRight(5, '0')}:00');
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _openSlotChat(Map<String, dynamic> booking) {
    final rawStart = booking['start_time'] ?? '';
    DateTime? startDt;
    try { startDt = DateTime.parse(rawStart); } catch (_) {}
    if (startDt == null) return;

    final date = DateFormat('yyyy-MM-dd').format(startDt);
    final time = DateFormat('HH:mm:ss').format(startDt);
    final slotLabel = '${DateFormat('MMM d').format(startDt)} \u00B7 ${DateFormat('h:mm a').format(startDt)}';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SlotChatScreen(
        courtId: booking['court_id'],
        date: date,
        time: time,
        courtName: booking['court_name'],
        slotLabel: slotLabel,
      ),
    ));
  }

  void _bookAgain(Map<String, dynamic> booking) {
    final courtId = booking['court_id'];
    if (courtId == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtId)));
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final rawStart = booking['start_time'] ?? '';
    final rawEnd = booking['end_time'] ?? '';
    final courtName = booking['court_name'] ?? 'Court';
    final status = booking['status'] ?? 'confirmed';
    final courtId = booking['court_id'];

    // Parse full datetime strings (e.g. "2026-08-30 09:00:00")
    final startDt = parseSqlDateTime('$rawStart');
    final endDt = parseSqlDateTime('$rawEnd');

    final date = startDt != null ? DateFormat('yyyy-MM-dd').format(startDt) : (booking['date'] ?? '');
    String formattedDate = date;
    String dayLabel = '';
    if (startDt != null) {
      formattedDate = DateFormat('MMM d, yyyy').format(startDt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final bookingDay = DateTime(startDt.year, startDt.month, startDt.day);
      if (bookingDay == today) {
        dayLabel = 'Today';
      } else if (bookingDay == tomorrow) {
        dayLabel = 'Tomorrow';
      } else {
        dayLabel = DateFormat('EEEE').format(startDt);
      }
    }

    final isConfirmed = status == 'confirmed';
    final isCancelled = status == 'cancelled';
    final isPast = endDt != null ? endDt.isBefore(DateTime.now()) : _isPastBooking(date, rawEnd);

    final countdown = isConfirmed && !isPast ? passCountdown(startDt, endDt, DateTime.now()) : '';
    final timeRange = startDt == null
        ? '$rawStart'
        : endDt == null
            ? DateFormat('h:mm a').format(startDt)
            : '${DateFormat('h:mm').format(startDt)} – ${DateFormat('h:mm a').format(endDt)}';

    final minutes = startDt != null && endDt != null ? endDt.difference(startDt).inMinutes : 0;
    final price = num.tryParse('${booking['total_price'] ?? ''}') ?? 0;
    final upcoming = isConfirmed && !isPast;
    void openVenue() => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtIdFrom(courtId))));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KoCard(
        // Cancelled games lose their sport colour so live ones stand out.
        sport: isCancelled ? null : booking['court_type'],
        kicker: isPast && isConfirmed ? 'Played' : (dayLabel.isNotEmpty ? dayLabel : formattedDate),
        title: '$courtName',
        meta: '$formattedDate · $timeRange',
        badge: startDt == null ? null : DateFormat('h a').format(startDt),
        stats: isPast && isConfirmed
            ? [
                if (minutes > 0) KoStat('$minutes', 'minutes'),
                if (price > 0) KoStat('₹${price.round()}', 'paid'),
              ]
            : const [],
        middle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                isPast && isConfirmed ? const StatusTag('Played', tone: TagTone.muted) : StatusTag.forBooking('$status'),
                if (countdown.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(child: Text(countdown, style: AppFonts.score(fontSize: 13, color: context.brand.primary))),
                ],
                const Spacer(),
                if (upcoming)
                  TextButton(
                    onPressed: () => _cancelBooking(booking['id']),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error, visualDensity: VisualDensity.compact),
                    child: const Text('Cancel booking'),
                  ),
              ],
            ),
            if (booking['refund_status'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Refund: ${booking['refund_status'].toString().replaceAll('_', ' ')} · INR ${((num.tryParse(booking['refund_amount_paise'].toString()) ?? 0) / 100).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actionLabel: upcoming ? 'Show pass' : (isPast && isConfirmed ? 'Book again' : null),
        onAction: upcoming ? () => context.push('/booking-confirmation/${booking['id']}') : () => _bookAgain(booking),
        onTap: courtId != null ? openVenue : null,
        onLongPress: upcoming ? () => _showBookingActions(booking) : null,
      ),
    );
  }

  Widget _segmented() {
    Widget tab(String label, bool past) {
      final on = _showPast == past;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            onTap: () => setState(() => _showPast = past),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(19),
                boxShadow: on ? const [BoxShadow(color: Color(0x1A111827), blurRadius: 3, offset: Offset(0, 1))] : null,
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? AppColors.textPrimary : AppColors.textSecondary)),
            ),
          ),
        ),
      );
    }

    final count = _upcoming.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFECEEF4), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [tab(count > 0 ? 'Upcoming · $count' : 'Upcoming', false), const SizedBox(width: 4), tab('Past', true)]),
    );
  }

  /// Matchday "Next up": the soonest game as a full card.
  Widget _buildNextUp(Map<String, dynamic> booking) {
    final start = parseSqlDateTime('${booking['start_time'] ?? ''}');
    final end = parseSqlDateTime('${booking['end_time'] ?? ''}');
    final left = start?.difference(DateTime.now());
    final minutes = start != null && end != null ? end.difference(start).inMinutes : 0;
    final price = num.tryParse('${booking['total_price'] ?? ''}') ?? 0;
    final courtId = booking['court_id'];
    void showPass() => context.push('/booking-confirmation/${booking['id']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: KoCard(
        sport: booking['court_type'],
        kicker: 'Next up',
        title: '${booking['court_name'] ?? 'Your game'}',
        meta: start == null || end == null ? null : '${DateFormat('EEE d MMM').format(start)} · ${DateFormat('h:mm').format(start)} – ${DateFormat('h:mm a').format(end)}',
        badge: start == null ? null : DateFormat('h a').format(start),
        stats: [
          if (left != null && !left.isNegative) KoStat(kickoffIn(left), 'to kick-off'),
          if (minutes > 0) KoStat('$minutes', 'minutes'),
          if (price > 0) KoStat('₹${price.round()}', 'paid'),
        ],
        actionLabel: 'Show pass',
        onAction: showPass,
        onTap: courtId == null ? showPass : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtIdFrom(courtId)))),
      ),
    );
  }
}
