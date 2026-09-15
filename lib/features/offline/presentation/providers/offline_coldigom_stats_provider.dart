import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/pdf_id_codec.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../data/providers/offline_audio_providers.dart';
import '../../data/providers/offline_repository_providers.dart';
import '../../domain/entities/coldigom_download_target.dart';

/// Revisão dos caches de cifra/gestos — os datasources de texto não têm
/// callback de escrita, então quem grava em lote (o download Coldigom) sobe
/// isto ao terminar, e o mapa de disponibilidade e as stats re-derivam.
class ChordGestureCacheRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final chordGestureCacheRevisionProvider =
    NotifierProvider<ChordGestureCacheRevisionNotifier, int>(
      ChordGestureCacheRevisionNotifier.new,
    );

/// Contagens e bytes de um kind Coldigom no `/offline` (§5.3/§5.4).
class ColdigomKindStats {
  const ColdigomKindStats({
    required this.kindId,
    required this.kindName,
    required this.total,
    required this.downloaded,
    required this.bytesKnown,
    required this.bytesEstimated,
    required this.pendingBytes,
  });

  final String kindId;
  final String kindName;
  final int total;
  final int downloaded;

  /// Soma dos `size` do dump (todos os alvos do kind).
  final int bytesKnown;

  /// Soma das médias por tipo dos alvos sem `size`.
  final int bytesEstimated;

  /// Bytes (conhecidos + estimados) só dos alvos **ainda não** baixados.
  final int pendingBytes;

  bool get hasEstimate => bytesEstimated > 0;
  int get bytesTotal => bytesKnown + bytesEstimated;
}

class OfflineColdigomStats {
  const OfflineColdigomStats(this.byKind);

  static const empty = OfflineColdigomStats({});

  /// Por `kindId`, só kinds com pelo menos um alvo baixável (O10).
  final Map<String, ColdigomKindStats> byKind;

  /// Estimativa do que «Baixar selecionados» vai transferir.
  int pendingBytes(Set<String> kindIds) =>
      kindIds.fold(0, (sum, id) => sum + (byKind[id]?.pendingBytes ?? 0));
}

/// Stats por kind a partir do catálogo local + índices (§5.3).
///
/// Recalcula quando sobem as revisões (PDF, áudio, cifra/gestos) ou o
/// catálogo é re-hidratado. Corre em fatias de
/// [OfflineConfig.coldigomHydrationChunkSize] praises cedendo o event loop
/// — o padrão do `library_group_worker` —, sem `compute`: as linhas Isar não
/// atravessam isolates e a soma cabe entre frames.
///
/// Observa [coldigomSearchIndexProvider] (não [coldigomCatalogHydrationProvider]
/// diretamente): os dois mudam junto — o índice é derivado dele —, mas
/// `coldigomSearchIndexProvider` é um `Provider` síncrono, e um
/// `FutureProvider` observando outro `FutureProvider` que por sua vez
/// aguarda `isarInitializerProvider` (via `awaitIsarSettled`) trava o
/// Riverpod 3.3.2 neste cenário de teste (`ProviderContainer` puro, sem
/// `WidgetsBinding`) — reproduzido isoladamente fora deste arquivo.
final offlineColdigomStatsProvider = FutureProvider<OfflineColdigomStats>((
  ref,
) async {
  ref.watch(offlineIndexRevisionProvider);
  ref.watch(offlineAudioIndexRevisionProvider);
  ref.watch(chordGestureCacheRevisionProvider);
  ref.watch(coldigomSearchIndexProvider);

  final rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  if (rows.isEmpty) return OfflineColdigomStats.empty;

  final pdfs = ref.read(offlinePdfLocalDatasourceProvider).findAllSync();
  final present = <String>{
    for (final p in pdfs)
      if (p.isPersistent) p.pdfId,
    for (final a in ref.read(offlineAudioLocalDatasourceProvider).findAllSync())
      a.audioId,
    for (final k
        in ref.read(chordContentLocalDatasourceProvider).allKeysWithContent())
      encodePdfId(k),
    for (final k
        in ref.read(gestureContentLocalDatasourceProvider).allKeysWithContent())
      encodePdfId(k),
  };

  final kindNames = <String, String>{};
  final total = <String, int>{};
  final downloaded = <String, int>{};
  final known = <String, int>{};
  final estimated = <String, int>{};
  final pending = <String, int>{};

  for (var i = 0; i < rows.length; i++) {
    for (final m in ColdigomPraiseCacheMapper.decodeMaterials(rows[i])) {
      final kindId = m.kindId;
      final r2Key = m.r2Key;
      if (kindId == null || r2Key == null || r2Key.isEmpty) continue;
      if (!isColdigomDownloadableType(m.type)) continue;
      if (materialKindOfRawType(m.type) == MaterialKind.unknown) continue;
      kindNames[kindId] = m.kindName;
      total.update(kindId, (v) => v + 1, ifAbsent: () => 1);
      final size = m.size;
      final bytes =
          size ??
          OfflineConfig.coldigomEstimatedBytesByType[m.type.toLowerCase()] ??
          0;
      if (size != null) {
        known.update(kindId, (v) => v + size, ifAbsent: () => size);
      } else {
        estimated.update(kindId, (v) => v + bytes, ifAbsent: () => bytes);
      }
      if (present.contains(encodePdfId(r2Key))) {
        downloaded.update(kindId, (v) => v + 1, ifAbsent: () => 1);
      } else {
        pending.update(kindId, (v) => v + bytes, ifAbsent: () => bytes);
      }
    }
    if ((i + 1) % OfflineConfig.coldigomHydrationChunkSize == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  return OfflineColdigomStats({
    for (final kindId in total.keys)
      kindId: ColdigomKindStats(
        kindId: kindId,
        kindName: kindNames[kindId] ?? '',
        total: total[kindId]!,
        downloaded: downloaded[kindId] ?? 0,
        bytesKnown: known[kindId] ?? 0,
        bytesEstimated: estimated[kindId] ?? 0,
        pendingBytes: pending[kindId] ?? 0,
      ),
  });
});
