import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/icons.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/toast_provider.dart';
import '../court_details/court_details_screen.dart';
import '../chat/chat_screen.dart';

class BookingsScreen extends StatefulWidget {
  final bool standalone;
  const BookingsScreen({super.key, this.standalone = false});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Api().get('/bookings', params: {'user_id': auth.userId});
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(
          (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.standalone) ...[
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: const Text(
                            'Bookings',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
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
                                itemCount: _bookings.length,
                                itemBuilder: (_, i) => _buildBookingCard(_bookings[i]),
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
              title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(bookingId: booking['id'])));
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
      await Api().delete('/bookings/$bookingId');
      context.read<ToastProvider>().success('Booking cancelled');
      _loadBookings();
    } catch (_) {
      if (mounted) context.read<ToastProvider>().error('Failed to cancel booking');
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final date = booking['date'] ?? '';
    final start = booking['start_time'] ?? '';
    final end = booking['end_time'] ?? '';
    final courtName = booking['court_name'] ?? 'Court';
    final status = booking['status'] ?? 'confirmed';
    final courtId = booking['court_id'];

    String formattedDate = date;
    String dayLabel = '';
    try {
      final parsed = DateTime.parse(date);
      formattedDate = DateFormat('MMM d, yyyy').format(parsed);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final bookingDay = DateTime(parsed.year, parsed.month, parsed.day);
      if (bookingDay == today) {
        dayLabel = 'Today';
      } else if (bookingDay == tomorrow) {
        dayLabel = 'Tomorrow';
      } else {
        dayLabel = DateFormat('EEEE').format(parsed);
      }
    } catch (_) {}

    final isConfirmed = status == 'confirmed';
    final isCancelled = status == 'cancelled';

    final startFormatted = start.length >= 5 ? start.substring(0, 5) : start;
    final endFormatted = end.length >= 5 ? end.substring(0, 5) : end;

    return GestureDetector(
      onTap: courtId != null
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtDetailsScreen(courtId: courtId)))
          : null,
      onLongPress: isConfirmed
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
                      // Status badge
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
