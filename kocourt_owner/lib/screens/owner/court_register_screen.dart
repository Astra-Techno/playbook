import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

import '../../widgets/sheets/walkin_sheet.dart';
import 'booking_detail_screen.dart';
import 'register_logic.dart';
import 'walk_in_fields.dart';

/// Front-desk register for one venue: today's till, a live tile per court,
/// and who is arriving next. Tiles tick every 30 s; data reloads every minute.
class CourtRegisterScreen extends StatefulWidget {
  const CourtRegisterScreen({super.key, required this.courtId});
  final int courtId;

  @override
  State<CourtRegisterScreen> createState() => _CourtRegisterScreenState();
}

class _CourtRegisterScreenState extends State<CourtRegisterScreen> {
  String _venue = 'Court register';
  List<Map<String, dynamic>> _spaces = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;
  String? _error;
  final Set<int> _checkingIn = {};
  Timer? _tick;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (++_ticks % 2 == 0) _load(quiet: true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(Object? raw) => raw is List
      ? [for (final r in raw) if (r is Map) Map<String, dynamic>.from(r)]
      : <Map<String, dynamic>>[];

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final res = await Api().get('/courts/${widget.courtId}/calendar', params: {'date': bookingDay(DateTime.now())});
      final data = res.data is Map ? res.data as Map : const {};
      if (!mounted) return;
      setState(() {
        _venue = '${(data['court'] is Map ? data['court']['name'] : null) ?? 'Court register'}';
        _spaces = _rows(data['sub_courts']);
        _bookings = _rows(data['bookings']);
        _blocks = _rows(data['blocked_slots']);
        _error = null;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!quiet) _error = Api.failureMessage(caught, fallback: 'Could not load today\'s courts.');
      });
    }
  }

  Future<void> _walkIn({int? spaceId}) async {
    final saved = await WalkInSheet.show(
      context,
      courtId: widget.courtId,
      date: bookingDay(DateTime.now()),
      startTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:00',
      spaceId: spaceId,
      spaces: _spaces,
    );
    if (saved == true) _load(quiet: true);
  }

  Future<void> _openBooking(Map<String, dynamic> booking) async {
    final id = int.tryParse('${booking['id']}') ?? 0;
    if (id <= 0) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: id)));
    _load(quiet: true);
  }

  Future<void> _checkIn(Map<String, dynamic> booking) async {
    final id = int.tryParse('${booking['id']}') ?? 0;
    if (id <= 0 || _checkingIn.contains(id)) return;
    setState(() => _checkingIn.add(id));
    try {
      await Api().post('/bookings/$id/attendance', data: {'action': 'check_in'});
      HapticFeedback.mediumImpact();
      if (mounted) context.toastSuccess('${playerName(booking)} checked in');
      await _load(quiet: true);
    } catch (caught) {
      if (mounted) context.toastError(Api.failureMessage(caught, fallback: 'Could not check in.'));
    } finally {
      if (mounted) setState(() => _checkingIn.remove(id));
    }
  }

  String _money(double v) => '₹${v.round()}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_venue, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Register · ${TimeOfDay.fromDateTime(now).format(context)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan a booking pass',
            onPressed: () => context.push('/scan').then((_) => _load(quiet: true)),
            icon: Icon(Icons.qr_code_scanner_rounded, color: context.brand.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _walkIn(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Walk-in'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(quiet: true),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 840;
                      final courts = _courtGrid(now, columns: wide ? 3 : 2);
                      final arrivals = _arrivals(now);
                      if (!wide) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          children: [_till(), const SizedBox(height: 16), _heading('Courts'), courts, const SizedBox(height: 16), arrivals],
                        );
                      }
                      // Tablet at the desk: courts on the left, arrivals beside them.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 4, 12, 96),
                              children: [_till(), const SizedBox(height: 16), _heading('Courts'), courts],
                            ),
                          ),
                          SizedBox(
                            width: 360,
                            child: ListView(padding: const EdgeInsets.fromLTRB(8, 4, 20, 96), children: [arrivals]),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppFonts.display(fontSize: 20, fontWeight: FontWeight.w900)),
      );

  Widget _till() {
    final till = tillTotals(_bookings);
    final cells = [
      ('Cash', till.cash, AppColors.textPrimary),
      ('UPI', till.upi, AppColors.textPrimary),
      ('Online', till.online, AppColors.textPrimary),
      ('To collect', till.toCollect, AppColors.error),
    ];
    return Row(
      children: [
        for (final (label, value, colour) in cells)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_money(value), style: AppFonts.score(fontSize: 18, fontWeight: FontWeight.w900, color: colour)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _courtGrid(DateTime now, {required int columns}) {
    // A venue without spaces is one court.
    final spaces = _spaces.isEmpty ? [<String, dynamic>{'id': null, 'name': 'Court'}] : _spaces;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: spaces.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 156,
      ),
      itemBuilder: (_, i) {
        final space = spaces[i];
        final spaceId = int.tryParse('${space['id']}');
        final tile = courtTile(bookings: _bookings, blocks: _blocks, spaceId: spaceId, now: now);
        return _CourtTileCard(
          name: '${space['name'] ?? 'Court'}',
          tile: tile,
          onTap: () => tile.booking != null
              ? _openBooking(tile.booking!)
              : tile.kind == TileKind.free
                  ? _walkIn(spaceId: spaceId)
                  : null,
        );
      },
    );
  }

  Widget _arrivals(DateTime now) {
    final rows = arrivingNext(_bookings, now);
    final brand = context.brand.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arriving next', style: AppFonts.display(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No one else is due today.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final b in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Transform(
                    transform: Matrix4.skewX(-0.14),
                    alignment: Alignment.center,
                    child: Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(startClock(b), style: AppFonts.score(fontSize: 12, fontWeight: FontWeight.w900, color: brand)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playerName(b), style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [_spaceName(b), paymentDue(b) ? 'Pay at venue' : 'Paid'].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  checkInOpen(b, now)
                      ? FilledButton(
                          onPressed: _checkingIn.contains(int.tryParse('${b['id']}')) ? null : () => _checkIn(b),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: const Text('Check in'),
                        )
                      : const Text('Opens 30 min before', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _spaceName(Map<String, dynamic> b) {
    for (final s in _spaces) {
      if ('${s['id']}' == '${b['sub_court_id']}') return '${s['name'] ?? ''}';
    }
    return '';
  }
}

class _CourtTileCard extends StatelessWidget {
  const _CourtTileCard({required this.name, required this.tile, required this.onTap});
  final String name;
  final CourtTile tile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    final (tag, tagBg, tagFg, ring, border, dashed) = switch (tile.kind) {
      TileKind.inPlay => ('In play', brand.withValues(alpha: 0.1), brand, brand, AppColors.border, false),
      TileKind.ending => ('Ending', const Color(0xFFFFF4E5), const Color(0xFFB45309), const Color(0xFFF59E0B), const Color(0xFFF5C77E), false),
      TileKind.collect => ('Collect', const Color(0xFFFEECEC), const Color(0xFFB91C1C), AppColors.error, const Color(0xFFF4B4B4), false),
      TileKind.free => ('Free', const Color(0xFFE7F8F0), const Color(0xFF047857), const Color(0xFF10B981), const Color(0xFF9AD9BC), true),
      TileKind.closed => ('Closed', AppColors.surfaceDim, AppColors.textSecondary, AppColors.textMuted, AppColors.border, false),
    };
    return Semantics(
      button: onTap != null,
      label: '$name, $tag, ${tile.title}, ${tile.subtitle}',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: dashed ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: AppFonts.display(fontSize: 16, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Transform(
                      transform: Matrix4.skewX(-0.17),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(5)),
                        child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tagFg)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: tile.kind == TileKind.free ? 1 : tile.progress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, child) => CustomPaint(
                          painter: StopwatchRingPainter(progress: value, color: ring, track: const Color(0xFFEEF0F5)),
                          child: child,
                        ),
                        child: Center(
                          child: tile.kind == TileKind.free
                              ? Icon(Icons.add_rounded, color: ring)
                              : Text(tile.clock, style: AppFonts.score(fontSize: 14, fontWeight: FontWeight.w900, color: tagFg)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tile.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(tile.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
