import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A lightweight, accessible alternative to decorative 3D assets.
///
/// The surface uses a directional highlight and two soft shadows to establish
/// hierarchy, and compresses slightly on touch. It is intentionally built from
/// Flutter primitives so lists remain smooth on entry-level Android devices.
class TactileSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color color;
  final Color? accentColor;

  const TactileSurface({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.radius = AppRadius.lg,
    this.color = AppColors.surfaceWhite,
    this.accentColor,
  });

  @override
  State<TactileSurface> createState() => _TactileSurfaceState();
}

class _TactileSurfaceState extends State<TactileSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.onTap != null;
    final radius = BorderRadius.circular(widget.radius);
    final accent = widget.accentColor;

    return Semantics(
      button: canTap,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
        onTapUp: canTap ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.982 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: widget.margin,
            padding: widget.padding,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.72), widget.color),
                  widget.color,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
              ),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 7,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                widget.child,
                if (accent != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 3, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
