import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/core/router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('player router exposes the player entry route', () {
    final router = createRouter(AuthProvider());
    expect(router.configuration.routes, isNotEmpty);
  });
}
