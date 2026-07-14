import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap_app.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'features/audio_player/data/audio_background_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureAudioBackgroundInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BootstrapApp(),
    ),
  );
}
