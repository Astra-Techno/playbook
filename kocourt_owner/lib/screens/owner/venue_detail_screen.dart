import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'edit_venue_screen.dart';
import 'spaces_screen.dart';
import 'staff_screen.dart';
import 'venue_earnings_screen.dart';
import 'venue_listing.dart';
import 'calendar_screen.dart';
import 'venue_members_screen.dart';
import 'block_slots_screen.dart';
import 'pricing_screen.dart';
import 'manage_plans_screen.dart';

class VenueDetailScreen extends StatefulWidget {
  final int courtId;
  const VenueDetailScreen({super.key, required this.courtId});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  Map<String, dynamic>? _court;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    Map<String, dynamic>? court;
    try {
      final res = await Api().get('/courts/${widget.courtId}');
      final raw = res.data['court'] ?? res.data;
      if (raw is Map) court = Map<String, dynamic>.from(raw);
      if (court == null) error = 'Venue not found.';
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load this venue.');
    }
    if (!mounted) return;
    setState(() {
      _court = court;
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_court == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Venue not found.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: () {
                  setState(() => _loading = true);
                  _load();
                }, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    final img = getVenueImage(_court!);
    final canManage = venueOwnedBy(_court!, context.watch<AuthProvider>().userId);
    final verified = venueIsVerified(_court!['is_verified']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(_court!['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                      if (verified) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified_rounded, size: 20, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(AppIcons.mapPin, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(_court!['location'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
                    ],
                  ),
                  if (_court!['hourly_rate'] != null) ...[
                    const SizedBox(height: 8),
                    Text('\u20B9${_court!['hourly_rate']}/slot', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                  const SizedBox(height: 16),
                  _statusCard(
                    venueListingLabel(_court!['claim_status']),
                    venueVerificationLabel(_court!['is_verified']),
                    _court!['claim_rejection_reason']?.toString(),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('MANAGE'),
                  if (canManage)
                    _menuItem(AppIcons.pencil, 'Edit Venue', 'Update name, location, rate, photos', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditVenueScreen(courtId: widget.courtId))).then((_) => _load());
                    }),
                  _menuItem(AppIcons.calendarDays, 'Booking Calendar', 'Day view of bookings', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen(courtId: widget.courtId)));
                  }),
                  _menuItem(AppIcons.layoutGrid, 'Spaces', canManage ? 'Manage courts, lanes, rooms' : 'View courts, lanes, rooms', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SpacesScreen(courtId: widget.courtId))).then((_) => _load());
                  }),
                  if (canManage) ...[
                    const SizedBox(height: 16),
                    _sectionLabel('OPERATIONS'),
                    _menuItem(AppIcons.users, 'Staff', 'Manage staff and permissions', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StaffScreen(courtId: widget.courtId)));
                    }),
                    _menuItem(AppIcons.award, 'Members', 'Active subscribers', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => VenueMembersScreen(courtId: widget.courtId)));
                    }),
                    _menuItem(Icons.block, 'Block Slots', 'Block venue for a period', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BlockSlotsScreen(courtId: widget.courtId)));
                    }),
                    _menuItem(Icons.trending_up, 'Earnings', 'Revenue and transaction history', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => VenueEarningsScreen(courtId: widget.courtId)));
                    }),
                    _menuItem(Icons.price_change_outlined, 'Pricing Rules', 'Peak, off-peak, weekend rates', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PricingScreen(courtId: widget.courtId)));
                    }),
                    _menuItem(AppIcons.award, 'Subscription Plans', 'Create and manage plans', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ManagePlansScreen(courtId: widget.courtId)));
                    }),
                  ],
                  const SizedBox(height: 16),
                  _sectionLabel('PROMOTE'),
                  _menuItem(Icons.share_outlined, 'Share Venue', 'Share via WhatsApp & social media', () {
                    final name = _court!['name'] ?? 'KoCourt Venue';
                    final location = _court!['location'] ?? '';
                    final rate = _court!['hourly_rate'] ?? '';
                    final text = '$name\n${location.isNotEmpty ? '$location\n' : ''}'
                        '${rate.toString().isNotEmpty ? '\u20B9$rate/hr\n' : ''}'
                        '\nBook now on KoCourt!\nhttps://www.kocourt.com/court/${widget.courtId}';
                    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }),
                  const SizedBox(height: 24),
                  if (canManage)
                    SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteCourt(),
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      label: const Text('Delete Venue', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String listing, String verification, String? rejection) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 4),
          Text(verification, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
          if (rejection != null && rejection.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rejection, style: const TextStyle(fontSize: 13, color: AppColors.error, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5)),
    );
  }

  Widget _menuItem(IconData icon, String label, String desc, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 18, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCourt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Venue?'),
        content: const Text(
          'This removes the venue. Existing booking records stay until you delete a venue with no upcoming bookings. A venue with an upcoming booking cannot be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api().delete('/courts/${widget.courtId}');
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.failureMessage(error, fallback: 'Could not delete this venue.')),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
