import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Turf banner with football pitch markings: how many listed venues are open now.
class LiveBanner extends StatelessWidget {
  const LiveBanner({super.key, required this.venueCount, required this.openNow, required this.onTap});

  final int venueCount;
  final int openNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Semantics(
        button: true,
        label: '$openNow venues open now. Book now.',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 156,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F5132), Color(0xFF1F7A4D), Color(0xFF2E9960)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: CustomPaint(
              painter: const _PitchPainter(),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF6EE7A8)),
                          SizedBox(width: 6),
                          Text('Live near you', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$openNow open now',
                                style: GoogleFonts.archivo(color: Colors.white, fontSize: 34, height: 1, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$venueCount venues on KoCourt near you',
                                style: const TextStyle(color: Color(0xFFDCF5E8), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Book now', style: TextStyle(color: Color(0xFF0F5132), fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Mowing stripes.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 30, size.height), stripe);
    }
    // Right half of a football pitch.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.26);
    final w = size.width;
    final h = size.height;
    final half = w * 0.65;
    canvas.drawRRect(RRect.fromLTRBR(10, 10, w - 10, h - 10, const Radius.circular(4)), line);
    canvas.drawLine(Offset(half, 10), Offset(half, h - 10), line);
    canvas.drawCircle(Offset(half, h / 2), h * 0.2, line);
    canvas.drawRect(Rect.fromLTRB(w - 62, h * 0.25, w - 10, h * 0.75), line);
    canvas.drawRect(Rect.fromLTRB(w - 32, h * 0.37, w - 10, h * 0.63), line);
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}
