import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';

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
    _load();
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
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: avatar is String && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar is String && avatar.isNotEmpty
                          ? null
                          : Text(
                              initial,
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(phone, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            if (auth.isAdmin) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
              ),
            ],
            const SizedBox(height: 32),

            _menuItem(Icons.person_outline, 'Edit Profile', () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ProfileEditSheet(),
              );
            }),
            _menuItem(Icons.notifications_outlined, 'Notifications', () {
              context.push('/notifications');
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
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                  ],
                ),
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
            Icon(icon, size: 22, color: color ?? Colors.grey[700]),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
            Icon(AppIcons.chevronRight, size: 18, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
