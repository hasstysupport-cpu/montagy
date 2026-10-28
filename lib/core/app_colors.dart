import 'package:flutter/material.dart';

/// Montagy v2.1 — brand palette.
/// Dark: أزرق كهربائي على أسود عميق (CapCut-inspired premium dark).
/// Light: أخضر فاخر على أبيض نقي (نظام "أخضر وأبيض").
/// accentOf(context) يرجّع لون التمييز حسب الثيم الحالي.
class AppColors {
  // ── الأساس ──
  static const Color blue = Color(0xFF2E7DFF);
  static const Color blueLight = Color(0xFF5B9BFF);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color deepBlue = Color(0xFF1B4FD8);

  static const Color green = Color(0xFF1FA855);      // أخضر رئيسي (الثيم الفاتح)
  static const Color greenLight = Color(0xFF4ADE80);
  static const Color greenDeep = Color(0xFF147A3D);
  static const Color teal = Color(0xFF0D9488);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, cyan],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, teal],
  );

  /// لون التمييز حسب الثيم: أزرق في الداكن، أخضر في الفاتح.
  static Color accentOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? blue : green;

  /// تدرج التمييز حسب الثيم.
  static LinearGradient accentGradientOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? brandGradient : greenGradient;

  // ── الثيم الداكن: أزرق + أسود ──
  static const Color darkBg = Color(0xFF05070D);
  static const Color darkSurface = Color(0xFF0C111C);
  static const Color darkSurfaceHi = Color(0xFF141C2E);
  static const Color darkBorder = Color(0xFF1D2740);
  static const Color darkText = Color(0xFFF2F6FF);
  static const Color darkTextDim = Color(0xFF8B97AD);

  // ── الثيم الفاتح: أخضر + أبيض ──
  static const Color lightBg = Color(0xFFFBFDFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHi = Color(0xFFF0F5F0);
  static const Color lightBorder = Color(0xFFDCE6DC);
  static const Color lightText = Color(0xFF0E1A12);
  static const Color lightTextDim = Color(0xFF64746A);

  // ── ألوان وظيفية ──
  static const Color danger = Color(0xFFFF4D5E);
  static const Color success = Color(0xFF22C55E);
  static const Color warn = Color(0xFFFFB020);

  /// لوحة كانفس CapCut الأصلية (المستخرجة من كود التطبيق).
  static const List<Color> canvasPalette = [
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFCCCCCC), Color(0xFF999999),
    Color(0xFF666666), Color(0xFFE8073D), Color(0xFFFE5252), Color(0xFFFF8B40),
    Color(0xFFF56B00), Color(0xFFFFBB01), Color(0xFFFEFE8D), Color(0xFFC3CF47),
    Color(0xFF17B39D), Color(0xFF00917E), Color(0xFF1CC8DD), Color(0xFF469DF3),
    Color(0xFF1385D4), Color(0xFF2A73F7), Color(0xFF664DCD), Color(0xFFCD7DFC),
    Color(0xFFCF2179), Color(0xFFEC6095), Color(0xFFF598BF), Color(0xFFFFD2EF),
    Color(0xFF913A05), Color(0xFFAB7433), Color(0xFF5C7248), Color(0xFF24A348),
  ];

  /// لوحة ألوان النصوص والملصقات.
  static const List<Color> textPalette = [
    Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFFFB3147), Color(0xFFFD6D41),
    Color(0xFFFEF015), Color(0xFF4DE51A), Color(0xFF3AFAF2), Color(0xFF1EB4E1),
    Color(0xFF2A73F7), Color(0xFFFD86FD), Color(0xFF747474), Color(0xFFFD8E70),
    Color(0xFFFC992E), Color(0xFFFFD2EF), Color(0xFF5CFEBF), Color(0xFF95D4F9),
    Color(0xFFE94F86), Color(0xFFCD7DFC), Color(0xFF24A348), Color(0xFFF5E6C8),
  ];
}

/// ألوان مشتقة حسب السطوع (helper).
extension ColorX on Color {
  Color dim(double amount) => Color.fromARGB(
        alpha,
        (red * (1 - amount)).round(),
        (green * (1 - amount)).round(),
        (blue * (1 - amount)).round(),
      );
}

/// وصول سريع للون التمييز من أي BuildContext.
extension AccentContextX on BuildContext {
  Color get accent => AppColors.accentOf(this);
  LinearGradient get accentGradient => AppColors.accentGradientOf(this);
}
