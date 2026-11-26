import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Sports-broadcast wipe: the new page sweeps in behind a slanted edge with
/// brand-coloured speed streaks, while the page underneath slides back.
Widget pushPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;

  final incoming = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final outgoing = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final streak = context.brand.primary;

  return SlideTransition(
    position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.2, 0)).animate(outgoing),
    child: AnimatedBuilder(
      animation: incoming,
      child: child,
      // The widget tree stays the same at every value so the page keeps its state.
      builder: (context, page) => CustomPaint(
        foregroundPainter: _WipeStreakPainter(incoming.value, streak),
        child: ClipPath(
          clipper: _SlantClipper(incoming.value),
          clipBehavior: incoming.value >= 1 ? Clip.none : Clip.antiAlias,
          child: page,
        ),
      ),
    ),
  );
}

/// Booking pass / confirmation: the page rises and settles like a ticket being handed over.
Widget ticketPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;

  final rise = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
  final fade = CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut));

  return FadeTransition(
    opacity: fade,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero).animate(rise),
      child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(rise), child: child),
    ),
  );
}

/// Theme hook so plain `MaterialPageRoute` pushes get the same wipe; dialogs get the ticket rise.
class SportsPageTransitionsBuilder extends PageTransitionsBuilder {
  const SportsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final build = route.fullscreenDialog ? ticketPageTransition : pushPageTransition;
    return build(context, animation, secondaryAnimation, child);
  }
}

/// Leading edge at the top for progress [t]; the bottom sits one slant further right.
double wipeEdgeX(double width, double t) => width - (width * 1.22) * t;

class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper(this.t);
  final double t;

  @override
  Path getClip(Size size) {
    final slant = size.width * 0.22;
    final top = wipeEdgeX(size.width, t);
    return Path()
      ..moveTo(top, 0)
      ..lineTo(size.width + slant, 0)
      ..lineTo(size.width + slant, size.height)
      ..lineTo(top + slant, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_SlantClipper oldClipper) => oldClipper.t != t;
}

class _WipeStreakPainter extends CustomPainter {
  const _WipeStreakPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final slant = size.width * 0.22;
    final top = wipeEdgeX(size.width, t);
    final strength = math.sin(math.pi * t);
    void streak(double gap, double width, double alpha) {
      final x = top - gap;
      canvas.drawPath(
        Path()
          ..moveTo(x - width, 0)
          ..lineTo(x, 0)
          ..lineTo(x + slant, size.height)
          ..lineTo(x - width + slant, size.height)
          ..close(),
        Paint()..color = color.withValues(alpha: alpha * strength),
      );
    }

    streak(0, 8, 1);
    streak(16, 3, 0.55);
  }

  @override
  bool shouldRepaint(_WipeStreakPainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}
