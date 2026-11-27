import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/offline_config.dart';
import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/data/datasources/audio_bytes_datasource.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../../gestures/domain/usecases/parse_gesture_dictionary.dart';
import '../../../gestures/domain/usecases/parse_gesture_document.dart';
import '../../../gestures/domain/utils/flatten_gesture_cards.dart';
import '../../../score_reader/data/providers/score_providers.dart';
import '../../domain/usecases/download_coldigom_materials.dart';
import '../../domain/usecases/remove_coldigom_downloads.dart';
import '../datasources/offline_coldigom_kind_selection_store.dart';
import 'offline_audio_providers.dart';
import 'offline_core_providers.dart';
import 'reader_offline_exclusions_provider.dart';

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
final downloadColdigomMaterialsProvider = Provider<DownloadColdigomMaterials>((
  ref,
) {
  final fetchAndStorePdf = ref.watch(fetchAndStorePdfProvider);
  return DownloadColdigomMaterials(
    catalog: ref.watch(coldigomCatalogLocalDatasourceProvider),
    pdfRepository: ref.watch(offlinePdfRepositoryProvider),
    pdfLocal: ref.watch(offlinePdfLocalDatasourceProvider),
    fetchPdf: (pdfId, r2Key, {cancelToken}) => fetchAndStorePdf(
      pdfId: pdfId,
      remotePath: '/$r2Key',
      persistentDownload: true,
      cancelToken: cancelToken,
    ),
    audioBytes: ref.watch(audioBytesDatasourceProvider),
    audioRepository: ref.watch(offlineAudioRepositoryProvider),
    chordRemote: ref.watch(chordContentDatasourceProvider),
    chordLocal: ref.watch(chordContentLocalDatasourceProvider),
    gestureRemote: ref.watch(gestureContentDatasourceProvider),
    gestureLocal: ref.watch(gestureContentLocalDatasourceProvider),
    figures: ref.watch(gestureFigureRepositoryProvider),
    figureKeysFor: (json) async {
      final document = parseGestureDocument(json);
      if (flattenGestureCards(document).isEmpty) return const {};
      final dictionary = await ref.read(gestureDictionaryProvider.future);
      return dictionary == null
          ? null
          : gestureFigureKeysForDocument(document, dictionary);
    },
    cachedFigureKeysFor: (json) async {
      try {
        final document = parseGestureDocument(json);
        if (flattenGestureCards(document).isEmpty) return const {};
        final cached = ref
            .read(gestureDictionaryLocalDatasourceProvider)
            .read();
        if (cached == null) return null;
        return gestureFigureKeysForDocument(
          document,
          parseGestureDictionary(cached.content),
        );
      } on GestureDocumentParseException catch (error) {
        debugPrint('[offline] documento de gestos ilegível: $error');
        return null;
      } on GestureDictionaryParseException catch (error) {
        debugPrint('[offline] dicionário de gestos ilegível: $error');
        return null;
      }
    },
    restoreLyrics: (praiseIds) => ref
        .read(readerOfflineExclusionsProvider.notifier)
        .include(
          praiseIds.map(
            (id) => readerOfflineExclusion(MaterialKind.lyrics, id),
          ),
        ),
    scoreFiles: ref.watch(scoreFileRepositoryProvider),
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
