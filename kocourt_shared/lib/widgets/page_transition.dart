import 'package:flutter/material.dart';

/// A pushed page enters from the right. The page underneath shifts left
/// while it is covered, then returns on the way back.
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

  return SlideTransition(
    position: Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).animate(outgoing),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(incoming),
      child: child,
    ),
  );
}
