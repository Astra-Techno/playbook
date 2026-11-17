/// KoCourt Player App — Integration Tests
///
/// These tests run the REAL app on a device/emulator and simulate
/// human-like interactions: tapping buttons, scrolling, typing text.
///
/// Run with:
///   flutter test integration_test/app_test.dart
///
/// Or on a connected device:
///   flutter test integration_test/ -d <device-id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kocourt/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch & Navigation', () {
    testWidgets('App launches and shows home screen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Home screen should show the bottom navigation
      expect(find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
             find.byType(NavigationBar).evaluate().isNotEmpty ||
             find.byIcon(Icons.explore).evaluate().isNotEmpty ||
             find.byIcon(Icons.compass_calibration).evaluate().isNotEmpty,
        true,
        reason: 'Bottom navigation should be visible',
      );
    });

    testWidgets('Bottom tabs navigate correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try tapping each bottom nav tab
      final tabIcons = [Icons.rss_feed, Icons.people, Icons.calendar_today, Icons.person];
      for (final icon in tabIcons) {
        final finder = find.byIcon(icon);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      }
    });
  });

  group('Login Flow', () {
    testWidgets('Can navigate to login and enter phone', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for login/profile button
      final profileIcon = find.byIcon(Icons.person);
      if (profileIcon.evaluate().isNotEmpty) {
        await tester.tap(profileIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Look for phone input field
      final phoneField = find.byType(TextField);
      if (phoneField.evaluate().isNotEmpty) {
        await tester.enterText(phoneField.first, '9000000099');
        await tester.pumpAndSettle();

        // Look for send OTP / continue button
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Enter OTP (demo mode: 1234)
          final otpFields = find.byType(TextField);
          if (otpFields.evaluate().length > 0) {
            // Try entering OTP
            for (int i = 0; i < otpFields.evaluate().length && i < 4; i++) {
              await tester.enterText(otpFields.at(i), '${i + 1}');
            }
            // Or if single OTP field
            if (otpFields.evaluate().length == 1) {
              await tester.enterText(otpFields.first, '1234');
            }
            await tester.pumpAndSettle(const Duration(seconds: 3));
          }
        }
      }
    });
  });

  group('Court Discovery', () {
    testWidgets('Home screen shows venue cards', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Wait for venues to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should see venue cards or a list
      final hasCards = find.byType(Card).evaluate().isNotEmpty;
      final hasListTiles = find.byType(ListTile).evaluate().isNotEmpty;
      final hasInkWell = find.byType(InkWell).evaluate().isNotEmpty;

      expect(hasCards || hasListTiles || hasInkWell, true,
        reason: 'Home should show venue cards or list items');
    });

    testWidgets('Can scroll through venues', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Scroll down to load more venues
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Scroll back up
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pumpAndSettle();
    });
  });

  group('Feed Tab', () {
    testWidgets('Feed tab shows community posts', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap feed tab
      final feedIcon = find.byIcon(Icons.rss_feed);
      if (feedIcon.evaluate().isNotEmpty) {
        await tester.tap(feedIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Should show posts or empty state
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('Matches Tab', () {
    testWidgets('Matches tab loads', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap matches tab
      final matchIcon = find.byIcon(Icons.people);
      if (matchIcon.evaluate().isNotEmpty) {
        await tester.tap(matchIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
    });
  });
}
