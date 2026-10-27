import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_font.dart';

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkSurfaceHi,
    );
    final text = AppFont.textTheme(AppColors.darkText, AppColors.darkTextDim);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBg,
      canvasColor: AppColors.darkSurface,
      textTheme: text,
      fontFamily: AppFont.family,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFont.family,
          fontVariations: [FontVariation('wght', 700)],
          fontSize: 18,
          color: AppColors.darkText,
        ),
        iconTheme: IconThemeData(color: AppColors.darkText),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        modalBackgroundColor: AppColors.darkSurface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      splashColor: AppColors.blue.withValues(alpha: 0.12),
      highlightColor: AppColors.blue.withValues(alpha: 0.08),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.blue,
        inactiveTrackColor: AppColors.darkBorder,
        thumbColor: Colors.white,
        overlayColor: AppColors.blue.withValues(alpha: 0.15),
        trackHeight: 3,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.blue),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceHi,
        contentTextStyle: AppFont.w(500, size: 14, color: AppColors.darkText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: AppFont.w(700, size: 18, color: AppColors.darkText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          textStyle: AppFont.w(700, size: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.4),
          textStyle: AppFont.w(600, size: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: AppFont.w(600, size: 14),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.blue,
        selectionColor: AppColors.blue.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.blue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceHi,
        hintStyle: AppFont.w(400, size: 14, color: AppColors.darkTextDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceHi,
        selectedColor: AppColors.blue,
        labelStyle: AppFont.w(600, size: 13, color: AppColors.darkText),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: AppColors.blue,
        unselectedLabelColor: AppColors.darkTextDim,
        labelStyle: AppFont.w(700, size: 14),
        unselectedLabelStyle: AppFont.w(500, size: 14),
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.blue,
      ),
      listTileTheme: ListTileThemeData(
        textColor: AppColors.darkText,
        iconColor: AppColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.lightSurface,
      surfaceContainerHighest: AppColors.lightSurfaceHi,
    );
    final text = AppFont.textTheme(AppColors.lightText, AppColors.lightTextDim);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBg,
      canvasColor: AppColors.lightSurface,
      textTheme: text,
      fontFamily: AppFont.family,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFont.family,
          fontVariations: [FontVariation('wght', 700)],
          fontSize: 18,
          color: AppColors.lightText,
        ),
        iconTheme: IconThemeData(color: AppColors.lightText),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        modalBackgroundColor: AppColors.lightSurface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      splashColor: AppColors.blue.withValues(alpha: 0.10),
      highlightColor: AppColors.blue.withValues(alpha: 0.06),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.blue,
        inactiveTrackColor: AppColors.lightBorder,
        thumbColor: Colors.white,
        overlayColor: AppColors.blue.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.blue),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightText,
        contentTextStyle: AppFont.w(500, size: 14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: AppFont.w(700, size: 18, color: AppColors.lightText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          textStyle: AppFont.w(700, size: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.lightBorder, width: 1.4),
          textStyle: AppFont.w(600, size: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: AppFont.w(600, size: 14),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.blue,
        selectionColor: AppColors.blue.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.blue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceHi,
        hintStyle: AppFont.w(400, size: 14, color: AppColors.lightTextDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceHi,
        selectedColor: AppColors.blue,
        labelStyle: AppFont.w(600, size: 13, color: AppColors.lightText),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: AppColors.blue,
        unselectedLabelColor: AppColors.lightTextDim,
        labelStyle: AppFont.w(700, size: 14),
        unselectedLabelStyle: AppFont.w(500, size: 14),
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.blue,
      ),
      listTileTheme: ListTileThemeData(
        textColor: AppColors.lightText,
        iconColor: AppColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
