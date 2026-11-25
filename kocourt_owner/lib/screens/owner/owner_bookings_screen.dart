import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'booking_detail_screen.dart';
import 'walk_in_fields.dart';
import '../../widgets/sheets/walkin_sheet.dart';

class OwnerBookingsScreen extends StatefulWidget {
  final bool active;
  const OwnerBookingsScreen({super.key, this.active = true});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(OwnerBookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final ownerId = auth.userId;
    if (ownerId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again.';
        });
      }
      return;
    }
    if (_bookings.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    List<Map<String, dynamic>>? bookings;
    try {
      final res = await Api().get('/bookings', params: {'owner_id': ownerId});
      bookings = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load bookings.');
    }
    if (!mounted) return;
    setState(() {
      if (bookings != null) _bookings = bookings;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _addBooking() async {
    final auth = context.read<AuthProvider>();
    final ownerId = auth.userId;
    if (ownerId == null) {
      if (!mounted) return;
      context.toastInfo('Please sign in again.');
      return;
    }
    try {
      final res = await Api().get('/courts', params: {'owner_id': ownerId});
      final courts = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      if (!mounted) return;
      if (courts.isEmpty) {
        context.toastInfo('Add a venue before recording a booking.');
        return;
      }
      final court = courts.length == 1 ? courts.first : await _pickVenue(courts);
      final courtId = int.tryParse('${court?['id']}');
      if (court == null || courtId == null || courtId <= 0 || !mounted) return;
      final saved = await WalkInSheet.open(context, courtId: courtId, date: bookingDay(DateTime.now()));
      if (saved && mounted) _load();
    } catch (caught) {
      if (!mounted) return;
      context.toastError(Api.failureMessage(caught, fallback: 'Could not load your venues.'));
    }
  }

  Future<Map<String, dynamic>?> _pickVenue(List<Map<String, dynamic>> courts) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a venue', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final court in courts)
              ListTile(
                title: Text('${court['name'] ?? 'Venue'}'),
                onTap: () => Navigator.pop(context, court),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Bookings'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBooking,
        icon: const Icon(Icons.add),
        label: const Text('Add booking'),
      ),
      body: _bookingsBody(),
    );
  }

  Widget _bookingsBody() {
    final phase = tabPhase(
      loading: _loading,
      failed: _error != null,
      hasData: _bookings.isNotEmpty,
    );
    if (phase == TabPhase.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          if (_error != null) ...[
            TabErrorBanner(message: _error!, onRetry: _load),
            const SizedBox(height: 16),
          ],
          if (phase == TabPhase.empty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: TabEmptyMessage(
                icon: AppIcons.calendarDays,
                title: 'No bookings yet',
                subtitle: 'Use Add booking to record a guest',
              ),
            )
          else
            ..._bookings.map(_bookingTile),
        ],
      ),
    );
  }

  Widget _bookingTile(Map<String, dynamic> b) {
    final status = (b['status'] ?? 'confirmed').toString();
    final start = DateTime.tryParse('${b['start_time'] ?? ''}');
    final person = '${b['guest_name'] ?? b['user_name'] ?? ''}'.isNotEmpty ? bookingPerson(b) : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            final id = int.tryParse('${b['id']}');
            if (id == null) return;
            Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: id)),
            ).then((changed) {
              if (changed == true) _load();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TimePlate(
                  top: start == null ? '\u2014' : DateFormat('h a').format(start),
                  bottom: start == null ? '' : DateFormat('EEE d MMM').format(start),
                  filled: status != 'cancelled',
                  width: 76,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b['court_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (person.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(person, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusTag.forBooking(status),
                    if (b['attendance'] == 'checked_in') ...[
                      const SizedBox(height: 6),
                      const StatusTag('Checked in', tone: TagTone.brand),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
