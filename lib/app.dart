import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'state/settings_provider.dart';
import 'ui/screens/home_screen.dart';

class MontagyApp extends ConsumerWidget {
  const MontagyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsProvider).locale;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.bg,
      ),
      child: MaterialApp(
        title: 'Montagy — مونتاجي',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        locale: locale == 'ar' ? const Locale('ar') : const Locale('en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
