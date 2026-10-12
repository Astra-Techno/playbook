import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'owner/owner_dashboard_screen.dart';
import 'owner/owner_bookings_screen.dart';
import 'owner/owner_earnings_screen.dart';
import 'chat/chat_threads_screen.dart';
import 'profile/owner_profile_screen.dart';

class OwnerAppShell extends StatefulWidget {
  const OwnerAppShell({super.key});

  @override
  State<OwnerAppShell> createState() => _OwnerAppShellState();
}

class _OwnerAppShellState extends State<OwnerAppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<AnimationController> _iconControllers;

  final _screens = const [
    OwnerDashboardScreen(),
    OwnerBookingsScreen(),
    OwnerEarningsScreen(),
    ChatThreadsScreen(),
    OwnerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(5, (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    ));
  }

  @override
  void dispose() {
    for (final c in _iconControllers) c.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _iconControllers[index].forward().then((_) => _iconControllers[index].reverse());
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 10),
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.bottomBar,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(0, AppIcons.layoutGrid, 'Venues'),
                _navItem(1, AppIcons.calendarDays, 'Bookings'),
                _navItem(2, AppIcons.wallet, 'Earnings'),
                _navItem(3, AppIcons.messageCircle, 'Chat'),
                _navItem(4, AppIcons.user, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.3).animate(
                CurvedAnimation(parent: _iconControllers[index], curve: Curves.easeOutBack),
              ),
              child: Icon(icon, size: 24, color: active ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
