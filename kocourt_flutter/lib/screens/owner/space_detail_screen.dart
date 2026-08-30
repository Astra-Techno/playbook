import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import 'pricing_screen.dart';
import 'manage_plans_screen.dart';
import '../bookings/block_slots_screen.dart';

class SpaceDetailScreen extends StatefulWidget {
  final int courtId;
  final int spaceId;
  const SpaceDetailScreen({super.key, required this.courtId, required this.spaceId});

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  Map<String, dynamic>? _space;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/sub-courts/${widget.spaceId}');
      setState(() {
        _space = Map<String, dynamic>.from(res.data['sub_court'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_space == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Space')),
        body: const Center(child: Text('Space not found')),
      );
    }

    final imageUrl = _space!['image_url'] ?? getVenueImage({});
    final mode = _space!['booking_mode'] ?? 'exclusive';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: mode == 'shared' ? AppColors.info : AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            mode.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _space!['name'] ?? 'Space',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        _infoRow('Hourly Rate', '\u20B9${_space!['hourly_rate'] ?? '-'}/hr'),
                        if (_space!['capacity'] != null) ...[
                          const Divider(height: 24),
                          _infoRow('Capacity', '${_space!['capacity']} players'),
                        ],
                        if (_space!['description'] != null && _space!['description'].toString().isNotEmpty) ...[
                          const Divider(height: 24),
                          _infoRow('Description', _space!['description']),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Menu items
                  const Text(
                    'MANAGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        _menuItem(
                          Icons.attach_money_rounded,
                          'Pricing Rules',
                          'Set dynamic pricing by day/hour',
                          () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PricingScreen(courtId: widget.courtId, spaceId: widget.spaceId),
                          )),
                        ),
                        const Divider(height: 1, indent: 56),
                        _menuItem(
                          Icons.card_membership_rounded,
                          'Plans',
                          'Membership plans for this space',
                          () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ManagePlansScreen(courtId: widget.courtId, spaceId: widget.spaceId),
                          )),
                        ),
                        const Divider(height: 1, indent: 56),
                        _menuItem(
                          Icons.block_rounded,
                          'Block Slots',
                          'Block time slots for maintenance',
                          () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => BlockSlotsScreen(courtId: widget.courtId, spaceId: widget.spaceId),
                          )),
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
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
