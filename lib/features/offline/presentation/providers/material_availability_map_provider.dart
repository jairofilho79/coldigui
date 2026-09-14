import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../../pdf_opening/domain/entities/pdf_offline_availability.dart';
import '../../data/providers/offline_audio_providers.dart';
import 'offline_availability_map_provider.dart';
import 'offline_coldigom_stats_provider.dart'
    show chordGestureCacheRevisionProvider;

/// Disponibilidade local de **qualquer** material por id (spec §5.3).
///
/// União de: `offlineAvailabilityMapProvider` (PDF, LRU ou persistente),
/// índice de áudio (sempre `persistentOffline`), cifras e gestos com corpo
/// não vazio no cache Isar (`persistentOffline` — nunca são evictados). O
/// marcador negativo (corpo vazio, 404) **não** conta: o material não
/// existe, e o sheet mostra isso pelo caminho de hoje. Letra e YouTube não
/// entram (regras fixas no sheet, O14).
///
/// Re-derivado pelas revisões de PDF, áudio e cifra/gestos — uma leitura por
/// mudança, `select` por card, como o mapa de PDF (A5). Uma cifra aberta
/// on-demand (fora do download) só entra aqui na próxima revisão — o
/// `chordSongProvider` não sobe nenhuma; é o download em lote quem sobe.
final materialAvailabilityMapProvider =
    Provider<Map<String, PdfOfflineAvailability>>((ref) {
      final pdfs = ref.watch(offlineAvailabilityMapProvider);
      ref.watch(offlineAudioIndexRevisionProvider);
      ref.watch(chordGestureCacheRevisionProvider);
      final audio = ref.watch(offlineAudioLocalDatasourceProvider);
      final chords = ref.watch(chordContentLocalDatasourceProvider);
      final gestures = ref.watch(gestureContentLocalDatasourceProvider);

      final map = <String, PdfOfflineAvailability>{...pdfs};
      for (final entry in audio.findAllSync()) {
        map[entry.audioId] = PdfOfflineAvailability.persistentOffline;
      }
      for (final r2Key in chords.allKeysWithContent()) {
        map[encodePdfId(r2Key)] = PdfOfflineAvailability.persistentOffline;
      }
      for (final r2Key in gestures.allKeysWithContent()) {
        map[encodePdfId(r2Key)] = PdfOfflineAvailability.persistentOffline;
      }
      return Map.unmodifiable(map);
    });
