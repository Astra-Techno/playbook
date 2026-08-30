import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import 'edit_venue_screen.dart';
import 'spaces_screen.dart';
import 'staff_screen.dart';
import 'venue_earnings_screen.dart';
import 'calendar_screen.dart';
import 'venue_members_screen.dart';
import '../bookings/block_slots_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/courts/${widget.courtId}');
      setState(() {
        _court = Map<String, dynamic>.from(res.data['court'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_court == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Venue not found')));
    }

    final img = getVenueImage(_court!);

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
                      if (_court!['is_verified'] == true || _court!['is_verified'] == 1) ...[
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
                    Text('₹${_court!['hourly_rate']}/slot', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                  const SizedBox(height: 24),
                  _sectionLabel('MANAGE'),
                  _menuItem(AppIcons.pencil, 'Edit Venue', 'Update name, location, rate', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditVenueScreen(courtId: widget.courtId))).then((_) => _load());
                  }),
                  _menuItem(AppIcons.calendarDays, 'Booking Calendar', 'Day & week view of all bookings', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen(courtId: widget.courtId)));
                  }),
                  _menuItem(AppIcons.layoutGrid, 'Spaces', 'Manage courts, lanes, rooms', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SpacesScreen(courtId: widget.courtId)));
                  }),
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
                  _menuItem(Icons.trending_up, 'Earnings', 'Revenue & transaction history', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => VenueEarningsScreen(courtId: widget.courtId)));
                  }),
                  _menuItem(Icons.price_change_outlined, 'Pricing Rules', 'Peak, off-peak, weekend rates', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PricingScreen(courtId: widget.courtId)));
                  }),
                  _menuItem(AppIcons.award, 'Subscription Plans', 'Create & manage plans', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManagePlansScreen(courtId: widget.courtId)));
                  }),
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
        content: const Text('This cannot be undone.'),
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
    } catch (_) {}
  }
}
