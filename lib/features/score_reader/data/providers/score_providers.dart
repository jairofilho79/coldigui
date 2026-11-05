import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/score_document.dart';
import '../../domain/usecases/parse_score_document.dart';
import '../audio/score_audio_engine.dart';
import '../datasources/score_byte_store.dart';
import '../repositories/score_file_repository.dart';
import '../repositories/score_sound_font_repository.dart';

final scoreByteStoreProvider = Provider<ScoreByteStorePort>(
  (ref) => createScoreByteStore(),
);

final scoreFileRepositoryProvider = Provider<ScoreFileRepository>((ref) {
  return ScoreFileRepository(
    ref.watch(scoreByteStoreProvider),
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

final scoreSoundFontRepositoryProvider = Provider<ScoreSoundFontRepository>((
  ref,
) {
  return ScoreSoundFontRepository(
    ref.watch(scoreByteStoreProvider),
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Fábrica do motor de áudio — sobrescrita nos testes.
final scoreAudioEngineFactoryProvider = Provider<ScoreAudioEngine Function()>(
  (ref) => SoundFontScoreAudioEngine.new,
);

/// Partitura de um `r2Key`; `null` só quando o arquivo não existe.
///
/// Cópia local primeiro (e revalidação em background), rede no miss. Mesmo
/// contrato do `gestureDocumentProvider`: `keepAlive()` só no sucesso e sem
/// retry automático. Cópia local ilegível é tratada como miss.
final scoreDocumentProvider = FutureProvider.autoDispose
    .family<ScoreDocument?, String>(retry: (_, _) => null, (ref, r2Key) async {
      final key = r2Key.trim();
      if (key.isEmpty) return null;
      final repository = ref.watch(scoreFileRepositoryProvider);

      final local = await repository.readLocal(key);
      if (local != null) {
        try {
          final doc = await _parse(local);
          ref.keepAlive();
          repository.refreshInBackground(key);
          return doc;
        } on ScoreDocumentParseException catch (error) {
          debugPrint('[partitura] cópia local ilegível de $key: $error');
        }
      }

      final bytes = await repository.fetch(key);
      if (bytes == null) return null;
      final doc = await _parse(bytes);
      ref.keepAlive();
      return doc;
    });

/// Fora da thread de UI no nativo (a grade do Castelo Forte tem 2,6 MB de
/// XML); na web `compute` roda inline.
Future<ScoreDocument> _parse(Uint8List bytes) =>
    compute(parseScoreDocument, bytes, debugLabel: 'parseScoreDocument');
