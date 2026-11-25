import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Progress ring with 12 stopwatch ticks (Player next game, Owner court tiles).
class StopwatchRingPainter extends CustomPainter {
  const StopwatchRingPainter({required this.progress, required this.color, this.track = const Color(0xFFEEF0F5)});
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.11;
    final radius = size.shortestSide / 2 - stroke / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * (radius - stroke / 2), center + dir * (radius + stroke / 2), tick);
    }
  }

  @override
  bool shouldRepaint(StopwatchRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.track != track;
}
