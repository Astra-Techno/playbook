import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/dashboard_load.dart';

void main() {
  test('venue reads that do not depend on each other finish together', () async {
    final clock = Stopwatch()..start();
    final done = await loadTogether(
      owned: Future.delayed(const Duration(milliseconds: 40), () => 'owned'),
      staff: Future.delayed(const Duration(milliseconds: 40), () => 'staff'),
      ghosts: Future.delayed(const Duration(milliseconds: 40), () => 'ghosts'),
    );
    clock.stop();
    expect(done.owned, 'owned');
    expect(done.staff, 'staff');
    expect(done.ghosts, 'ghosts');
    expect(clock.elapsedMilliseconds, lessThan(100));
  });
}
