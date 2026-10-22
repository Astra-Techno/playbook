import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = user?['name'] ?? 'Owner';
    final phone = user?['phone'] ?? '';
    final avatar = user?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary),
                    )
                  : null,
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
