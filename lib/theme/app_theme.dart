import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA DESIGN SYSTEM — Compact Institutional Research
// ═══════════════════════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  // ─── Colors ───────────────────────────────────────────────────────────────
  static const Color primary =
      Color(0xFF003366); // Goldman Sachs Institutional Blue
  static const Color accent = Color(0xFFBD9354); // Soft Gold/Champagne
  static const Color gold = Color(0xFFC5A059);

  static const Color bgPrimary =
      Color(0xFF0B0E14); // Midnight Navy (Deep & Premium)
  static const Color bgSecondary = Color(0xFF151B23); // Dark Surface
  static const Color bgTertiary = Color(0xFF21262D);
  static const Color bgElevated = Color(0xFF30363D);

  static const Color borderDark = Color(0xFF30363D);
  static const Color borderLight = Color(0xFFE1E4E8);

  // ─── Extended Surface Colors ──────────────────────────────────────────
  static const Color surfaceUltraDark = Color(0xFF05070A);
  static const Color surfaceDeep = Color(0xFF0D1117);
  static const Color surfaceMid = Color(0xFF161B22);
  static const Color dividerSubtle = Color(0xFF1B1F23);

  static const Color textPrimary = Color(0xFFF0F3F6);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textTertiary = Color(0xFF6E7681);

  static const Color positive = Color(0xFF238636); // Institutional Green
  static const Color negative = Color(0xFFDA3633); // Institutional Red
  static const Color warning = Color(0xFFD29922);

  static const Color textDisabled = Color(0xFF484F58);
  static const Color textMuted = textSecondary;
  static const Color lightText = Color(0xFFF9FAFB);
  static const Color lightTextSecond = Color(0xFF94A3B8);
  static const Color lightTextPrimary = Color(0xFFF9FAFB);
  static const Color lightTextSecondary = Color(0xFF94A3B8);
  static const Color lightTextMuted = Color(0xFF64748B);

  static const Color background = bgPrimary;
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceLight = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSub = Color(0xFFCBD5E1);

  static const Color amber = Color(0xFFFFB300);
  static const Color emerald = Color(0xFF00E676);
  static const Color goldDim = Color(0x33FFD54F);

  // ─── Academy Tokens (Institutional Learning UX) ────────────────────────
  static const Color academyHeroSurfaceDark = Color(0xFF0D1520);
  static const Color academyTitleLight = Color(0xFF0F172A);
  static const Color academyTrackTechnical = Color(0xFF2196F3);
  static const Color academyTrackTechnicalSoft = Color(0xFF42A5F5);
  static const Color academyTrackFundamental = Color(0xFFFFD54F);
  static const Color academyTrackPattern = Color(0xFFAB47BC);
  static const Color academyTrackIndicators = Color(0xFFEF5350);
  static const Color academyTrackVolume = Color(0xFF26A69A);
  static const Color academyTrackCyan = Color(0xFF00E5FF);
  static const Color academyTrackPink = Color(0xFFE91E63);
  static const Color academyTrackWarm = Color(0xFFFFCC80);
  static const Color academyPanelSurface = Color(0xFF090A0C);
  static const Color surfaceNearBlack = Color(0xFF0A0A0A);
  static const Color surfaceCharcoal = Color(0xFF080808);
  static const Color textPrimaryLightStrong = Color(0xFF1A1A1A);

  // ─── Education Chart Tokens ─────────────────────────────────────────────
  static const Color eduBull = Color(0xFF00E676);
  static const Color eduBear = Color(0xFFFF5252);
  static const Color eduBg = Color(0xFF0D1117);
  static const Color eduGrid = Color(0x14FFFFFF);
  static const Color eduAxis = Color(0x80FFFFFF);
  static const Color eduIndigo = Color(0xFF6366F1);
  static const Color eduGold = Color(0xFFFFD54F);
  static const Color eduBlue = Color(0xFF42A5F5);
  static const Color eduSlate = Color(0xFF90A4AE);
  static const Color eduSignal = Color(0xFFFF7043);
  static const Color eduPurple = Color(0xFFAB47BC);
  static const Color eduTeal = Color(0xFF26A69A);
  static const Color eduCassure = academyTrackTechnical;

  // ─── Extended Semantic Colors ───────────────────────────────────────────
  static const Color positiveStrong = Color(0xFF10B981);
  static const Color positiveSoft = Color(0xFF34D399);
  static const Color negativeStrong = Color(0xFFEF4444);
  static const Color negativeSoft = Color(0xFFF87171);
  static const Color warningStrong = Color(0xFFFBBF24);
  static const Color successStrong = Color(0xFF00C853);
  static const Color bearishDeep = Color(0xFFB71C1C);
  static const Color infoStrong = Color(0xFF3B82F6);

  // ─── Neutral Alias Tokens (Hardcode Removal) ───────────────────────────
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
  static const Color white60 = Colors.white60;
  static const Color white54 = Colors.white54;
  static const Color white38 = Colors.white38;
  static const Color white24 = Colors.white24;
  static const Color white12 = Colors.white12;
  static const Color white10 = Colors.white10;
  static const Color black = Colors.black;
  static const Color black87 = Colors.black87;
  static const Color black54 = Colors.black54;
  static const Color black45 = Colors.black45;
  static const Color black38 = Colors.black38;
  static const Color black26 = Colors.black26;
  static const Color transparent = Colors.transparent;
  static const Color white30 = Colors.white30;

  // ─── Accent Alias Tokens ───────────────────────────────────────────────
  static const Color amberAccent = Colors.amber;
  static const Color blueAccent = Colors.blueAccent;
  static const Color yellowAccent = Colors.yellowAccent;
  static const Color purpleAccent = Colors.purpleAccent;
  static const Color redAccent = Colors.redAccent;
  static const Color greenAccent = Colors.greenAccent;
  static const Color lightGreenAccent = Colors.lightGreenAccent;
  static const Color cyan = Colors.cyan;
  static const Color tealAccent = Colors.tealAccent;
  static const Color orangeAccent = Colors.orangeAccent;
  static const Color orange = Colors.orange;
  static const Color green = Colors.green;
  static const Color teal = Colors.teal;
  static const Color blue = Colors.blue;
  static const Color indigo = Colors.indigo;
  static const Color pinkAccent = Colors.pinkAccent;
  static const Color black12 = Colors.black12;
  static const Color lightGreen = Colors.lightGreen;
  static const Color red = Colors.red;

  // ─── Residual Legacy Hex Tokens ────────────────────────────────────────
  static const Color slate950 = Color(0xFF0F172A);
  static const Color slate900Strong = Color(0xFF1E293B);
  static const Color slate700Strong = Color(0xFF334155);
  static const Color blue800Strong = Color(0xFF1E3A8A);
  static const Color blue700Strong = Color(0xFF1D4ED8);
  static const Color nearBlack0C = Color(0xFF0C0C0C);
  static const Color cyanStrong = Color(0xFF06B6D4);
  static const Color indigoStrong = Color(0xFF6366F1);
  static const Color goldBright = Color(0xFFFFD700);
  static const Color panelDark = Color(0xFF21262D);

  // ─── Layout Constants ─────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double radiusSm = 4.0; // Sharper corners for GS look
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusFull = 99.0;

  static const double screenPadding = 16.0;
  static const double sectionGap = 14.0;
  static const double rowHeight = 44.0;
  static const double compactHeaderHeight = 48.0;
  static const double panelPadding = 14.0;

  static const double sidebarWidth = 72.0;
  static const double tickerBarHeight = 30.0;
  static const double statusBarHeight = 24.0;
  static const double bottomPadding = 40.0;

  static const Duration animNormal = Duration(milliseconds: 300);

  // ─── Typography — police unique : Lora ────────────────────────────────────
  static TextStyle serif(BuildContext context,
          {double? size, FontWeight? weight, Color? color}) =>
      GoogleFonts.lora(
        fontSize: size ?? 24,
        fontWeight: weight ?? FontWeight.w800,
        color: color ?? getPrimaryText(context),
        letterSpacing: -0.5,
      );

  static TextStyle sans(BuildContext context,
          {double? size, FontWeight? weight, Color? color}) =>
      GoogleFonts.lora(
        fontSize: size ?? 14,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? getPrimaryText(context),
      );

  static TextTheme getTextTheme(bool isDark) {
    final titleColor = isDark ? textPrimary : const Color(0xFF1A1A1A);
    final bodyColor = isDark ? textSecondary : const Color(0xFF4A4A4A);

    return TextTheme(
      displayLarge: GoogleFonts.lora(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: titleColor,
        letterSpacing: -0.8,
      ),
      headlineMedium: GoogleFonts.lora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: titleColor,
        letterSpacing: -0.5,
      ),
      headlineSmall: GoogleFonts.lora(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: titleColor,
      ),
      bodyLarge: GoogleFonts.lora(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: bodyColor,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.lora(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: bodyColor,
        height: 1.5,
      ),
      labelSmall: GoogleFonts.lora(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: isDark ? accent : primary,
        letterSpacing: 1.5,
      ),
    );
  }

  // ─── Helper Methods ────────────────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color getBackground(BuildContext context) =>
      isDark(context) ? bgPrimary : lightBg;
  static Color getSurface(BuildContext context) =>
      isDark(context) ? bgSecondary : lightSurface;
  static Color getBorder(BuildContext context) =>
      isDark(context) ? borderDark : lightBorder;
  static Color getPrimaryText(BuildContext context) =>
      isDark(context) ? textPrimary : const Color(0xFF1A1A1A);
  static Color getSecondaryText(BuildContext context) =>
      isDark(context) ? textSecondary : const Color(0xFF57606A);

  static Color backgroundShim(BuildContext context) =>
      isDark(context) ? bgPrimary : const Color(0xFFF1F5F9);
  static Color sectionBackground(BuildContext context) =>
      isDark(context) ? bgSecondary : const Color(0xFFF8FAFC);
  static Color borderShim(BuildContext context) => getBorder(context);
  static Color rowSurface(BuildContext context) =>
      isDark(context) ? surfaceDeep : lightSurface;
  static Color mutedSurface(BuildContext context) =>
      isDark(context) ? surfaceMid : lightSurfaceLight;
  static Color accentLine(BuildContext context) =>
      isDark(context) ? gold.withValues(alpha: 0.75) : primary;

  static EdgeInsets get pagePadding => const EdgeInsets.fromLTRB(
      screenPadding, sectionGap, screenPadding, bottomPadding);
  static EdgeInsets get compactPanelPadding =>
      const EdgeInsets.all(panelPadding);

  static TextStyle overline(BuildContext context, {Color? color}) =>
      GoogleFonts.lora(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: color ?? gold,
        letterSpacing: 1.6,
      );

  static TextStyle compactTitle(BuildContext context,
          {double size = 18, Color? color}) =>
      GoogleFonts.lora(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? getPrimaryText(context),
        height: 1.12,
      );

  static TextStyle compactBody(BuildContext context,
          {double size = 12, Color? color}) =>
      GoogleFonts.lora(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? getSecondaryText(context),
        height: 1.35,
      );

  // ─── Widget Builders (GS Style) ──────────────────────────────────────────
  static Widget section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: GoogleFonts.lora(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5, color: accent),
            ],
          ),
        ),
        child,
      ],
    );
  }

  static Widget editorialTile({required Widget child, Color? accentColor}) {
    return Container(
      decoration: BoxDecoration(
        border:
            Border(left: BorderSide(color: accentColor ?? primary, width: 3)),
      ),
      child: child,
    );
  }

  static Widget tile({required Widget child, Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      child: child,
    );
  }

  // ─── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? bgPrimary : lightBg;
    final surface = isDark ? bgSecondary : lightSurface;
    final border = isDark ? borderDark : lightBorder;
    final textPri = isDark ? textPrimary : const Color(0xFF1A1A1A);
    final textSec = isDark ? textSecondary : const Color(0xFF57606A);
    final divider = isDark ? dividerSubtle : const Color(0xFFE2E8F0);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: accent,
      surface: surface,
      onSurface: textPri,
      onPrimary: Colors.white,
      outline: border,
    );

    final textTheme = getTextTheme(isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      cardColor: surface,
      dividerColor: divider,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // ── AppBar ────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPri,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 2.0,
        ),
        iconTheme: IconThemeData(color: primary, size: 20),
        actionsIconTheme: IconThemeData(color: textSec, size: 18),
        surfaceTintColor: Colors.transparent,
      ),

      // ── Card ──────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: border, width: 0.5),
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0,
      ),

      // ── ListTile ──────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: primary,
        textColor: textPri,
        subtitleTextStyle: GoogleFonts.lora(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textSec,
        ),
        titleTextStyle: GoogleFonts.lora(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPri,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minLeadingWidth: 0,
        dense: true,
      ),

      // ── Dialog ────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: border, width: 0.5),
        ),
        titleTextStyle: GoogleFonts.lora(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: textPri,
          letterSpacing: 1.2,
        ),
        contentTextStyle: GoogleFonts.lora(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSec,
          height: 1.5,
        ),
      ),

      // ── BottomSheet ───────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Switch ────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF6E7681)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? primary
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Icon ──────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: primary, size: 18),

      // ── InputDecoration ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? bgTertiary : const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
        labelStyle: GoogleFonts.lora(fontSize: 12, color: textSec),
        hintStyle: GoogleFonts.lora(fontSize: 12, color: textSec),
      ),

      // ── PopupMenu ─────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: border, width: 0.5),
        ),
        textStyle: GoogleFonts.lora(fontSize: 13, color: textPri),
      ),

      // ── Chip ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? bgTertiary : const Color(0xFFF1F5F9),
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.lora(fontSize: 11, fontWeight: FontWeight.w600),
        side: BorderSide(color: border, width: 0.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── ElevatedButton ────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.lora(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:
              GoogleFonts.lora(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? bgElevated : const Color(0xFF1A1A1A),
        contentTextStyle: GoogleFonts.lora(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Scrollbar ─────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(primary.withValues(alpha: 0.3)),
        thickness: WidgetStateProperty.all(2),
        radius: const Radius.circular(2),
      ),
    );
  }

  // ─── Legacy Compatibility Methods ──────────────────────────────────────────
  static TextStyle h1(BuildContext context) =>
      serif(context, size: 26, weight: FontWeight.w800);
  static TextStyle h2(BuildContext context) =>
      serif(context, size: 18, weight: FontWeight.w700);
  static TextStyle heading(BuildContext context, {double size = 20}) =>
      serif(context, size: size, weight: FontWeight.w800);

  static TextStyle body(BuildContext context,
          {bool muted = false, double? size}) =>
      sans(context,
          size: size ?? 15,
          color: muted ? getSecondaryText(context) : getPrimaryText(context));

  static TextStyle label(BuildContext context) => sans(context,
          size: 11, weight: FontWeight.w900, color: getSecondaryText(context))
      .copyWith(letterSpacing: 1.2);

  static TextStyle numeric(BuildContext context,
          {Color? color,
          double size = 14.0,
          FontWeight weight = FontWeight.w600}) =>
      sans(context, size: size, weight: weight, color: color);

  // Additional aliases for terminal components
  static TextStyle terminalLabel(BuildContext context) => label(context);
  static TextStyle terminalMetric(BuildContext context,
          {Color? color, double size = 14.0}) =>
      numeric(context, color: color, size: size);
  static TextStyle terminalValue(BuildContext context,
          {Color? color, double size = 14.0}) =>
      numeric(context, color: color, size: size);
  static Color get surface => bgSecondary;
  static Color get border => borderDark;
  static const Color corporateGrey = Color(0xFF71717A);
}

extension SigmaThemeExtensions on BuildContext {
  bool get isDark => AppTheme.isDark(this);
  Color get bg => AppTheme.getBackground(this);
  Color get surface => AppTheme.getSurface(this);
  Color get border => AppTheme.getBorder(this);
  Color get primaryText => AppTheme.getPrimaryText(this);
  Color get secondaryText => AppTheme.getSecondaryText(this);
}
