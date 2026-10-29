import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../court_details/court_details_screen.dart';
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
  Set<String> _dismissedReviews = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedReviews();
    _loadBookings();
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
    if (!auth.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Api().get('/bookings', params: {'user_id': auth.userId});
      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(
            (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
                              const Expanded(
                                child: Text(
                                  'Bookings',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
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
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _bookings.isEmpty
                              ? 'No bookings yet'
                              : '${_bookings.length} booking${_bookings.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: _bookings.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _loadBookings,
                              color: AppColors.primary,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                                itemCount: _bookings.length + (_reviewableBooking != null ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (_reviewableBooking != null) {
                                    if (i == 0) return _buildReviewPrompt(_reviewableBooking!);
                                    return _buildBookingCard(_bookings[i - 1]);
                                  }
                                  return _buildBookingCard(_bookings[i]);
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

  Future<void> _cancelBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await Api().delete('/bookings/$bookingId');
      if (mounted) context.read<ToastProvider>().success(response.data['message'] ?? 'Booking cancelled');
      _loadBookings();
    } catch (_) {
      if (mounted) context.read<ToastProvider>().error('Failed to cancel booking');
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
                final result = await ReviewSheet.show(
                  context,
                  courtId: booking['court_id'],
                  userId: auth.userId ?? 0,
                  courtName: courtName,
                  bookingId: booking['id'],
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
    DateTime? startDt;
    DateTime? endDt;
    try { startDt = DateTime.parse(rawStart); } catch (_) {}
    try { endDt = DateTime.parse(rawEnd); } catch (_) {}

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

    final startFormatted = startDt != null ? DateFormat('HH:mm').format(startDt) : rawStart;
    final endFormatted = endDt != null ? DateFormat('HH:mm').format(endDt) : rawEnd;

    return GestureDetector(
      onTap: courtId != null
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtId)))
          : null,
      onLongPress: isConfirmed && !isPast
          ? () => _showBookingActions(booking)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? AppColors.secondary
                      : isCancelled
                          ? AppColors.error
                          : AppColors.textMuted,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Time block
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? AppColors.secondary.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              startFormatted,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isConfirmed ? AppColors.secondary : AppColors.textMuted,
                              ),
                            ),
                            if (endFormatted.isNotEmpty) ...[
                              Container(
                                width: 8,
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                color: isConfirmed
                                    ? AppColors.secondary.withValues(alpha: 0.3)
                                    : AppColors.textDisabled,
                              ),
                              Text(
                                endFormatted,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isConfirmed
                                      ? AppColors.secondary.withValues(alpha: 0.6)
                                      : AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              courtName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (booking['refund_status'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Refund: ${booking['refund_status'].toString().replaceAll('_', ' ')} · INR ${((num.tryParse(booking['refund_amount_paise'].toString()) ?? 0) / 100).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(AppIcons.calendarDays, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                if (dayLabel.isNotEmpty) ...[
                                  Text(
                                    dayLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: dayLabel == 'Today' ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    ' \u00B7 ',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                                Text(
                                  formattedDate,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge or Book Again
                      if (isPast && isConfirmed)
                        GestureDetector(
                          onTap: () => _bookAgain(booking),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.replay_rounded, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Book Again', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isConfirmed
                                ? AppColors.secondary.withValues(alpha: 0.08)
                                : isCancelled
                                    ? AppColors.errorLight
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isConfirmed
                                      ? AppColors.secondary
                                      : isCancelled
                                          ? AppColors.error
                                          : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                status[0].toUpperCase() + status.substring(1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isConfirmed
                                      ? AppColors.secondary
                                      : isCancelled
                                          ? AppColors.error
                                          : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
