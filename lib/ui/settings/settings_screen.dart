import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../services/projects_store.dart';

/// شاشة الإعدادات — المظهر + الذاكرة المؤقتة + حول.
class SettingsScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  const SettingsScreen({
    super.key,
    required this.prefs,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  (int, int) _sizes = (0, 0);

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    final sizes = await ProjectsStore.cacheSizes();
    if (mounted) setState(() => _sizes = sizes);
  }

  Future<void> _clearCache() async {
    await ProjectsStore.clearThumbCache();
    await _loadSizes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.cacheCleared)),
      );
    }
  }

  String _fmtBytes(int b) {
    if (b > 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
    }
    if (b > 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    if (b > 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: AppFont.w(700, size: 16).make(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _Section(S.appearance),
          Row(
            children: [
              for (final (mode, label, icon) in [
                (ThemeMode.dark, S.themeDark, Icons.dark_mode_outlined),
                (ThemeMode.light, S.themeLight, Icons.light_mode_outlined),
                (ThemeMode.system, S.themeSystem, Icons.brightness_auto_outlined),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onThemeChanged(mode);
                      widget.prefs.setString('theme_mode',
                          mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: widget.themeMode == mode
                            ? AppColors.blue
                            : (dark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: widget.themeMode == mode
                              ? AppColors.blue
                              : (dark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon,
                              size: 20,
                              color: widget.themeMode == mode
                                  ? Colors.white
                                  : null),
                          const SizedBox(height: 5),
                          AppFont.w(600, size: 10.5,
                                  color: widget.themeMode == mode
                                      ? Colors.white
                                      : null)
                              .make(label),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mode != ThemeMode.system) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 22),

          _Section('الذاكرة'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: AppFont.w(600, size: 13.5).make(S.clearCache),
            subtitle: AppFont.w(400, size: 11,
                    color: dark
                        ? AppColors.darkTextDim
                        : AppColors.lightTextDim)
                .make(_sizes.$1 == 0 && _sizes.$2 == 0
                    ? S.cacheEmpty
                    : 'الصور المصغرة: ${_fmtBytes(_sizes.$1)} • الوسائط المستوردة: ${_fmtBytes(_sizes.$2)}'),
            onTap: _clearCache,
          ),
          const SizedBox(height: 22),

          _Section(S.about),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                const MontagyLogo(size: 52),
                const SizedBox(height: 12),
                AppFont.w(900, size: 17).make(S.appName),
                AppFont.w(500, size: 11,
                        color: dark
                            ? AppColors.darkTextDim
                            : AppColors.lightTextDim)
                    .make('${S.version} 2.0.0'),
                const SizedBox(height: 14),
                AppFont.w(400, size: 12,
                        color: dark
                            ? AppColors.darkTextDim
                            : AppColors.lightTextDim,
                        height: 1.7)
                    .make(S.aboutBody),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _Section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          AppFont.w(800, size: 14).make(title),
        ],
      ),
    );
  }
}
