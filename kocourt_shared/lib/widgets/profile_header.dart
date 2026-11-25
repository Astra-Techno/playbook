import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import 'sport_tags.dart';

/// v4 profile header shared by both apps: jersey-plate avatar, name, phone and role tag.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.phone,
    required this.initial,
    this.avatarUrl,
    this.role,
  });

  final String name;
  final String phone;
  final String initial;
  final String? avatarUrl;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Slanted(
            child: Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: hasPhoto
                  ? Image.network(avatarUrl!, width: 64, height: 64, fit: BoxFit.cover)
                  : Text(initial, style: GoogleFonts.archivo(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.archivo(fontSize: 22, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (phone.isNotEmpty)
                  Text(phone, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                if (role != null && role!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  StatusTag(role!, tone: TagTone.brand),
                ],
              ],
            ),
          ),
        ],
      ),
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
