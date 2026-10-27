import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_font.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'ui/home/home_screen.dart';

class MontagyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const MontagyApp({super.key, required this.prefs});

  @override
  State<MontagyApp> createState() => _MontagyAppState();
}

class _MontagyAppState extends State<MontagyApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    final saved = widget.prefs.getString('theme_mode');
    _mode = saved == 'light'
        ? ThemeMode.light
        : saved == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
  }

  void _setMode(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.prefs.setString(
        'theme_mode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // خط الواجهة افتراضياً لكل النصوص
        return DefaultTextStyle(
          style: AppFont.w(400, size: 14, color: AppColors.darkText)
              .copyWith(color: Theme.of(context).textTheme.bodyMedium?.color),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(
        prefs: widget.prefs,
        onThemeChanged: _setMode,
        themeMode: _mode,
      ),
    );
  }
}

/// شعار مونتاجي (M متدرج).
class MontagyLogo extends StatelessWidget {
  final double size;
  const MontagyLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LogoPainter(),
        size: Size.square(size),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final pts = [
      Offset(w * 0.26, w * 0.72),
      Offset(w * 0.26, w * 0.32),
      Offset(w * 0.5, w * 0.58),
      Offset(w * 0.74, w * 0.32),
      Offset(w * 0.74, w * 0.72),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);

    // مثلث تشغيل صغير
    final tri = Path()
      ..moveTo(w * 0.58, w * 0.66)
      ..lineTo(w * 0.58, w * 0.82)
      ..lineTo(w * 0.72, w * 0.74)
      ..close();
    canvas.drawPath(tri, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
