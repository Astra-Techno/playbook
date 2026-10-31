import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'booking_detail_screen.dart';
import 'walk_in_fields.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bookings', style: TextStyle(fontWeight: FontWeight.w800)),
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
        padding: const EdgeInsets.all(20),
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
                subtitle: 'Bookings will appear here',
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
