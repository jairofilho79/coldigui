import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../data/audio_media_session.dart';
import '../../data/audio_player_web_providers.dart';
import '../../data/audio_web_unlock.dart';
import '../../data/web_audio_source_resolver.dart';
import '../../domain/entities/audio_track.dart';
import '../../domain/utils/audio_track_url.dart';

/// Estado da sessão global de áudio (página + face de playlist).
class AudioPlayerSessionState {
  const AudioPlayerSessionState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
    this.errorMessage,
    this.restoredWithoutPlayback = false,
  });

  final List<AudioTrack> queue;
  final int currentIndex;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool buffering;
  final String? errorMessage;

  /// A fila veio de [AudioPlayerSessionNotifier.restoreQueue] e o usuário ainda
  /// não comandou nenhuma reprodução.
  ///
  /// Sinal explícito de "restauração de sessão" para "Seguir o áudio": antes,
  /// a ausência de faixa anterior servia de proxy e engolia a **primeira**
  /// faixa de uma sessão nova (A6).
  final bool restoredWithoutPlayback;

  AudioTrack? get currentTrack {
    if (queue.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < queue.length - 1;

  AudioPlayerSessionState copyWith({
    List<AudioTrack>? queue,
    int? currentIndex,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? buffering,
    String? errorMessage,
    bool clearError = false,
    bool? restoredWithoutPlayback,
  }) {
    return AudioPlayerSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffering: buffering ?? this.buffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      restoredWithoutPlayback:
          restoredWithoutPlayback ?? this.restoredWithoutPlayback,
    );
  }
}

/// Índice da sessão enquanto o player troca de fonte.
///
/// `setUrl` / playlist nova dispara [currentIndexStream] em 0 — no iPad isso
/// pintava sempre o primeiro material (ex.: MIDI Geral).
int resolveSessionQueueIndex({
  required int pendingIndex,
  required int? playerIndex,
  required bool applyingSources,
}) {
  if (applyingSources || playerIndex == null) return pendingIndex;
  return playerIndex;
}

/// Fábrica do [AudioPlayer] da sessão.
///
/// Existe para os testes trocarem o player real por um duplo com
/// `errorStream`/`setAudioSources` controláveis — o `just_audio` não expõe
/// nenhuma outra costura para simular erro de reprodução.
final audioSessionPlayerFactoryProvider = Provider<AudioPlayer Function()>(
  (ref) => AudioPlayer.new,
);

/// Sessão única de áudio — fonte de verdade para page e playlist face.
class AudioPlayerSessionNotifier extends Notifier<AudioPlayerSessionState> {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  AudioMediaSessionController? _mediaSession;
  WebAudioSourceResolver? _sourceResolver;
  AudioPlayer Function() _playerFactory = AudioPlayer.new;
  bool _mediaSessionAttached = false;

  /// Geração da fila em vigor: cada `_applyQueue` incrementa e descarta o
  /// próprio resultado se outra chamada tiver começado depois (toque duplo).
  int _generation = 0;

  /// Geração **dona** da troca de fontes em curso, ou `null` se ninguém está
  /// trocando.
  ///
  /// A posse é por geração, e não um `bool`, porque uma chamada superada não
  /// tem como devolver a marca: se a chamada nova estourasse antes de marcar
  /// (`Uri.parse`, `unlockWebAudioIfNeeded`), a antiga terminava, via o `gen`
  /// desatualizado e deixava a marca presa em `true` — a sessão parava de
  /// seguir o `currentIndexStream` para sempre.
  int? _applyingSourcesGen;

  bool get _applyingSources => _applyingSourcesGen == _generation;

  AudioPlayer get _ensurePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final player = _playerFactory();
    _player = player;
    _subscriptions.addAll([
      player.playerStateStream.listen((playerState) {
        state = state.copyWith(
          playing: playerState.playing,
          buffering:
              playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering,
        );
        _mediaSession?.updatePlaybackState(playing: playerState.playing);
      }),
      player.positionStream.listen((position) {
        state = state.copyWith(position: position);
        _mediaSession?.updatePosition(
          position: position,
          duration: state.duration,
        );
      }),
      player.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
          _mediaSession?.updatePosition(
            position: state.position,
            duration: duration,
          );
        }
      }),
      player.currentIndexStream.listen((index) {
        if (index == null) return;
        final next = resolveSessionQueueIndex(
          pendingIndex: state.currentIndex,
          playerIndex: index,
          applyingSources: _applyingSources,
        );
        state = state.copyWith(currentIndex: next);
        _mediaSession?.updateTrack(state.currentTrack);
        _persistFocusedAudioId(state.currentTrack?.audioId);
      }),
      // Erro do player (decode/rede/CORS) não chega pelo `playerStateStream`:
      // sem isto a faixa simplesmente parava em silêncio.
      player.errorStream.listen((error) {
        // Erro atrasado de uma fonte já superada não pode pintar por cima da
        // fila que está entrando.
        if (_applyingSources) return;
        debugPrint('[audio] erro do player: $error');
        state = state.copyWith(
          errorMessage: error.toString(),
          playing: false,
          buffering: false,
        );
      }),
    ]);
    return player;
  }

  @override
  AudioPlayerSessionState build() {
    _playerFactory = ref.read(audioSessionPlayerFactoryProvider);
    if (kIsWeb) {
      _sourceResolver = ref.read(webAudioSourceResolverProvider);
      _mediaSession = ref.read(audioMediaSessionControllerProvider);
    }

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
      _sourceResolver?.revokeAll();
      _mediaSession?.detach();
      unawaited(_player?.dispose());
      _player = null;
    });
    return const AudioPlayerSessionState();
  }

  void _ensureMediaSessionAttached() {
    if (!kIsWeb || _mediaSessionAttached || _mediaSession == null) return;
    _mediaSession!.attach(
      callbacks: (
        onPlay: playPause,
        onPause: playPause,
        onPrevious: skipToPrevious,
        onNext: skipToNext,
        onSeek: seek,
      ),
    );
    _mediaSessionAttached = true;
  }

  Future<Uri> _playbackUriForTrack(AudioTrack track) async {
    // HTTP + CORP + crossOrigin. blob: com anonymous falha no Chrome/Safari.
    return Uri.parse(AudioTrackUrl.fetchUrlForTrack(track));
  }

  void _persistFocusedAudioId(String? audioId) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (audioId == null || audioId.isEmpty) {
      unawaited(prefs.remove(kPlaylistFocusedAudioIdPrefsKey));
    } else {
      unawaited(prefs.setString(kPlaylistFocusedAudioIdPrefsKey, audioId));
    }
  }

  /// Define fila e inicia em [startIndex].
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) {
    return _applyQueue(tracks, startIndex: startIndex, autoplay: true);
  }

  /// Restaura a fila no reload **sem** tocar.
  Future<void> restoreQueue(List<AudioTrack> tracks, {int startIndex = 0}) {
    return _applyQueue(tracks, startIndex: startIndex, autoplay: false);
  }

  Future<void> _applyQueue(
    List<AudioTrack> tracks, {
    required int startIndex,
    required bool autoplay,
  }) async {
    if (tracks.isEmpty) return;
    final gen = ++_generation;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(
      queue: List<AudioTrack>.from(tracks),
      currentIndex: safeIndex,
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
      restoredWithoutPlayback: !autoplay,
    );
    _persistFocusedAudioId(tracks[safeIndex].audioId);

    try {
      final player = _ensurePlayer;
      if (kIsWeb && autoplay) {
        await unlockWebAudioIfNeeded(
          player,
          immediateUrl: AudioTrackUrl.fetchUrlForTrack(tracks[safeIndex]),
        );
        if (gen != _generation) return;
      }

      _ensureMediaSessionAttached();

      final sources = <AudioSource>[];
      for (final track in tracks) {
        final uri = await _playbackUriForTrack(track);
        if (gen != _generation) return;
        sources.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: track.audioId,
              title: track.categoria.isNotEmpty ? track.categoria : track.nome,
              album: track.nome,
              artist: track.author.isNotEmpty
                  ? track.author
                  : (track.numero.isNotEmpty ? track.numero : 'Coldigom'),
              extras: {'groupId': track.groupId, 'r2Key': track.r2Key},
            ),
          ),
        );
      }

      _applyingSourcesGen = gen;
      try {
        await player.setAudioSources(
          sources,
          initialIndex: safeIndex,
          preload: autoplay && !kIsWeb,
        );
        if (gen != _generation) return;
        state = state.copyWith(currentIndex: safeIndex, playing: false);
        _mediaSession?.updateTrack(tracks[safeIndex]);
        if (autoplay) {
          await player.play();
        }
      } finally {
        // Só quem ainda é a geração vigente devolve a marca: uma chamada
        // superada terminando depois não pode destravar o índice de quem
        // ainda está carregando.
        if (gen == _generation) _applyingSourcesGen = null;
      }
    } on Object catch (e) {
      // Chamada superada: quem venceu já cuidou do estado (e um
      // `PlayerInterruptedException` daqui é justamente o esperado).
      if (gen != _generation) return;
      _applyingSourcesGen = null;
      debugPrint('[audio] falha ao aplicar a fila: $e');
      state = state.copyWith(errorMessage: e.toString(), playing: false);
    }
  }

  Future<void> playTrack(AudioTrack track) => playQueue([track]);

  /// "Tentar de novo": reaplica a fila atual a partir do índice em foco.
  ///
  /// Conta como intenção de reprodução do usuário (encerra a marca de
  /// restauração, igual a `playPause`).
  Future<void> retryCurrent() async {
    final tracks = state.queue;
    if (tracks.isEmpty) return;
    _markUserPlaybackIntent();
    await _applyQueue(tracks, startIndex: state.currentIndex, autoplay: true);
  }

  /// Marca que o usuário comandou a reprodução, encerrando a restauração.
  ///
  /// Também apaga o erro visível: se o comando der certo, a face volta a
  /// mostrar o seek; se falhar de novo, o `catch` repõe a mensagem.
  void _markUserPlaybackIntent() {
    if (!state.restoredWithoutPlayback && state.errorMessage == null) return;
    state = state.copyWith(clearError: true, restoredWithoutPlayback: false);
  }

  /// Nenhum comando de transporte pode estourar para o widget: registra e
  /// deixa o erro visível com "Tentar de novo".
  void _reportTransportFailure(String action, Object error) {
    debugPrint('[audio] $action falhou: $error');
    state = state.copyWith(errorMessage: error.toString());
  }

  Future<void> playPause() async {
    final player = _player;
    if (player == null || state.queue.isEmpty) return;
    _markUserPlaybackIntent();
    try {
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } on Object catch (e) {
      _reportTransportFailure('playPause', e);
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } on Object catch (e) {
      _reportTransportFailure('seek', e);
    }
  }

  Future<void> skipToPrevious() async {
    final player = _player;
    if (player == null) return;
    _markUserPlaybackIntent();
    try {
      if (state.position > const Duration(seconds: 3) || !state.hasPrevious) {
        await player.seek(Duration.zero);
        return;
      }
      await player.seekToPrevious();
    } on Object catch (e) {
      _reportTransportFailure('skipToPrevious', e);
    }
  }

  Future<void> skipToNext() async {
    if (!state.hasNext) return;
    _markUserPlaybackIntent();
    try {
      await _player?.seekToNext();
    } on Object catch (e) {
      _reportTransportFailure('skipToNext', e);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    _markUserPlaybackIntent();
    try {
      await _player?.seek(Duration.zero, index: index);
      await _player?.play();
    } on Object catch (e) {
      _reportTransportFailure('skipToIndex', e);
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object catch (e) {
      _reportTransportFailure('stop', e);
    }
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  /// Encerra o player: para e limpa fila/posição (diferente de [stop]).
  Future<void> close() async {
    // Descarta uma `_applyQueue` em voo: sem isto ela repovoava a sessão
    // depois do fechamento. Como ninguém mais roda o `finally` dela, a flag
    // de troca de fonte é liberada aqui.
    _generation++;
    _applyingSourcesGen = null;
    try {
      await _player?.stop();
    } on Object catch (e) {
      debugPrint('[audio] close falhou ao parar o player: $e');
    }
    _sourceResolver?.revokeAll();
    _mediaSession?.updateTrack(null);
    state = const AudioPlayerSessionState();
    _persistFocusedAudioId(null);
  }
}

final audioPlayerSessionProvider =
    NotifierProvider<AudioPlayerSessionNotifier, AudioPlayerSessionState>(
      AudioPlayerSessionNotifier.new,
    );
