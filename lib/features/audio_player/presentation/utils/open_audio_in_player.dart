import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Navega para `/audio` com os query params da faixa (sem alterar a sessão).
///
/// No-op se já estiver na rota de áudio.
void pushAudioPlayerRoute(BuildContext context, AudioTrack track) {
  if (!context.mounted) return;
  final path = GoRouterState.of(context).uri.path;
  if (path == RoutePaths.audio) return;

  final params = <String, String>{
    UrlSyncParams.audioId: track.audioId,
    UrlSyncParams.titulo: track.nome,
    if (track.numero.isNotEmpty) UrlSyncParams.subtitulo: track.numero,
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  unawaited(context.push('${RoutePaths.audio}?$query'));
}

/// Índice inicial da fila — [startIndex] ganha; senão o [track.audioId].
int audioQueueStartIndex({
  required List<AudioTrack> tracks,
  required AudioTrack track,
  int? startIndex,
}) {
  if (tracks.isEmpty) return 0;
  if (startIndex != null) {
    return startIndex.clamp(0, tracks.length - 1);
  }
  final found = tracks.indexWhere((t) => t.audioId == track.audioId);
  return found < 0 ? 0 : found;
}

/// Inicia playback na sessão global sem navegar (gesto iOS no mesmo tap).
///
/// Devolve o desfecho da entrada na lista ativa. Tocar não depende do storage
/// (o áudio vem da rede): sem Isar a faixa toca e o resultado é
/// [AddToActiveOutcome.storageUnavailable] — quem tem `BuildContext`
/// ([openAudioInPlayer]) o traduz em snackbar. Nada é pré-julgado no toque
/// (A8): a decisão é do editor, não de `isarAvailableProvider`.
Future<AddToActiveOutcome> playAudioInSession({
  required WidgetRef ref,
  required AudioTrack track,
  List<AudioTrack>? queue,
  int? startIndex,
}) async {
  final tracks = queue == null || queue.isEmpty ? [track] : queue;
  final index = audioQueueStartIndex(
    tracks: tracks,
    track: track,
    startIndex: startIndex,
  );

  unawaited(
    ref
        .read(playlistMediaFaceProvider.notifier)
        .setFace(PlaylistMediaFace.audio),
  );
  // Os dois começam no mesmo tick: `playQueue` precisa sair do gesto (iOS), e
  // `addToActive` nunca lança por falta de storage — devolve o desfecho.
  final add = ref
      .read(activePlaylistEditorProvider.notifier)
      .addToActive(track.audioId, kind: MaterialKind.audio);
  await ref
      .read(audioPlayerSessionProvider.notifier)
      .playQueue(tracks, startIndex: index);
  return add;
}

/// Abre a rota `/audio` e inicia a faixa (ou fila) na sessão global.
///
/// Sem storage a faixa toca e a rota abre normalmente; só a lista ativa não
/// gravou, e é isso que a snackbar diz.
Future<void> openAudioInPlayer({
  required WidgetRef ref,
  required BuildContext context,
  required AudioTrack track,
  List<AudioTrack>? queue,
  int? startIndex,
  bool pushRoute = true,
}) async {
  final play = playAudioInSession(
    ref: ref,
    track: track,
    queue: queue,
    startIndex: startIndex,
  );
  if (pushRoute) {
    pushAudioPlayerRoute(context, track);
  }
  final outcome = await play;
  if (outcome != AddToActiveOutcome.storageUnavailable) return;
  if (!context.mounted) return;
  showAppSnackbar(
    context,
    AppLocalizations.of(context)!.playlistStorageUnavailable,
  );
}
