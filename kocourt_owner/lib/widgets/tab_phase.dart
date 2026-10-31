/// Which full-page state a tab should show.
///
/// A failed refresh that still has previous rows stays [TabPhase.ready] so the
/// screen can keep those rows and show a retry banner above them.
enum TabPhase { loading, failed, empty, ready }

TabPhase tabPhase({
  required bool loading,
  required bool failed,
  required bool hasData,
}) {
  if (loading && !hasData && !failed) return TabPhase.loading;
  if (failed && !hasData) return TabPhase.failed;
  if (!hasData) return TabPhase.empty;
  return TabPhase.ready;
}
