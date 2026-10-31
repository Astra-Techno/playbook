import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/core/router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:provider/provider.dart';

void main() {
  test('logged-out visitors are sent to login, except public legal pages', () {
    expect(
      ownerRouteRedirect(loggedIn: false, isAdmin: false, location: '/'),
      '/login',
    );
    expect(
      ownerRouteRedirect(loggedIn: false, isAdmin: false, location: '/admin'),
      '/login',
    );
    expect(
      ownerRouteRedirect(loggedIn: false, isAdmin: false, location: '/refund-policy'),
      isNull,
    );
    expect(
      ownerRouteRedirect(loggedIn: false, isAdmin: false, location: '/contact'),
      isNull,
    );
  });

  test('a signed-in owner stays on home', () {
    expect(
      ownerRouteRedirect(loggedIn: true, isAdmin: false, location: '/'),
      isNull,
    );
    expect(
      ownerRouteRedirect(loggedIn: true, isAdmin: false, location: '/login'),
      '/',
    );
  });

  test('a signed-in non-admin is sent home from admin', () {
    expect(
      ownerRouteRedirect(loggedIn: true, isAdmin: false, location: '/admin'),
      '/',
    );
    expect(
      ownerRouteRedirect(loggedIn: true, isAdmin: true, location: '/admin'),
      isNull,
    );
  });

  testWidgets('the owner router opens login when nobody is signed in', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider();
    final router = createOwnerRouter(auth);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Continue'), findsOneWidget);
  });
}
