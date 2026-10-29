import 'dart:async';

import 'package:coldigui/core/routing/reading_navigation.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Navega para `/audio` com os query params da faixa (sem alterar a sessão).
///
/// No-op se já estiver na rota de áudio; vindo de outro leitor, substitui a
/// rota em vez de empilhar ([openReadingLocation]).
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
  openReadingLocation(context, '${RoutePaths.audio}?$query');
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
Future<void> playAudioInSession({
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

  final session = ref.read(audioPlayerSessionProvider);
  final notifier = ref.read(audioPlayerSessionProvider.notifier);
  if (isAudioTrackLoaded(session, tracks[index])) {
    // Já é a faixa da sessão: recarregar a fonte recomeçava do zero e deixava
    // a sessão sem duração nem estado de play — os streams do just_audio são
    // `distinct` e não reemitem a mesma duração / o mesmo `playing`.
    if (!session.playing) await notifier.playPause();
    return;
  }
  await notifier.playQueue(tracks, startIndex: index);
}

/// `true` quando [track] já é a faixa carregada (sem erro) na sessão —
/// abri-la de novo é só voltar a ela, não recarregar.
bool isAudioTrackLoaded(AudioPlayerSessionState session, AudioTrack track) {
  return session.errorMessage == null &&
      session.currentTrack?.audioId == track.audioId;
}

/// Abre a rota `/audio` e inicia a faixa (ou fila) na sessão global.
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
  await play;
}
