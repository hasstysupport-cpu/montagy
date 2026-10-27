import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/settings_provider.dart';
import 'core/i18n/strings.dart';

/// Bootstraps settings (locale, AI keys) before the app renders so the
/// first frame already has the user's language.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  final container = ProviderContainer(
    overrides: [settingsProvider.overrideWith((ref) => SettingsNotifier(settings))],
  );
  // Warm-up: nothing else needed; riverpod container handed to scope below.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MontagyApp(),
    ),
  );
}

/// Keep a direct reference so tree-shaking doesn't drop unused i18n.
const _ = S.ar;
