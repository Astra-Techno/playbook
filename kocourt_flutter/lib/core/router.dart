import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../screens/app_shell.dart';
import '../screens/login/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/court_details/court_details_screen.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/bookings/booking_confirmation_screen.dart';
import '../screens/feed/create_post_screen.dart';
import '../screens/feed/post_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/subscriptions/subscriptions_screen.dart';
import '../screens/search/find_courts_screen.dart';
import '../screens/reviews/reviews_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_threads_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/chat/group_info_screen.dart';
import '../screens/static/faq_screen.dart';
import '../screens/static/terms_screen.dart';
import '../screens/static/privacy_screen.dart';
import '../screens/payments/payment_history_screen.dart';

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

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      final isGuestRoute = state.matchedLocation == '/onboarding';
      final isPublic = state.matchedLocation == '/' ||
          state.matchedLocation == '/faq' ||
          state.matchedLocation == '/terms' ||
          state.matchedLocation == '/privacy' ||
          state.matchedLocation == '/refund-policy' ||
          state.matchedLocation == '/contact' ||
          state.matchedLocation == '/find-courts' ||
          state.matchedLocation.startsWith('/courts/') ||
          state.matchedLocation.startsWith('/feed');

      // Guest-only routes (login, onboarding)
      if (loggedIn && (isLoginRoute || isGuestRoute)) return '/';

      // Auth-required routes
      if (!loggedIn && !isPublic && !isLoginRoute && !isGuestRoute) return '/login';

      return null;
    },
    routes: [
      // Main app with bottom nav
      GoRoute(
        path: '/',
        builder: (_, __) => const AppShell(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _slideFadePage(const LoginScreen(), state),
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // Court details
      GoRoute(
        path: '/courts/:id',
        pageBuilder: (_, state) => _slideFadePage(
          CourtDetailsScreen(
            courtId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
          state,
        ),
      ),

      // Bookings
      GoRoute(
        path: '/bookings',
        pageBuilder: (_, state) => _slideFadePage(const BookingsScreen(standalone: true), state),
      ),
      GoRoute(
        path: '/booking-confirmation/:bookingId',
        builder: (_, state) => BookingConfirmationScreen(
          bookingId: int.tryParse(state.pathParameters['bookingId'] ?? '') ?? 0,
        ),
      ),

      // Feed
      GoRoute(
        path: '/feed/:id',
        builder: (_, state) => PostDetailScreen(
          postId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/post/create', builder: (_, __) => const CreatePostScreen()),

      // Player
      GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
      GoRoute(path: '/payment-history', builder: (_, __) => const PaymentHistoryScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/find-courts', builder: (_, __) => const FindCourtsScreen()),
      GoRoute(path: '/reviews', builder: (_, __) => const ReviewsScreen()),

      // Map
      GoRoute(path: '/map', builder: (_, __) => const MapScreen()),

      // Chat (new system)
      GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/chats/:groupId',
        pageBuilder: (_, state) => _slideFadePage(
          GroupChatScreen(groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0),
          state,
        ),
      ),
      GoRoute(
        path: '/chats/:groupId/info',
        pageBuilder: (_, state) => _slideFadePage(
          GroupInfoScreen(groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0),
          state,
        ),
      ),

      // Legacy chat (booking-based)
      GoRoute(path: '/messages', builder: (_, __) => const ChatThreadsScreen()),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (_, state) => ChatScreen(
          bookingId: int.tryParse(state.pathParameters['bookingId'] ?? '') ?? 0,
        ),
      ),

      // Static
      GoRoute(path: '/faq', builder: (_, __) => const FaqScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/refund-policy', builder: (_, __) => const RefundCancellationScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactSupportScreen()),
    ],
  );
}
