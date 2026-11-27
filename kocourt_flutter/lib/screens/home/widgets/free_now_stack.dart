import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

import '../home_logic.dart';
import 'day_strip.dart';

/// v5 "Open now" card stack: swipe through venues open right now. The photo
/// fades into white, two tilted cards behind hint there is more to swipe, and
/// the incoming card rises with a slight tilt.
class FreeNowStack extends StatefulWidget {
  const FreeNowStack({super.key, required this.venues, required this.onOpen, this.date});

  final List<Map<String, dynamic>> venues;
  final ValueChanged<Map<String, dynamic>> onOpen;

  /// Day the strips describe ("YYYY-MM-DD").
  final String? date;

  @override
  State<FreeNowStack> createState() => _FreeNowStackState();
}

class _FreeNowStackState extends State<FreeNowStack> {
  final _pages = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venues = widget.venues;
    if (venues.isEmpty) return const SizedBox.shrink();
    final current = _page.round().clamp(0, venues.length - 1);
    final behind1 = sportTint(venues[(current + 1) % venues.length]['type']);
    final behind2 = sportTint(venues[(current + 2) % venues.length]['type']);
    final still = MediaQuery.disableAnimationsOf(context);
    // Cards grow to fit the day strip once strips have loaded.
    final extra = venues.any((v) => v['strip'] is String) ? 44.0 : 0.0;

    return Column(
      children: [
        SizedBox(
          height: 262 + extra,
          child: Stack(
            children: [
              if (venues.length > 2)
                Positioned(
                  left: 28,
                  right: 28,
                  top: 0,
                  height: 236 + extra,
                  child: Transform.rotate(angle: -0.05, child: _BackCard(color: behind2.bg)),
                ),
              if (venues.length > 1)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 6,
                  height: 238 + extra,
                  child: Transform.rotate(angle: 0.045, child: _BackCard(color: behind1.bg)),
                ),
              Positioned.fill(
                top: 12,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: venues.length,
                  itemBuilder: (_, i) {
                    final delta = (_page - i).clamp(-1.0, 1.0);
                    final card = _VenueCard(
                      venue: venues[i],
                      position: '${i + 1} of ${venues.length}',
                      onOpen: () => widget.onOpen(venues[i]),
                      date: widget.date,
                    );
                    if (still) return card;
                    // The card leaving tilts away and shrinks a little.
                    return Transform.rotate(
                      angle: delta * 0.06,
                      child: Transform.scale(scale: 1 - delta.abs() * 0.06, child: card),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (venues.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < venues.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == current ? 18 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == current ? context.brand.primary : const Color(0xFFC9CDD8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(26)));
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.position, required this.onOpen, this.date});
  final Map<String, dynamic> venue;
  final String? date;
  final String position;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rate = venue['hourly_rate'];
    final km = venue['distance_km'];
    final strip = venue['strip'] is String ? venue['strip'] as String : null;
    final hour = freeHour(venue);
    final meta = [
      'Open till ${clockLabel(venue['close_time'] ?? '22:00:00')}',
      if (rate != null) '${rupees(rate)}/hr',
      if (km != null) '$km km',
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${venue['name'] ?? 'Venue'}, $meta',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: getVenueImage(venue),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(color: sportTint(venue['type']).bg),
                      ),
                      // v5: photos fade into the white card instead of darkening.
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: 70,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00FFFFFF), Colors.white],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(13)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text('${freeLabel(venue)} · $position',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                            ],
                          ),
                        ),
                      ),
                      Positioned(right: 12, top: 12, child: StatusTag.sport(venue['type'])),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${venue['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.display(fontSize: 23, fontWeight: FontWeight.w900, height: 1)),
                            const SizedBox(height: 4),
                            Text(meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(hour == null ? 'Book' : 'Book ${hourLabel(hour)}'),
                      ),
                    ],
                  ),
                ),
                if (strip != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: DayStrip(strip: strip, tone: sportTint(venue['type']).fg, highlightHour: hour, date: date),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
