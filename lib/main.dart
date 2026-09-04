import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap_app.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/error_reporter.dart';
import 'core/logging/install_error_handlers.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'features/audio_player/data/audio_background_bootstrap.dart';

final _log = AppLogger.of('main');

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      installErrorHandlers(const NoopErrorReporter());
      await ensureAudioBackgroundInitialized();

      final prefs = await SharedPreferences.getInstance();

      runApp(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const BootstrapApp(),
        ),
      );
    },
    (error, stackTrace) {
      _log.error('erro nao tratado na zona raiz', error, stackTrace);
      const NoopErrorReporter().report(
        error,
        stackTrace,
        context: 'runZonedGuarded',
      );
    },
  );
}
