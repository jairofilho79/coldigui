import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
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

/// Abre a rota `/audio` e inicia a faixa (ou fila) na sessão global.
Future<void> openAudioInPlayer({
  required WidgetRef ref,
  required BuildContext context,
  required AudioTrack track,
  List<AudioTrack>? queue,
  int? startIndex,
}) async {
  final tracks = queue == null || queue.isEmpty ? [track] : queue;
  final index =
      startIndex ??
      tracks
          .indexWhere((t) => t.audioId == track.audioId)
          .clamp(0, tracks.length - 1);

  unawaited(
    ref
        .read(playlistMediaFaceProvider.notifier)
        .setFace(PlaylistMediaFace.audio),
  );

  // Navega antes do play: após pop do sheet o push imediato race e some
  // (PDF “sempre abre” porque resolve/download atrasa o push).
  pushAudioPlayerRoute(context, track);

  await ref
      .read(playlistsProvider.notifier)
      .addAudioToActivePlaylist(track.audioId);

  await ref
      .read(audioPlayerSessionProvider.notifier)
      .playQueue(tracks, startIndex: index);
}
