import 'package:flutter/material.dart';

/// Alexandria — الخط الرئيسي (متغير الوزن 100..900).
/// نستخدم fontVariations للتحكم في الوزن لأن الخط Variable.
class AppFont {
  static const String family = 'Alexandria';

  static TextStyle w(double weight,
      {double? size, Color? color, double? height, double? spacing}) {
    return TextStyle(
      fontFamily: family,
      fontVariations: [FontVariation('wght', weight)],
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }

  static TextTheme textTheme(Color text, Color dim) => TextTheme(
        displayLarge: w(800, size: 42, color: text, height: 1.15),
        displayMedium: w(800, size: 32, color: text, height: 1.2),
        headlineMedium: w(700, size: 24, color: text),
        headlineSmall: w(700, size: 20, color: text),
        titleLarge: w(700, size: 18, color: text),
        titleMedium: w(600, size: 16, color: text),
        titleSmall: w(600, size: 14, color: text),
        bodyLarge: w(400, size: 16, color: text, height: 1.5),
        bodyMedium: w(400, size: 14, color: text, height: 1.45),
        bodySmall: w(400, size: 12, color: dim),
        labelLarge: w(600, size: 14, color: text),
        labelMedium: w(500, size: 12, color: dim),
        labelSmall: w(500, size: 10, color: dim),
      );
}

/// امتداد: يحول TextStyle إلى Text بسرعة.
extension AppFontText on TextStyle {
  Widget make(String s) => Text(s, style: this);
}
