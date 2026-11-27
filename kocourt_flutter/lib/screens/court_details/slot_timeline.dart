import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

// ── Pure helpers (tested in test/slot_timeline_test.dart) ───────────────────

/// Slot rows come from CourtDetailsScreen._loadSlots: start, end, key, booked, blocked, past.
bool slotFree(Map<String, dynamic> slot) =>
    slot['booked'] != true && slot['blocked'] != true && slot['past'] != true;

int slotHour(Map<String, dynamic> slot) => int.tryParse('${slot['start']}'.split(':').first) ?? 0;

double hourPrice(Map<int, double> prices, int hour, double fallback) => prices[hour] ?? fallback;

/// Consecutive hours that share one price, for the price band above the timeline.
class PriceBand {
  const PriceBand(this.price, this.hours, {required this.peak});
  final double price;
  final int hours;
  final bool peak;
}

List<PriceBand> priceBands(List<Map<String, dynamic>> slots, Map<int, double> prices, double fallback) {
  if (slots.isEmpty) return const [];
  final each = [for (final s in slots) hourPrice(prices, slotHour(s), fallback)];
  final lowest = each.reduce((a, b) => a < b ? a : b);
  final bands = <PriceBand>[];
  var run = 1;
  for (var i = 1; i <= each.length; i++) {
    if (i < each.length && each[i] == each[i - 1]) {
      run++;
      continue;
    }
    bands.add(PriceBand(each[i - 1], run, peak: each[i - 1] > lowest));
    run = 1;
  }
  return bands;
}

/// Free slots from [from] toward [to], stopping at the first slot that is not free.
Set<String> dragRange(List<Map<String, dynamic>> slots, int from, int to) {
  final keys = <String>{};
  final step = to >= from ? 1 : -1;
  for (var i = from; i != to + step; i += step) {
    if (i < 0 || i >= slots.length || !slotFree(slots[i])) break;
    keys.add('${slots[i]['key']}');
  }
  return keys;
}

/// [hours] consecutive free slots starting at [start], or null when one is taken.
Set<String>? extendFrom(List<Map<String, dynamic>> slots, int start, int hours) {
  if (start < 0 || start + hours > slots.length) return null;
  final keys = <String>{};
  for (var i = start; i < start + hours; i++) {
    if (!slotFree(slots[i])) return null;
    keys.add('${slots[i]['key']}');
  }
  return keys;
}

double selectionTotal(List<Map<String, dynamic>> slots, Set<String> selected, Map<int, double> prices, double fallback) {
  var total = 0.0;
  for (final s in slots) {
    if (selected.contains(s['key'])) total += hourPrice(prices, slotHour(s), fallback);
  }
  return total;
}

String _clock(int hour) {
  final h = hour % 24;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12 ${h < 12 ? 'AM' : 'PM'}';
}

/// "6 – 8 PM · 2 hrs" for one run, otherwise "3 hrs".
String selectionLabel(List<Map<String, dynamic>> slots, Set<String> selected) {
  final hours = [for (final s in slots) if (selected.contains(s['key'])) slotHour(s)];
  if (hours.isEmpty) return '';
  final count = '${hours.length} hr${hours.length > 1 ? 's' : ''}';
  final contiguous = hours.last - hours.first + 1 == hours.length;
  if (!contiguous) return count;
  final start = _clock(hours.first);
  final end = _clock(hours.last + 1);
  final sameHalf = start.substring(start.length - 2) == end.substring(end.length - 2);
  return '${sameHalf ? start.substring(0, start.length - 3) : start} – $end · $count';
}

// ── Widget ──────────────────────────────────────────────────────────────────

/// Turf-striped day timeline: tap hours or press-and-drag to pick a run.
/// Price band above shows off-peak and peak prices; taken hours are hatched.
class SlotTimeline extends StatefulWidget {
  const SlotTimeline({
    super.key,
    required this.slots,
    required this.selected,
    required this.prices,
    required this.fallbackRate,
    required this.onChanged,
    required this.onTakenTap,
  });

  final List<Map<String, dynamic>> slots;
  final Set<String> selected;
  final Map<int, double> prices;
  final double fallbackRate;
  final ValueChanged<Set<String>> onChanged;
  final ValueChanged<int> onTakenTap;

  @override
  State<SlotTimeline> createState() => _SlotTimelineState();
}

class _SlotTimelineState extends State<SlotTimeline> {
  static const _cell = 58.0;
  final _scroll = ScrollController();
  int? _dragFrom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstFree());
  }

  @override
  void didUpdateWidget(SlotTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.slots, widget.slots)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstFree());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToFirstFree() {
    if (!_scroll.hasClients) return;
    final i = widget.slots.indexWhere(slotFree);
    if (i <= 0) return;
    _scroll.animateTo(
      (i * _cell - 24).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  int _indexAt(double dx) => (dx / _cell).floor().clamp(0, widget.slots.length - 1);

  void _tap(int i) {
    final slot = widget.slots[i];
    if (!slotFree(slot)) {
      if (slot['booked'] == true) widget.onTakenTap(i);
      return;
    }
    HapticFeedback.selectionClick();
    final next = {...widget.selected};
    final key = '${slot['key']}';
    next.contains(key) ? next.remove(key) : next.add(key);
    widget.onChanged(next);
  }

  void _drag(int to) {
    final from = _dragFrom;
    if (from == null) return;
    final range = dragRange(widget.slots, from, to);
    if (range.isEmpty || setEquals(range, widget.selected)) return;
    HapticFeedback.selectionClick();
    widget.onChanged(range);
  }

  int? get _firstSelectedIndex {
    final i = widget.slots.indexWhere((s) => widget.selected.contains(s['key']));
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    final slots = widget.slots;
    final bands = priceBands(slots, widget.prices, widget.fallbackRate);
    final first = _firstSelectedIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'PICK YOUR TIME',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5),
              ),
            ),
            if (widget.selected.isNotEmpty)
              Text(
                selectionLabel(slots, widget.selected),
                style: AppFonts.score(fontSize: 14, fontWeight: FontWeight.w900, color: brand),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap hours, or press and drag across the pitch to pick a run.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price band
                Row(
                  children: [
                    for (final band in bands)
                      Container(
                        width: band.hours * _cell - 2,
                        height: 22,
                        margin: const EdgeInsets.only(right: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: band.peak ? AppColors.warningLight : AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (band.peak) const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFB45309)),
                            Text(
                              band.hours > 1
                                  ? '${band.peak ? 'Peak · ' : ''}${rupees(band.price)}/hr'
                                  : rupees(band.price),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: band.peak ? const Color(0xFFB45309) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Pitch cells
                GestureDetector(
                  onTapUp: (d) => _tap(_indexAt(d.localPosition.dx)),
                  onLongPressStart: (d) {
                    final i = _indexAt(d.localPosition.dx);
                    if (!slotFree(slots[i])) return;
                    _dragFrom = i;
                    _drag(i);
                  },
                  onLongPressMoveUpdate: (d) => _drag(_indexAt(d.localPosition.dx)),
                  onLongPressEnd: (_) => _dragFrom = null,
                  child: Row(
                    children: [
                      for (var i = 0; i < slots.length; i++) _cellFor(i, brand),
                    ],
                  ),
                ),
                // Stopwatch ticks every 15 minutes
                SizedBox(
                  width: slots.length * _cell,
                  height: 8,
                  child: const CustomPaint(painter: _TickPainter(_cell)),
                ),
                Row(
                  children: [
                    for (final s in slots)
                      SizedBox(
                        width: _cell,
                        child: Text(
                          _clock(slotHour(s)),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Quick lengths from the first picked hour
        Row(
          children: [
            for (final hours in const [1, 2, 3])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$hours hr${hours > 1 ? 's' : ''}'),
                  selected: widget.selected.length == hours && first != null && extendFrom(slots, first, hours) != null,
                  onSelected: first == null || extendFrom(slots, first, hours) == null
                      ? null
                      : (_) {
                          HapticFeedback.selectionClick();
                          widget.onChanged(extendFrom(slots, first, hours)!);
                        },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _cellFor(int i, Color brand) {
    final slot = widget.slots[i];
    final key = '${slot['key']}';
    final free = slotFree(slot);
    final picked = widget.selected.contains(key);
    final prevPicked = i > 0 && widget.selected.contains(widget.slots[i - 1]['key']);
    final nextPicked = i < widget.slots.length - 1 && widget.selected.contains(widget.slots[i + 1]['key']);
    final turf = slotHour(slot).isEven ? const Color(0xFFE7F8F0) : const Color(0xFFD6F2E4);
    final label = slot['past'] == true ? 'Past' : slot['booked'] == true ? 'Booked' : 'Closed';

    return Semantics(
      button: free,
      selected: picked,
      label: '${_clock(slotHour(slot))}, ${free ? (picked ? 'selected' : 'free') : label}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _cell,
        height: 76,
        margin: EdgeInsets.symmetric(vertical: picked ? 0 : 4),
        decoration: BoxDecoration(
          color: picked ? brand : (free ? turf : null),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(picked && !prevPicked ? 12 : (picked ? 0 : 4)),
            right: Radius.circular(picked && !nextPicked ? 12 : (picked ? 0 : 4)),
          ),
        ),
        foregroundDecoration: free ? null : const _HatchDecoration(),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (picked && !prevPicked) const Positioned(left: 4, child: _Handle()),
            if (picked && !nextPicked) const Positioned(right: 4, child: _Handle()),
            if (!free)
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary))
            else if (picked)
              const Icon(Icons.sports_score_rounded, size: 18, color: Colors.white)
            else
              Text(
                rupees(hourPrice(widget.prices, slotHour(slot), widget.fallbackRate)),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 26,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
    );
  }
}

/// Grey diagonal hatching over taken or closed hours.
class _HatchDecoration extends Decoration {
  const _HatchDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HatchPainter();
}

class _HatchPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final rect = offset & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF1F2F6));
    final line = Paint()
      ..color = const Color(0xFFE0E3EA)
      ..strokeWidth = 4;
    for (double x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(rect.topLeft + Offset(x, size.height), rect.topLeft + Offset(x + size.height, 0), line);
    }
    canvas.restore();
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.cell);
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFAEB4C2)
      ..strokeWidth = 1;
    for (double x = 0, i = 0; x <= size.width; x += cell / 4, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, i % 4 == 0 ? size.height : size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => oldDelegate.cell != cell;
}

/// Booking touch: what each player's share would be. The booker still pays the full amount.
class SquadSplit extends StatelessWidget {
  const SquadSplit({super.key, required this.total, required this.players, required this.onPlayers});

  final double total;
  final int players;
  final ValueChanged<int> onPlayers;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    final share = total / players;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, color: brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Split with $players players', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Text('You pay the full amount; this is each share.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fewer players',
            onPressed: players > 2 ? () => onPlayers(players - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text(
            '${rupees(share.ceilToDouble())} each',
            style: AppFonts.score(fontSize: 15, fontWeight: FontWeight.w900, color: brand),
          ),
          IconButton(
            tooltip: 'More players',
            onPressed: players < 22 ? () => onPlayers(players + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
