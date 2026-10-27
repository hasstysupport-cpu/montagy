import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Montagy dark theme — CapCut-inspired: deep blacks, neon purple/teal accents.
class AppColors {
  static const bg = Color(0xFF0B0B0F); // deepest background
  static const surface = Color(0xFF15151C); // cards / panels
  static const surface2 = Color(0xFF1E1E28); // elevated elements
  static const border = Color(0xFF2A2A38);
  static const text = Color(0xFFF4F4F8);
  static const textDim = Color(0xFF9A9AAD);

  static const primary = Color(0xFF8B5CF6); // neon violet
  static const primaryDark = Color(0xFF6D28D9);
  static const accent = Color(0xFF22D3EE); // cyan
  static const accent2 = Color(0xFFF472B6); // pink
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  static const gradPrimary = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradHot = LinearGradient(
    colors: [Color(0xFFF472B6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textDim,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        hintStyle: const TextStyle(color: AppColors.textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: Color(0x3322D3EE),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2,
        selectedColor: AppColors.primary.withOpacity(.35),
        labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  /// Arabic-friendly text style helper.
  static TextStyle ui(BuildContext ctx, {double? size, FontWeight? weight, Color? color}) =>
      GoogleFonts.cairo(fontSize: size ?? 14, fontWeight: weight, color: color);
}
