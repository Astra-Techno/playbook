import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/page_transition.dart';

/// Per-app brand. Both apps share the logo violet (design v4 "Pro Light").
class BrandTokens extends ThemeExtension<BrandTokens> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color onPrimary;
  final Color surface;
  final Color ink;
  final LinearGradient gradient;

  const BrandTokens({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.onPrimary,
    required this.surface,
    required this.ink,
    required this.gradient,
  });

  static const player = BrandTokens(
    primary: Color(0xFF6D28D9),
    primaryDark: Color(0xFF5521B5),
    primaryLight: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7FB),
    ink: Color(0xFF111827),
    gradient: LinearGradient(
      colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const owner = BrandTokens(
    primary: Color(0xFF6D28D9),
    primaryDark: Color(0xFF5521B5),
    primaryLight: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7FB),
    ink: Color(0xFF111827),
    gradient: LinearGradient(
      colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  BrandTokens copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? onPrimary,
    Color? surface,
    Color? ink,
    LinearGradient? gradient,
  }) {
    return BrandTokens(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      onPrimary: onPrimary ?? this.onPrimary,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      gradient: gradient ?? this.gradient,
    );
  }

  @override
  BrandTokens lerp(ThemeExtension<BrandTokens>? other, double t) {
    if (other is! BrandTokens) return this;
    return BrandTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      gradient: LinearGradient(
        colors: [
          Color.lerp(gradient.colors.first, other.gradient.colors.first, t)!,
          Color.lerp(gradient.colors.last, other.gradient.colors.last, t)!,
        ],
        begin: gradient.begin,
        end: gradient.end,
      ),
    );
  }
}

extension BrandContext on BuildContext {
  BrandTokens get brand => Theme.of(this).extension<BrandTokens>() ?? BrandTokens.player;
  Color get brandPrimary => Theme.of(this).colorScheme.primary;
}

class AppColors {
  // Default / player brand constants (legacy call sites without context)
  static const primary = Color(0xFF6D28D9);
  static const primaryDark = Color(0xFF5521B5);
  static const primaryLight = Color(0xFF8B5CF6);
  static const onPrimary = Color(0xFFFFFFFF);

  // Owner brand constants (for owner-only hardcodes when context is awkward)
  static const ownerPrimary = Color(0xFF6D28D9);
  static const ownerPrimaryDark = Color(0xFF5521B5);
  static const ownerPrimaryLight = Color(0xFF8B5CF6);
  static const ownerSurface = Color(0xFFF6F7FB);
  static const ownerInk = Color(0xFF111827);

  // Secondary - forest green for success/confirmed states
  static const secondary = Color(0xFF047857);
  static const secondaryLight = Color(0xFF10B981);
  static const onSecondary = Color(0xFFFFFFFF);

  // Accent - gold for ratings/premium
  static const accent = Color(0xFFFFB800);
  static const accentDark = Color(0xFFE5A600);

  // Neutrals
  static const surface = Color(0xFFF6F7FB);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const surfaceDim = Color(0xFFF0F1F3);
  static const surfaceMuted = Color(0xFFE8EAED);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF5B6475);
  static const textMuted = Color(0xFF9CA3AF);
  static const textDisabled = Color(0xFFD1D5DB);

  // Borders
  static const border = Color(0xFFE6E8F0);
  static const borderLight = Color(0xFFF3F4F6);

  // States
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);

  // Soft toast wells
  static const successLight = Color(0xFFDCFCE7);

  // Shadows
  static const shadowLight = Color(0x0A000000);
  static const shadowMedium = Color(0x14000000);
  static const shadowHeavy = Color(0x1F000000);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ownerGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF2D2D30)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0x00000000), Color(0xB3000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const elevated = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const bottomBar = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 24,
      offset: Offset(0, -8),
    ),
  ];

  static List<BoxShadow> primaryGlow(double opacity, [Color? color]) => [
    BoxShadow(
      color: (color ?? AppColors.primary).withValues(alpha: opacity),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppRadius {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const full = 100.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

class AppTheme {
  /// Legacy alias → player theme.
  static ThemeData get theme => player;

  static ThemeData get player => _build(BrandTokens.player);

  static ThemeData get owner => _build(BrandTokens.owner);

  static ThemeData _build(BrandTokens brand) {
    // Inter for reading, Archivo for sporty headings and big numbers.
    final body = GoogleFonts.interTextTheme();
    TextStyle head(TextStyle? s) => GoogleFonts.archivo(textStyle: s, fontWeight: FontWeight.w800);
    final textTheme = body.copyWith(
      displayLarge: head(body.displayLarge),
      displayMedium: head(body.displayMedium),
      displaySmall: head(body.displaySmall),
      headlineLarge: head(body.headlineLarge),
      headlineMedium: head(body.headlineMedium),
      headlineSmall: head(body.headlineSmall),
      titleLarge: head(body.titleLarge),
    );
    final radius = BorderRadius.circular(AppRadius.md);

    OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: brand.surface,
      extensions: [brand],
      // iOS keeps the native page so swipe-back still works.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SportsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: brand.ink,
      ),
      colorScheme: ColorScheme.light(
        primary: brand.primary,
        onPrimary: brand.onPrimary,
        primaryContainer: brand.primaryLight,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: brand.surface,
        onSurface: brand.ink,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: brand.ink),
        titleTextStyle: GoogleFonts.archivo(
          color: brand.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        // v4: the active tab sits on a soft brand pill.
        indicatorColor: brand.primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: brand.primary,
              letterSpacing: 0.5,
            );
          }
          return GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: brand.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: brand.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: brand.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.primary,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.ink,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(brand.primary, width: 2),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, width: 2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: brand.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textDisabled,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.inter(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: GoogleFonts.archivo(
          color: brand.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brand.ink,
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brand.primary,
        disabledColor: AppColors.surfaceDim,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: brand.ink),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand.primary,
        foregroundColor: brand.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        extendedTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: brand.ink,
        titleTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: brand.ink),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand.primary),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
