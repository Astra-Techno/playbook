import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'booking_detail_screen.dart';
import 'walk_in_fields.dart';
import '../../widgets/sheets/walkin_sheet.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

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
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (_bookings.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    List<Map<String, dynamic>>? bookings;
    try {
      final res = await Api().get('/bookings', params: {'owner_id': auth.userId});
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
    try {
      final res = await Api().get('/courts', params: {'owner_id': auth.userId});
      final courts = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      if (!mounted) return;
      if (courts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a venue before recording a booking.')),
        );
        return;
      }
      final court = courts.length == 1 ? courts.first : await _pickVenue(courts);
      final courtId = int.tryParse('${court?['id']}');
      if (court == null || courtId == null || courtId <= 0 || !mounted) return;
      final saved = await WalkInSheet.open(context, courtId: courtId, date: bookingDay(DateTime.now()));
      if (saved && mounted) _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'Could not load your venues.'))),
      );
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bookings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBooking,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                      final isCancelled = status == 'cancelled';
                      final statusColor = isCancelled ? AppColors.error : AppColors.secondary;
                      return InkWell(
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
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[100]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(AppIcons.calendarDays, size: 18, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b['court_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 3),
                                  Text('${b['date'] ?? ''} \u2022 ${b['start_time'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  if ('${b['guest_name'] ?? b['user_name'] ?? ''}'.isNotEmpty)
                                    Text(bookingPerson(b), style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
  }
}
