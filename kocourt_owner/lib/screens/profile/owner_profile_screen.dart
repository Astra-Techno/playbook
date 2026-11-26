import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import '../owner/owner_copy.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ownerLanguage.addListener(_onLanguage);
    loadOwnerLanguage();
    _load();
  }

  void _onLanguage() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ownerLanguage.removeListener(_onLanguage);
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    try {
      final res = await Api().get('/auth/profile');
      final fresh = res.data['user'];
      if (fresh is! Map) {
        throw const FormatException('Profile response was incomplete.');
      }
      await auth.replaceCachedUser(Map<String, dynamic>.from(fresh));
    } catch (caught) {
      error = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not load your profile.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = (user?['name'] ?? 'Owner').toString();
    final phone = (user?['phone'] ?? '').toString();
    final avatar = user?['avatar_url'];
    final initial = name.trim().isEmpty ? 'O' : name.trim()[0].toUpperCase();
    final phase = tabPhase(
      loading: _loading,
      failed: _error != null,
      hasData: user != null,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: ownerLanguage,
          builder: (context, language, _) => Text(ownerPhrase(language, 'profile'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: phase == TabPhase.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
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
                  if (user == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: TabEmptyMessage(
                        icon: AppIcons.user,
                        title: 'No profile saved',
                        subtitle: 'Sign in again to restore this account',
                      ),
                    )
                  else ...[
                    ProfileHeader(
                      name: name,
                      phone: phone,
                      initial: initial,
                      avatarUrl: avatar is String ? avatar : null,
                      role: auth.isAdmin ? 'Admin' : 'Venue owner',
                    ),
                    const SizedBox(height: 20),

            _menuItem(Icons.person_outline, 'Edit Profile', () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ProfileEditSheet(),
              );
            }),
            _menuItem(Icons.notifications_outlined, ownerPhrase(ownerLanguage.value, 'notifications'), () {
              context.push('/notifications');
            }),
            ValueListenableBuilder<String>(
              valueListenable: ownerLanguage,
              builder: (context, language, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 22, color: AppColors.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(child: Text(ownerPhrase(language, 'language'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                    Semantics(
                      button: true,
                      selected: language == 'en',
                      label: ownerTabLabel(language, 'english', selected: language == 'en'),
                      child: TextButton(
                        onPressed: () => chooseOwnerLanguage('en'),
                        child: Text(
                          ownerPhrase(language, 'english'),
                          style: TextStyle(fontWeight: language == 'en' ? FontWeight.w800 : FontWeight.w500, color: language == 'en' ? AppColors.primary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      selected: language == 'ta',
                      label: ownerTabLabel(language, 'tamil', selected: language == 'ta'),
                      child: TextButton(
                        onPressed: () => chooseOwnerLanguage('ta'),
                        child: Text(
                          ownerPhrase(language, 'tamil'),
                          style: TextStyle(fontWeight: language == 'ta' ? FontWeight.w800 : FontWeight.w500, color: language == 'ta' ? AppColors.primary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _menuItem(Icons.emoji_events_outlined, 'Events', () {
              context.push('/events');
            }),
            _menuItem(Icons.account_balance_outlined, 'Payout Settings', () {
              context.push('/payout-settings');
            }),
            if (auth.isAdmin)
              _menuItem(Icons.admin_panel_settings_outlined, 'Admin Panel', () {
                context.push('/admin');
              }),
            const Divider(height: 32),
            _menuItem(Icons.receipt_long_outlined, 'Refund & Cancellation', () {
              context.push('/refund-policy');
            }),
            _menuItem(Icons.support_agent_outlined, 'Contact Support', () {
              context.push('/contact');
            }),
            const Divider(height: 32),
            _menuItem(Icons.logout, 'Logout', () async {
              final authProvider = context.read<AuthProvider>();
              final confirm = await AppConfirmDialog.show(
                context,
                title: 'Log out?',
                body: 'Are you sure you want to log out of KoCourt Owner?',
                confirmLabel: 'Log out',
                destructive: true,
                icon: Icons.logout_rounded,
              );
              if (confirm == true) {
                authProvider.logout();
              }
            }, color: AppColors.error),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            MenuIcon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color))),
            Icon(AppIcons.chevronRight, size: 18, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
