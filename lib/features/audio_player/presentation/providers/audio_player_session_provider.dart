import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../data/audio_media_session.dart';
import '../../data/audio_player_web_providers.dart';
import '../../data/audio_web_unlock.dart';
import '../../data/web_audio_source_resolver.dart';
import '../../domain/entities/audio_track.dart';
import '../../domain/utils/audio_track_url.dart';
import 'audio_player_position_provider.dart';

/// Estado da sessão global de áudio (página + face de playlist).
///
/// `position`/`duration` moraram aqui até a A7 — o `positionStream` do
/// `just_audio` tica a ~5 Hz e trocava a identidade deste objeto inteiro a
/// cada tick, derrubando tudo que observava a sessão (barra do shell,
/// presente em toda rota). Ficaram em [audioPlayerPositionProvider].
class AudioPlayerSessionState {
  const AudioPlayerSessionState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.buffering = false,
    this.errorMessage,
    this.restoredWithoutPlayback = false,
  });

  final List<AudioTrack> queue;
  final int currentIndex;
  final bool playing;
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
    bool? buffering,
    String? errorMessage,
    bool clearError = false,
    bool? restoredWithoutPlayback,
  }) {
    return AudioPlayerSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      restoredWithoutPlayback:
          restoredWithoutPlayback ?? this.restoredWithoutPlayback,
    );
  }
}

/// Decide quando reenviar a posição pra media session do sistema: no máximo
/// uma vez por segundo, exceto quando `force` (troca de duração ou seek) —
/// sem isto o listener de `positionStream` (~5 Hz) chamaria `updatePosition`
/// a cada tick (A7).
@visibleForTesting
class MediaSessionPositionThrottle {
  MediaSessionPositionThrottle({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastSentAt;

  static const _minInterval = Duration(seconds: 1);

  /// `true` quando o chamador deve mandar a posição agora (e já registra o
  /// envio, avançando a janela de 1 s).
  bool shouldSend({bool force = false}) {
    final now = _now();
    final lastSentAt = _lastSentAt;
    if (!force &&
        lastSentAt != null &&
        now.difference(lastSentAt) < _minInterval) {
      return false;
    }
    _lastSentAt = now;
    return true;
  }

  /// Troca de fila ou encerramento: a próxima posição tem que sair na hora.
  void reset() {
    _lastSentAt = null;
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
  final _mediaSessionPositionThrottle = MediaSessionPositionThrottle();

  /// Geração da fila em vigor: cada `_applyQueue` incrementa e descarta o
  /// próprio resultado se outra chamada tiver começado depois (toque duplo).
  int _generation = 0;

  /// Quantas trocas de fonte estão em voo **no player**.
  ///
  /// A marca é do player ("tem algum `setAudioSources` rodando?"), não da
  /// geração: o `currentIndexStream` cospe lixo enquanto o player troca de
  /// fonte, e quem sabe disso é o player, não a fila mais recente. Por isso o
  /// contador sobe e desce sem checar geração e abraça só a chamada ao player
  /// — uma carga superada que estourou antes de mexer no player nunca contou,
  /// e nada consegue deixar o contador preso.
  int _sourcesInFlight = 0;

  bool get _applyingSources => _sourcesInFlight > 0;

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
        ref
            .read(audioPlayerPositionProvider.notifier)
            .update(position: position);
        _sendMediaSessionPosition(
          position: position,
          duration: ref.read(audioPlayerPositionProvider).duration,
        );
      }),
      player.durationStream.listen((duration) {
        if (duration != null) {
          ref
              .read(audioPlayerPositionProvider.notifier)
              .update(duration: duration);
          // Duração nova (troca de faixa) não pode esperar a janela de 1 s.
          _sendMediaSessionPosition(
            position: ref.read(audioPlayerPositionProvider).position,
            duration: duration,
            force: true,
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
    if (ref.read(platformCapabilitiesProvider).isWeb) {
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

  /// Manda a posição pra media session do sistema, no máximo 1x/segundo
  /// (`force` ignora a janela — troca de duração ou seek).
  void _sendMediaSessionPosition({
    required Duration position,
    required Duration duration,
    bool force = false,
  }) {
    final mediaSession = _mediaSession;
    if (mediaSession == null) return;
    if (!_mediaSessionPositionThrottle.shouldSend(force: force)) return;
    mediaSession.updatePosition(position: position, duration: duration);
  }

  void _ensureMediaSessionAttached() {
    if (ref.read(platformCapabilitiesProvider).supportsBackgroundAudio ||
        _mediaSessionAttached ||
        _mediaSession == null) {
      return;
    }
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
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    state = state.copyWith(
      queue: List<AudioTrack>.from(tracks),
      currentIndex: safeIndex,
      playing: false,
      clearError: true,
      restoredWithoutPlayback: !autoplay,
    );
    _persistFocusedAudioId(tracks[safeIndex].audioId);

    try {
      final player = _ensurePlayer;
      if (ref.read(platformCapabilitiesProvider).needsUserGestureForAudio &&
          autoplay) {
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

      // O contador abraça só a mexida no player: entra antes e sai depois,
      // sem checar geração, para não haver caminho que o deixe preso.
      _sourcesInFlight++;
      try {
        await player.setAudioSources(
          sources,
          initialIndex: safeIndex,
          preload: autoplay && !ref.read(platformCapabilitiesProvider).isWeb,
        );
      } finally {
        _sourcesInFlight--;
      }

      // Daqui para baixo é escrita de estado: só a geração vigente escreve.
      if (gen != _generation) return;
      state = state.copyWith(currentIndex: safeIndex, playing: false);
      _mediaSession?.updateTrack(tracks[safeIndex]);
      if (autoplay) {
        await player.play();
      }
    } on Object catch (e) {
      // Chamada superada: quem venceu já cuidou do estado (e um
      // `PlayerInterruptedException` daqui é justamente o esperado).
      if (gen != _generation) return;
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
      // Seek não pode esperar a janela de 1 s: o usuário mudou a posição na
      // hora, a media session tem que refletir isso na hora.
      _sendMediaSessionPosition(
        position: position,
        duration: ref.read(audioPlayerPositionProvider).duration,
        force: true,
      );
    } on Object catch (e) {
      _reportTransportFailure('seek', e);
    }
  }

  Future<void> skipToPrevious() async {
    final player = _player;
    if (player == null) return;
    _markUserPlaybackIntent();
    try {
      final position = ref.read(audioPlayerPositionProvider).position;
      if (position > const Duration(seconds: 3) || !state.hasPrevious) {
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
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    state = state.copyWith(playing: false);
  }

  /// Encerra o player: para e limpa fila/posição (diferente de [stop]).
  Future<void> close() async {
    // Descarta uma `_applyQueue` em voo: sem isto ela repovoava a sessão
    // depois do fechamento. O contador de trocas de fonte não se mexe aqui —
    // é do player, e quem o incrementou devolve no próprio `finally`.
    _generation++;
    try {
      await _player?.stop();
    } on Object catch (e) {
      debugPrint('[audio] close falhou ao parar o player: $e');
    }
    _sourceResolver?.revokeAll();
    _mediaSession?.updateTrack(null);
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    state = const AudioPlayerSessionState();
    _persistFocusedAudioId(null);
  }
}

final audioPlayerSessionProvider =
    NotifierProvider<AudioPlayerSessionNotifier, AudioPlayerSessionState>(
      AudioPlayerSessionNotifier.new,
    );
