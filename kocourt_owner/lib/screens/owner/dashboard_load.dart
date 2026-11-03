/// Three venue-home reads that do not depend on each other.
Future<({A owned, B staff, C ghosts})> loadTogether<A, B, C>({
  required Future<A> owned,
  required Future<B> staff,
  required Future<C> ghosts,
}) async {
  final rows = await Future.wait([owned, staff, ghosts]);
  return (owned: rows[0] as A, staff: rows[1] as B, ghosts: rows[2] as C);
}
