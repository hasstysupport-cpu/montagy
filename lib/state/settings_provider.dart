import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings: language + AI provider keys (stored ONLY on device).
class AppSettings {
  final String locale; // 'ar' | 'en'
  final String openrouterKey;
  final String openrouterModel;
  final String groqKey;
  final String geminiKey;
  final String tavilyKey;
  final String defaultCaptionStyleId;

  const AppSettings({
    this.locale = 'ar',
    this.openrouterKey = '',
    this.openrouterModel = 'deepseek/deepseek-chat-v3-0324:free',
    this.groqKey = '',
    this.geminiKey = '',
    this.tavilyKey = '',
    this.defaultCaptionStyleId = 'tiktok_karaoke',
  });

  AppSettings copyWith({
    String? locale,
    String? openrouterKey,
    String? openrouterModel,
    String? groqKey,
    String? geminiKey,
    String? tavilyKey,
    String? defaultCaptionStyleId,
  }) =>
      AppSettings(
        locale: locale ?? this.locale,
        openrouterKey: openrouterKey ?? this.openrouterKey,
        openrouterModel: openrouterModel ?? this.openrouterModel,
        groqKey: groqKey ?? this.groqKey,
        geminiKey: geminiKey ?? this.geminiKey,
        tavilyKey: tavilyKey ?? this.tavilyKey,
        defaultCaptionStyleId: defaultCaptionStyleId ?? this.defaultCaptionStyleId,
      );

  Map<String, dynamic> toJson() => {
        'locale': locale,
        'openrouterKey': openrouterKey,
        'openrouterModel': openrouterModel,
        'groqKey': groqKey,
        'geminiKey': geminiKey,
        'tavilyKey': tavilyKey,
        'defaultCaptionStyleId': defaultCaptionStyleId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        locale: j['locale'] as String? ?? 'ar',
        openrouterKey: j['openrouterKey'] as String? ?? '',
        openrouterModel: j['openrouterModel'] as String? ?? 'deepseek/deepseek-chat-v3-0324:free',
        groqKey: j['groqKey'] as String? ?? '',
        geminiKey: j['geminiKey'] as String? ?? '',
        tavilyKey: j['tavilyKey'] as String? ?? '',
        defaultCaptionStyleId: j['defaultCaptionStyleId'] as String? ?? 'tiktok_karaoke',
      );
}

/// Persistence layer for [AppSettings].
class SettingsStore {
  static const _kKey = 'montagy.settings.v1';

  static Future<AppSettings> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kKey);
      if (raw == null) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(s.toJson()));
  }
}

/// Global settings state — every mutation persists immediately.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(super.initial);

  Future<void> update(AppSettings Function(AppSettings) fn) async {
    state = fn(state);
    await SettingsStore.save(state);
  }

  Future<void> toggleLocale() => update((s) => s.copyWith(locale: s.locale == 'ar' ? 'en' : 'ar'));
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier(const AppSettings()));
