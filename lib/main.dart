import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/collections/carousel_entry.dart';
import 'core/database/collections/louvor_cache.dart';
import 'core/database/collections/offline_pdf_index.dart';
import 'core/database/collections/playlist.dart';
import 'core/database/isar_provider.dart';
import 'core/providers/shared_prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      LouvorCacheSchema,
      CarouselEntrySchema,
      PlaylistSchema,
      OfflinePdfIndexSchema,
    ],
    directory: dir.path,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ColdiguiApp(),
    ),
  );
}
