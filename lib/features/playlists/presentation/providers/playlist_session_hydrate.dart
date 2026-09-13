import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../coldigom/data/coldigom_praise_cache_warmup.dart';
import '../../../coldigom/domain/utils/coldigom_praise_id.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_media_face.dart';
import 'active_playlist_provider.dart';
import 'playlist_media_face_provider.dart';
import 'playlist_session_prefs.dart';
import 'playlists_provider.dart';

/// Praise IDs Coldigom embutidos em pdfIds/audioIds (mesmo codec Base64).
Set<String> collectColdigomPraiseIds({
  required Iterable<String> pdfIds,
  required Iterable<String> audioIds,
}) {
  final ids = <String>{};
  for (final id in pdfIds) {
    final praiseId = coldigomPraiseIdFromPdfId(id);
    if (praiseId != null) ids.add(praiseId);
  }
  for (final id in audioIds) {
    final praiseId = coldigomPraiseIdFromPdfId(id);
    if (praiseId != null) ids.add(praiseId);
  }
  return ids;
}

/// Índice da faixa persistida, ou 0.
int restoreQueueStartIndex(List<AudioTrack> tracks, String? focusedAudioId) {
  if (focusedAudioId == null || focusedAudioId.isEmpty || tracks.isEmpty) {
    return 0;
  }
  final index = tracks.indexWhere((track) => track.audioId == focusedAudioId);
  return index < 0 ? 0 : index;
}

/// Restaura playlist ativa, labels Coldigom e fila pausada após o boot.
///
/// Devolve `false` — sem tocar em nada — quando o Isar não abriu. Desde que o
/// app monta durante a abertura (A8), esta função roda no boot frio com o
/// datasource degradado, que responde `null` para qualquer id: tratar isso
/// como "a playlist não existe mais" apagaria de vez o id ativo das
/// SharedPreferences e derrubaria a face para pdf. Quem chama usa o retorno
/// para saber se pode considerar a sessão hidratada.
///
/// Com storage, começa pela migração única do carousel Isar (D3): a coleção
/// antiga vira a lista ativa quando não havia nenhuma, e é esvaziada em seguida.
Future<bool> hydratePlaylistSession(Ref ref) async {
  if (await awaitIsarSettled(ref) != IsarStatus.available) {
    debugPrint('[playlists] hidratação adiada: storage indisponível');
    return false;
  }

  final outcome = await ref.read(migrateCarouselStoreProvider)(
    activePlaylistId: ref.read(activePlaylistIdProvider),
  );
  final createdByMigration = outcome.createdPlaylistId;
  if (createdByMigration != null) {
    ref.read(activePlaylistIdProvider.notifier).set(createdByMigration);
    await ref.read(playlistsProvider.notifier).reload();
  }

  final activeId = ref.read(activePlaylistIdProvider);
  var pdfIds = const <String>[];
  var audioIds = const <String>[];

  if (activeId != null) {
    final playlist = await ref
        .read(playlistRepositoryProvider)
        .getById(activeId);
    if (playlist == null) {
      ref.read(activePlaylistIdProvider.notifier).clear();
    } else {
      pdfIds = playlist.pdfIds;
      audioIds = playlist.audioIds;
    }
  }

  await warmupColdigomPraiseIds(
    ref,
    collectColdigomPraiseIds(pdfIds: pdfIds, audioIds: audioIds),
  );

  final tracks = ref.read(catalogMaterialLookupProvider).tracksFor(audioIds);
  if (tracks.isEmpty) {
    if (ref.read(playlistMediaFaceProvider) == PlaylistMediaFace.audio) {
      await ref
          .read(playlistMediaFaceProvider.notifier)
          .setFace(PlaylistMediaFace.pdf);
    }
    return true;
  }

  final focusedAudioId = ref
      .read(sharedPreferencesProvider)
      .getString(kPlaylistFocusedAudioIdPrefsKey);
  await ref
      .read(audioPlayerSessionProvider.notifier)
      .restoreQueue(
        tracks,
        startIndex: restoreQueueStartIndex(tracks, focusedAudioId),
      );
  return true;
}
