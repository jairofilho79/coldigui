import 'package:isar_plus/isar_plus.dart';

import 'collections/audio_flag.dart';
import 'collections/carousel_entry.dart';
import 'collections/chord_content_cache.dart';
import 'collections/coldigom_praise_cache.dart';
import 'collections/gesture_dictionary_cache.dart';
import 'collections/gesture_document_cache.dart';
import 'collections/louvor_cache.dart';
import 'collections/offline_audio_index.dart';
import 'collections/offline_pdf_index.dart';
import 'collections/playlist.dart';

/// Nome da instância Isar (ADR-001).
const kAppIsarName = 'plpcg_plus';

/// Schemas abertos no boot da aplicação.
final List<IsarGeneratedSchema> kAppIsarSchemas = [
  LouvorCacheSchema,
  CarouselEntrySchema,
  PlaylistSchema,
  OfflinePdfIndexSchema,
  OfflineAudioIndexSchema,
  AudioFlagSchema,
  ChordContentCacheSchema,
  GestureDocumentCacheSchema,
  GestureDictionaryCacheSchema,
  ColdigomPraiseCacheSchema,
];
