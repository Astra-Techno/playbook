import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/core/router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('owner router exposes the owner entry route', () {
    final router = createOwnerRouter(AuthProvider());
    expect(router.configuration.routes, isNotEmpty);
  });
}
