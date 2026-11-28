import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../reviews/reviews_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../chat/chat_list_screen.dart';
import '../static/faq_screen.dart';
import '../static/terms_screen.dart';
import '../static/privacy_screen.dart';
import '../payments/payment_history_screen.dart';
import 'profile_logic.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Player card numbers (GET /players/stats); the card shows without them.
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!context.read<AuthProvider>().isLoggedIn) return;
    try {
      final res = await Api().get('/players/stats');
      if (mounted && res.data is Map) setState(() => _stats = Map<String, dynamic>.from(res.data as Map));
    } catch (_) {
      // Older server or offline: the card keeps name and phone only.
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

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await auth.refreshUser();
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Profile card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ProfileHeader(
                        name: auth.userName,
                        phone: auth.userPhone.isEmpty ? '' : '+91 ${auth.userPhone}',
                        initial: auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                        avatarUrl: auth.avatarUrl,
                        role: 'Player',
                        stats: playerCardStats(_stats),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bookings, Explore and the notification bell already have their own places,
                    // so Profile only lists what lives here.
                    const _SectionLabel('Your account'),
                    _MenuSection(
                      children: [
                        _MenuItem(icon: AppIcons.user, label: 'Edit profile', onTap: () => ProfileEditSheet.show(context)),
                        _MenuItem(
                          icon: AppIcons.award,
                          label: 'Memberships',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.wallet,
                          label: 'Payments and refunds',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.star,
                          label: 'Your reviews',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
                        ),
                        _MenuItem(
                          icon: AppIcons.messageCircle,
                          label: 'Messages',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                        ),
                      ],
                    ),
                    const _SectionLabel('Help'),
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.helpCircle,
                          label: 'Help and FAQ',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())),
                        ),
                        _MenuItem(icon: AppIcons.phone, label: 'Contact support', onTap: () => context.push('/contact')),
                        _MenuItem(icon: AppIcons.fileText, label: 'Terms and policies', onTap: () => _showPolicies(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MenuSection(
                      children: [
                        _MenuItem(
                          icon: AppIcons.logOut,
                          label: 'Log out',
                          color: AppColors.error,
                          showChevron: false,
                          onTap: () async {
                            final ok = await AppConfirmDialog.show(
                              context,
                              title: 'Log out?',
                              body: 'You can sign in again with your mobile number.',
                              cancelLabel: 'Stay',
                              confirmLabel: 'Log out',
                              destructive: true,
                              icon: AppIcons.logOut,
                            );
                            if (ok == true) await auth.logout();
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

/// Terms, privacy and refunds in one place instead of three rows.
void _showPolicies(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.fileText),
            title: const Text('Terms and conditions'),
            onTap: () {
              Navigator.pop(sheet);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.shield),
            title: const Text('Privacy policy'),
            onTap: () {
              Navigator.pop(sheet);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.wallet),
            title: const Text('Refunds and cancellations'),
            onTap: () {
              Navigator.pop(sheet);
              context.push('/refund-policy');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Align(alignment: Alignment.centerLeft, child: Text(text, style: AppFonts.display(fontSize: 15, color: AppColors.textSecondary))),
      );
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
        border: Border.all(color: AppColors.border),
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
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
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
            MenuIcon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.textPrimary,
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
