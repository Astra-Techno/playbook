import 'package:flutter/material.dart';
import '../core/fonts.dart';

import '../core/theme.dart';
import 'ko_card.dart';
import 'sport_tags.dart';

/// Matchday player card shared by both apps: role, name, phone, and the
/// jersey-plate avatar in the badge spot. [stats] fill in once player stats exist.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.phone,
    required this.initial,
    this.avatarUrl,
    this.role,
    this.stats = const [],
  });

  final String name;
  final String phone;
  final String initial;
  final String? avatarUrl;
  final String? role;
  final List<KoStat> stats;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return KoCard(
      kicker: role == null || role!.isEmpty ? null : (role == 'Player' ? 'Player card' : role),
      title: name,
      meta: phone,
      badgeWidget: Slanted(
        child: Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
          alignment: Alignment.center,
          child: hasPhoto
              ? Image.network(avatarUrl!, width: 56, height: 56, fit: BoxFit.cover)
              : Text(initial, style: AppFonts.display(fontSize: 26, color: Colors.white)),
        ),
      ),
      stats: stats,
    );
  }
}

/// Menu row icon on a soft tinted square.
class MenuIcon extends StatelessWidget {
  const MenuIcon(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.brand.primary;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}
