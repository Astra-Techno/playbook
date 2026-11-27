import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sport_icon_svgs.g.dart';
import 'sport_tags.dart';

/// Icon file for a venue or match type ("turf" → football); null when unknown.
String? sportIconKey(Object? type) => switch ('${type ?? ''}'.trim().toLowerCase()) {
      'turf' || 'football' => 'football',
      'shuttle' || 'badminton' => 'badminton',
      'basket' || 'basketball' => 'basketball',
      'table_tennis' || 'table tennis' || 'tt' => 'table_tennis',
      final id when sportIconSvgs.containsKey(id) => id,
      _ => null,
    };

/// The sport's SVG with its colours filled in, ready for flutter_svg.
String? sportIconSvg(Object? type, {Color? tone, Color? tint, Color surface = Colors.white}) {
  final key = sportIconKey(type);
  if (key == null) return null;
  final colours = sportTint(type);
  String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return sportIconSvgs[key]!
      .replaceAll('var(--tone)', hex(tone ?? colours.fg))
      .replaceAll('var(--tint)', hex(tint ?? colours.bg))
      .replaceAll('var(--surface)', hex(surface));
}

/// Matchday sport icon: rounded line in the sport colour, one shape in its tint.
/// Falls back to [fallback] (or nothing) for a type without an icon.
class SportIcon extends StatelessWidget {
  const SportIcon(this.type, {super.key, this.size = 24, this.tone, this.tint, this.fallback, this.semanticLabel});

  final Object? type;
  final double size;

  /// Overrides the sport colours, e.g. white on a filled chip.
  final Color? tone;
  final Color? tint;
  final IconData? fallback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final svg = sportIconSvg(type, tone: tone, tint: tint);
    if (svg == null) {
      return fallback == null ? SizedBox.square(dimension: size) : Icon(fallback, size: size, color: tone ?? sportTint(type).fg);
    }
    return SvgPicture.string(svg, width: size, height: size, semanticsLabel: semanticLabel ?? sportLabel(type));
  }
}
