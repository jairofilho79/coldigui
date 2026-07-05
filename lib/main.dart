import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/isar_bootstrap.dart';
import 'core/database/isar_provider.dart';
import 'core/providers/shared_prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  final isar = await openAppIsar();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ColdiguiApp(),
    ),
  );
}
