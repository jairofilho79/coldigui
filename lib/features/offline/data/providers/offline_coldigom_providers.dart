import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../../gestures/domain/usecases/parse_gesture_document.dart';
import '../../../gestures/domain/utils/flatten_gesture_cards.dart';
import '../../domain/usecases/download_coldigom_materials.dart';
import '../../domain/usecases/remove_coldigom_downloads.dart';
import '../datasources/offline_coldigom_kind_selection_store.dart';
import 'offline_audio_providers.dart';
import 'offline_core_providers.dart';

/// DI — seleção local de kinds para download (O11).
final offlineColdigomKindSelectionStoreProvider =
    Provider<OfflineColdigomKindSelectionStore>((ref) {
      return OfflineColdigomKindSelectionStore(
        ref.watch(sharedPreferencesProvider),
      );
    });

/// DI — bytes de áudio para persistir (proxy na web, direto no nativo).
final audioBytesDatasourceProvider = Provider<AudioBytesDatasource>((ref) {
  return AudioBytesDatasource(
    ref.watch(dioProvider),
    apiBase: AppConfig.apiBaseUrl,
    isWeb: ref.watch(platformCapabilitiesProvider).isWeb,
  );
});

/// DI — [DownloadColdigomMaterials].
///
/// As figuras dos gestos precisam do dicionário para resolver os `r2Key`s
/// (`prefetchGestureFigures` faz o mesmo na tela); sem dicionário, o
/// documento fica gravado e as figuras são buscadas na primeira abertura.
final downloadColdigomMaterialsProvider = Provider<DownloadColdigomMaterials>((
  ref,
) {
  final fetchAndStorePdf = ref.watch(fetchAndStorePdfProvider);
  return DownloadColdigomMaterials(
    catalog: ref.watch(coldigomCatalogLocalDatasourceProvider),
    pdfRepository: ref.watch(offlinePdfRepositoryProvider),
    pdfLocal: ref.watch(offlinePdfLocalDatasourceProvider),
    fetchPdf: (pdfId, r2Key) => fetchAndStorePdf(
      pdfId: pdfId,
      remotePath: '/$r2Key',
      persistentDownload: true,
    ),
    audioBytes: ref.watch(audioBytesDatasourceProvider),
    audioRepository: ref.watch(offlineAudioRepositoryProvider),
    chordRemote: ref.watch(chordContentDatasourceProvider),
    chordLocal: ref.watch(chordContentLocalDatasourceProvider),
    gestureRemote: ref.watch(gestureContentDatasourceProvider),
    gestureLocal: ref.watch(gestureContentLocalDatasourceProvider),
    figures: ref.watch(gestureFigureRepositoryProvider),
    figureKeysFor: (json) async {
      final dictionary = await ref.read(gestureDictionaryProvider.future);
      if (dictionary == null) return const {};
      final keys = <String>{};
      for (final flat in flattenGestureCards(parseGestureDocument(json))) {
        final entry = dictionary.resolve(flat.card.gestureId);
        if (entry == null) continue;
        keys.add(entry.image);
        final gif = entry.gif;
        if (gif != null) keys.add(gif);
      }
      return keys;
    },
    concurrency: OfflineConfig.coldigomDownloadConcurrency,
  );
});

/// DI — [RemoveColdigomDownloads].
final removeColdigomDownloadsProvider = Provider<RemoveColdigomDownloads>((
  ref,
) {
  return RemoveColdigomDownloads(
    pdfRepository: ref.watch(offlinePdfRepositoryProvider),
    audioRepository: ref.watch(offlineAudioRepositoryProvider),
  );
});
