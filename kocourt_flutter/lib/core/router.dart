import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../screens/app_shell.dart';
import '../screens/login/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/court_details/court_details_screen.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/bookings/booking_confirmation_screen.dart';
import '../screens/feed/create_post_screen.dart';
import '../screens/feed/post_detail_screen.dart';
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
        pageBuilder: (_, state) => _slideFadePage(
          BookingConfirmationScreen(bookingId: int.tryParse(state.pathParameters['bookingId'] ?? '') ?? 0),
          state,
        ),
      ),

      // Feed
      GoRoute(
        path: '/feed/:id',
        pageBuilder: (_, state) => _slideFadePage(
          PostDetailScreen(postId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
          state,
        ),
      ),
      GoRoute(path: '/post/create', pageBuilder: (_, state) => _slideFadePage(const CreatePostScreen(), state)),

      // Player
      GoRoute(path: '/subscriptions', pageBuilder: (_, state) => _slideFadePage(const SubscriptionsScreen(), state)),
      GoRoute(path: '/payment-history', pageBuilder: (_, state) => _slideFadePage(const PaymentHistoryScreen(), state)),
      GoRoute(path: '/notifications', pageBuilder: (_, state) => _slideFadePage(const NotificationsScreen(), state)),
      GoRoute(path: '/find-courts', pageBuilder: (_, state) => _slideFadePage(const FindCourtsScreen(), state)),
      GoRoute(path: '/reviews', pageBuilder: (_, state) => _slideFadePage(const ReviewsScreen(), state)),

      // Map
      GoRoute(path: '/map', pageBuilder: (_, state) => _slideFadePage(const MapScreen(), state)),

      // Chat (new system)
      GoRoute(path: '/chats', pageBuilder: (_, state) => _slideFadePage(const ChatListScreen(), state)),
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
      GoRoute(path: '/messages', pageBuilder: (_, state) => _slideFadePage(const ChatThreadsScreen(), state)),
      GoRoute(
        path: '/chat/:bookingId',
        pageBuilder: (_, state) => _slideFadePage(
          ChatScreen(bookingId: int.tryParse(state.pathParameters['bookingId'] ?? '') ?? 0),
          state,
        ),
      ),

      // Static
      GoRoute(path: '/faq', pageBuilder: (_, state) => _slideFadePage(const FaqScreen(), state)),
      GoRoute(path: '/terms', pageBuilder: (_, state) => _slideFadePage(const TermsScreen(), state)),
      GoRoute(path: '/privacy', pageBuilder: (_, state) => _slideFadePage(const PrivacyScreen(), state)),
      GoRoute(path: '/refund-policy', pageBuilder: (_, state) => _slideFadePage(const RefundCancellationScreen(), state)),
      GoRoute(path: '/contact', pageBuilder: (_, state) => _slideFadePage(const ContactSupportScreen(), state)),
    ],
  );
}
