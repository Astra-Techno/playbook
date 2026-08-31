import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../bookings/bookings_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import '../owner/venue_earnings_screen.dart';
import '../reviews/reviews_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../search/find_courts_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_threads_screen.dart';
import '../static/faq_screen.dart';
import '../static/terms_screen.dart';
import '../static/privacy_screen.dart';
import '../owner/edit_venue_screen.dart';
import '../payments/payment_history_screen.dart';
import '../../widgets/sheets/profile_edit_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _venueCount = 0;
  bool _venueChecked = false;

  @override
  void initState() {
    super.initState();
    _checkVenues();
  }

  Future<void> _checkVenues() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final res = await Api().get('/courts', params: {'owner_id': auth.userId});
      final records = res.data['records'] as List? ?? [];
      if (mounted) setState(() { _venueCount = records.length; _venueChecked = true; });
    } catch (_) {
      if (mounted) setState(() => _venueChecked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(AppIcons.user, size: 36, color: AppColors.textDisabled),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Login to view your profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track bookings, manage venues & more',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Login / Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final bool hasVenues = _venueCount > 0;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await auth.refreshUser();
                await _checkVenues();
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Profile card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 3),
                            ),
                            child: ClipOval(
                              child: auth.avatarUrl != null
                                  ? CachedNetworkImage(imageUrl: auth.avatarUrl!, fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      alignment: Alignment.center,
                                      child: Text(
                                        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.userName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(AppIcons.phone, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+91 ${auth.userPhone}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => ProfileEditSheet.show(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(AppRadius.full),
                                    ),
                                    child: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Venue management section — data-driven
                    if (hasVenues) ...[
                      _MenuSection(
                        children: [
                          _MenuItem(
                            icon: AppIcons.layoutGrid,
                            label: 'My Venues',
                            badge: '$_venueCount',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardScreen())).then((_) => _checkVenues()),
                          ),
                          _MenuItem(
                            icon: AppIcons.wallet,
                            label: 'Earnings',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VenueEarningsScreen(courtId: 0))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (!hasVenues && _venueChecked) ...[
                      // CTA to list a venue
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(AppIcons.plus, size: 22, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'List Your Venue',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Add your court, gym or arena',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(AppIcons.chevronRight, size: 18, color: AppColors.textDisabled),
                          ],
                        ),
                      ).wrapTap(() {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EditVenueScreen())).then((_) => _checkVenues());
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Main menu section
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.calendarDays,
                          label: 'My Bookings',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsScreen(standalone: true))),
                        ),
                        _MenuItem(
                          icon: AppIcons.star,
                          label: 'Reviews',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.award,
                          label: 'My Memberships',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.wallet,
                          label: 'Payment History',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.mapPin,
                          label: 'Find Available Courts',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindCourtsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.messageCircle,
                          label: 'Messages',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatThreadsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.bell,
                          label: 'Notifications',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Support section
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.helpCircle,
                          label: 'Help & FAQ',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.fileText,
                          label: 'Terms & Conditions',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.shield,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Logout
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.logOut,
                          label: 'Logout',
                          color: AppColors.error,
                          showChevron: false,
                          onTap: () async {
                            await auth.logout();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'v1.0.0',
                      style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extension to wrap any widget with GestureDetector
extension _TapWrap on Widget {
  Widget wrapTap(VoidCallback onTap) => GestureDetector(onTap: onTap, child: this);
}

class _MenuSection extends StatelessWidget {
  final List<Widget> children;
  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Divider(height: 1, color: AppColors.borderLight),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? AppColors.textSecondary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (showChevron)
              Icon(AppIcons.chevronRight, size: 16, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
