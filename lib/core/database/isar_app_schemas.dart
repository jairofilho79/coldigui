import 'package:isar_plus/isar_plus.dart';

import 'collections/carousel_entry.dart';
import 'collections/louvor_cache.dart';
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
];
