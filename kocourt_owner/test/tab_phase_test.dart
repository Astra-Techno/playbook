import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/widgets/tab_phase.dart';

void main() {
  test('first load with no rows is a spinner, not an empty list', () {
    expect(
      tabPhase(loading: true, failed: false, hasData: false),
      TabPhase.loading,
    );
  });

  test('a failed request with no rows is an error, not an empty list', () {
    expect(
      tabPhase(loading: false, failed: true, hasData: false),
      TabPhase.failed,
    );
  });

  test('a successful response with no rows is empty', () {
    expect(
      tabPhase(loading: false, failed: false, hasData: false),
      TabPhase.empty,
    );
  });

  test('a failed refresh keeps the ready state when rows are already shown', () {
    expect(
      tabPhase(loading: false, failed: true, hasData: true),
      TabPhase.ready,
    );
  });
}
