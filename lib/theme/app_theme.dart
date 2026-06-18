// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── palette ───────────────────────────────────────────────────────────────
  static const bg0       = Color(0xFF0D1117); // darkest bg
  static const bg1       = Color(0xFF161B22); // panel bg
  static const bg2       = Color(0xFF1C2128); // card bg
  static const bg3       = Color(0xFF21262D); // elevated

  static const border    = Color(0xFF30363D);
  static const accent    = Color(0xFF388BFD); // blue
  static const accentAlt = Color(0xFF3FB950); // green — live indicator
  static const warn      = Color(0xFFD29922);
  static const err       = Color(0xFFF85149);

  static const textPrim  = Color(0xFFE6EDF3);
  static const textSec   = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);

  // ── mono font ────────────────────────────────────────────────────────────
  static TextStyle mono({double size = 12, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color ?? textPrim,
        fontWeight: weight ?? FontWeight.w400,
      );

  static TextStyle ui({double size = 13, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color ?? textPrim,
        fontWeight: weight ?? FontWeight.w400,
      );

  // ── theme ─────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg0,
      colorScheme: const ColorScheme.dark(
        surface: bg1,
        surfaceContainerHighest: bg2,
        primary: accent,
        secondary: accentAlt,
        error: err,
        onSurface: textPrim,
        outline: border,
      ),
      dividerColor: border,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrim,
        displayColor: textPrim,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg1,
        foregroundColor: textPrim,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: ui(size: 14, weight: FontWeight.w600),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textSec,
        indicatorColor: accent,
        dividerColor: border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accent),
        ),
        labelStyle: ui(size: 12, color: textSec),
        hintStyle: ui(size: 12, color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle: ui(size: 13, weight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrim,
          side: const BorderSide(color: border),
          textStyle: ui(size: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bg2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: border),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: bg3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        textStyle: ui(size: 11, color: textPrim),
      ),
      cardTheme: CardThemeData(
        color: bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
