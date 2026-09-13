import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../data/providers/offline_providers.dart';

export '../../data/providers/offline_repository_providers.dart'
    show offlineIndexRevisionProvider;

/// Disponibilidade offline de **todos** os PDFs do índice, por `pdfId` (A5).
///
/// Uma leitura síncrona do índice por mudança ([offlineIndexRevisionProvider]
/// sobe a cada escrita do datasource) — antes cada card do catálogo disparava
/// a própria query, e uma página de resultados virava dezenas de consultas
/// ao Isar. Os cards leem via `select((m) => m[id] ?? notAvailable)`, então só
/// quem teve a disponibilidade alterada reconstrói.
///
/// Sem Isar (modo degradado) o mapa é vazio: nada está offline.
final offlineAvailabilityMapProvider =
    Provider<Map<String, PdfOfflineAvailability>>((ref) {
      ref.watch(offlineIndexRevisionProvider);
      final local = ref.watch(offlinePdfLocalDatasourceProvider);
      return Map.unmodifiable({
        for (final entry in local.findAllSync())
          entry.pdfId: entry.isPersistent
              ? PdfOfflineAvailability.persistentOffline
              : PdfOfflineAvailability.cachedLru,
      });
    });
