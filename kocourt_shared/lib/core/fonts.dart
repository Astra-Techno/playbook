import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Matchday type system. Every screen picks one of three roles, so a later
/// font change happens here only.
///  - display: Bricolage Grotesque, for names and headings
///  - body: Figtree, for reading and controls
///  - score: Barlow Condensed, for times, prices, counters and stats
class AppFonts {
  AppFonts._();

  /// Barlow Condensed is narrow; this keeps its numbers as large as the text around them.
  static const double scoreScale = 1.1;

  static TextStyle display({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? height, double? letterSpacing, FontStyle? fontStyle}) =>
      GoogleFonts.bricolageGrotesque(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        // The family stops at ExtraBold.
        fontWeight: _cap(fontWeight ?? FontWeight.w800, FontWeight.w800),
        height: height,
        letterSpacing: letterSpacing ?? -0.2,
        fontStyle: fontStyle,
      );

  static TextStyle body({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? height, double? letterSpacing, FontStyle? fontStyle}) =>
      GoogleFonts.figtree(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  static TextStyle score({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? height, double? letterSpacing, FontStyle? fontStyle}) =>
      GoogleFonts.barlowCondensed(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize == null ? null : fontSize * scoreScale,
        fontWeight: _cap(fontWeight ?? FontWeight.w700, FontWeight.w700),
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextTheme bodyTheme([TextTheme? base]) => GoogleFonts.figtreeTextTheme(base);

  static FontWeight _cap(FontWeight w, FontWeight max) => w.index > max.index ? max : w;
}
