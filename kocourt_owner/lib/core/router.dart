import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../screens/app_shell.dart';
import '../screens/login/login_screen.dart';
import '../screens/owner/owner_dashboard_screen.dart';
import '../screens/owner/venue_detail_screen.dart';
import '../screens/owner/edit_venue_screen.dart';
import '../screens/owner/manage_plans_screen.dart';
import '../screens/owner/venue_earnings_screen.dart';
import '../screens/owner/spaces_screen.dart';
import '../screens/owner/space_detail_screen.dart';
import '../screens/owner/venue_members_screen.dart';
import '../screens/owner/staff_screen.dart';
import '../screens/owner/pricing_screen.dart';
import '../screens/owner/calendar_screen.dart';
import '../screens/owner/block_slots_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_threads_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/admin/ledger_screen.dart';
import '../screens/owner/payout_settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _slideFadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

GoRouter createOwnerRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      final isAdminRoute = state.matchedLocation == '/admin';
      final isPublicRoute = state.matchedLocation == '/refund-policy' ||
          state.matchedLocation == '/contact';

      if (loggedIn && isLoginRoute) return '/';
      if (!loggedIn && !isLoginRoute && !isPublicRoute) return '/login';
      if (isAdminRoute && !auth.isAdmin) return '/';

      return null;
    },
    routes: [
      // Main owner shell
      GoRoute(
        path: '/',
        builder: (_, __) => const OwnerAppShell(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _slideFadePage(const LoginScreen(), state),
      ),
      GoRoute(path: '/refund-policy', builder: (_, __) => const RefundCancellationScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactSupportScreen()),

      // Venue management
      GoRoute(path: '/venues', builder: (_, __) => const OwnerDashboardScreen()),
      GoRoute(path: '/venues/new', builder: (_, __) => const EditVenueScreen()),
      GoRoute(
        path: '/venues/:id',
        builder: (_, state) => VenueDetailScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/edit',
        builder: (_, state) => EditVenueScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/venues/:id/calendar',
        builder: (_, state) => CalendarScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/spaces',
        builder: (_, state) => SpacesScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/spaces/:spaceId',
        builder: (_, state) => SpaceDetailScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          spaceId: int.tryParse(state.pathParameters['spaceId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/staff',
        builder: (_, state) => StaffScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/members',
        builder: (_, state) => VenueMembersScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/earnings',
        builder: (_, state) => VenueEarningsScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/pricing',
        builder: (_, state) => PricingScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/plans',
        builder: (_, state) => ManagePlansScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/venues/:id/block',
        builder: (_, state) => BlockSlotsScreen(
          courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),

      // Chat
      GoRoute(path: '/messages', builder: (_, __) => const ChatThreadsScreen()),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (_, state) => ChatScreen(
          bookingId: int.tryParse(state.pathParameters['bookingId'] ?? '') ?? 0,
        ),
      ),

      // Notifications
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/ledger', builder: (_, __) => const LedgerScreen()),
      GoRoute(path: '/payout-settings', builder: (_, __) => const PayoutSettingsScreen()),
    ],
  );
}
