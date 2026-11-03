import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'owner/owner_dashboard_screen.dart';
import 'owner/owner_bookings_screen.dart';
import 'owner/owner_earnings_screen.dart';
import 'chat/chat_threads_screen.dart';
import 'profile/owner_profile_screen.dart';
import 'owner/owner_copy.dart';

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
    loadOwnerLanguage();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) { c.dispose(); }
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 10),
        height: ownerBarHeight(textScale),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.bottomBar,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ValueListenableBuilder<String>(
              valueListenable: ownerLanguage,
              builder: (context, language, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(0, AppIcons.layoutGrid, language, 'venues'),
                  _navItem(1, AppIcons.calendarDays, language, 'bookings'),
                  _navItem(2, AppIcons.wallet, language, 'earnings'),
                  _navItem(3, AppIcons.messageCircle, language, 'chat'),
                  _navItem(4, AppIcons.user, language, 'profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String language, String key) {
    final active = _currentIndex == index;
    final label = ownerPhrase(language, key);
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: ownerTabLabel(language, key, selected: active),
        child: GestureDetector(
          onTap: () => _onTap(index),
          behavior: HitTestBehavior.opaque,
          child: ExcludeSemantics(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
