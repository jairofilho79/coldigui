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
import '../../data/datasources/audio_playback_position_store.dart';
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
    this.speed = 1.0,
  });

  final List<AudioTrack> queue;
  final int currentIndex;
  final bool playing;
  final bool buffering;
  final String? errorMessage;

  /// Velocidade de reprodução (`0.75`, `1.0`, `1.25`, `1.5` na UI) — C12.
  /// Reaplicada em [AudioPlayerSessionNotifier._applyQueue] porque trocar de
  /// fonte no `just_audio` reseta a velocidade do player pro padrão.
  final double speed;

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
    double? speed,
  }) {
    return AudioPlayerSessionState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      restoredWithoutPlayback:
          restoredWithoutPlayback ?? this.restoredWithoutPlayback,
      speed: speed ?? this.speed,
    );
  }
}

/// Decide quando reenviar a posição pra media session do sistema: no máximo
/// uma vez por segundo (padrão), exceto quando `force` (troca de duração ou
/// seek) — sem isto o listener de `positionStream` (~5 Hz) chamaria
/// `updatePosition` a cada tick (A7).
///
/// [minInterval] é reutilizado por [AudioPlaybackPositionStore] (C12), que
/// grava a posição no máximo a cada 5 s enquanto toca — mesma lógica de
/// janela, intervalo diferente.
@visibleForTesting
class MediaSessionPositionThrottle {
  MediaSessionPositionThrottle({
    DateTime Function()? now,
    Duration? minInterval,
  }) : _now = now ?? DateTime.now,
       _minInterval = minInterval ?? const Duration(seconds: 1);

  final DateTime Function() _now;
  final Duration _minInterval;
  DateTime? _lastSentAt;

  /// `true` quando o chamador deve mandar a posição agora (e já registra o
  /// envio, avançando a janela).
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

/// Tempo máximo aceitável de `buffering` antes de virar erro visível.
///
/// Bug real (web, avanço automático dentro da fila): quando o just_audio
/// troca de faixa sozinho (fim natural da anterior) e o carregamento da
/// próxima trava — rede lenta, asset ausente, `just_audio_web` engole a
/// falha do `<audio>` sem nunca completar nem emitir `errorStream` — o
/// `processingState` fica preso em `loading`/`buffering` para sempre.
/// `buffering: true` desabilita o play/pause (mini player e tela cheia) sem
/// nenhum sinal de erro: o usuário "não consegue nem desligar nem pausar
/// nada" e parece que o player sumiu. Mesma lógica do `isarOpenTimeout`
/// (`core/database/isar_provider.dart`) — nunca deixar o app preso num
/// spinner para sempre.
const audioBufferingTimeout = Duration(seconds: 20);

/// Última posição de reprodução gravada (C12) — `SharedPreferences`.
final audioPlaybackPositionStoreProvider = Provider<AudioPlaybackPositionStore>(
  (ref) => AudioPlaybackPositionStore(ref.watch(sharedPreferencesProvider)),
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
  late AudioPlaybackPositionStore _positionStore;

  /// Arma quando `buffering` vira `true`; dispara [audioBufferingTimeout]
  /// depois sem sinal nenhum de progresso — ver [audioBufferingTimeout].
  Timer? _bufferingWatchdog;

  /// C12: no máximo uma gravação a cada 5 s enquanto toca (mesmo padrão do
  /// [_mediaSessionPositionThrottle], janela maior).
  final _positionStoreThrottle = MediaSessionPositionThrottle(
    minInterval: const Duration(seconds: 5),
  );

  /// `audioId` dono da última duração observada (`durationStream`) — C12 fix
  /// round 2.
  ///
  /// `durationStream` ignora emissões `null` e nada zera o `duration` do
  /// [audioPlayerPositionProvider] numa troca **dentro da fila**
  /// (`skipToNext`/`skipToPrevious`/`skipToIndex`/avanço automático do
  /// player) — só `_applyQueue` faz isso. Sem essa marca, a duração da faixa
  /// anterior ficava "pendurada" no provider e [_persistCurrentPosition]
  /// gravava a duração errada sob o id da faixa nova.
  String? _durationForAudioId;

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

  /// Faixa da fila em [state.queue] no índice que [player] reporta agora —
  /// resolvido pela mesma regra do `currentIndexStream`
  /// ([resolveSessionQueueIndex]), já que `player.currentIndex` pode estar à
  /// frente do próprio stream (C12 fix round 3, ver `durationStream` acima).
  AudioTrack? _trackAtPlayerIndex(AudioPlayer player) {
    final index = resolveSessionQueueIndex(
      pendingIndex: state.currentIndex,
      playerIndex: player.currentIndex,
      applyingSources: _applyingSources,
    );
    if (index < 0 || index >= state.queue.length) return null;
    return state.queue[index];
  }

  AudioPlayer get _ensurePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final player = _playerFactory();
    _player = player;
    _subscriptions.addAll([
      player.playerStateStream.listen((playerState) {
        final buffering =
            playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering;
        state = state.copyWith(
          playing: playerState.playing,
          buffering: buffering,
        );
        _mediaSession?.updatePlaybackState(playing: playerState.playing);
        _updateBufferingWatchdog(buffering);
      }),
      player.positionStream.listen((position) {
        ref
            .read(audioPlayerPositionProvider.notifier)
            .update(position: position);
        _sendMediaSessionPosition(
          position: position,
          duration: ref.read(audioPlayerPositionProvider).duration,
        );
        // Gravação periódica (C12): só enquanto toca — pause/stop já gravam
        // na hora, fora daqui (`_persistCurrentPosition(force: true)`).
        if (state.playing) _persistCurrentPosition(position);
      }),
      player.durationStream.listen((duration) {
        if (duration != null) {
          ref
              .read(audioPlayerPositionProvider.notifier)
              .update(duration: duration);
          // Marca de quem é essa duração (C12 fix round 2) — sem isto uma
          // duração emitida atrasada, já noutra faixa, seria gravada com o
          // id errado em `_persistCurrentPosition`.
          //
          // A partir de `player.currentIndex` (fix round 3), não de
          // `state.currentTrack`: o just_audio emite `durationStream` antes
          // de `currentIndexStream` numa troca dentro da fila, e
          // `state.currentIndex` só muda quando o listener de
          // `currentIndexStream` (abaixo) rodar — `player.currentIndex` já
          // reflete a troca nesse momento.
          _durationForAudioId = _trackAtPlayerIndex(player)?.audioId;
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
        if (next != state.currentIndex) {
          // Troca de faixa dentro da fila (skip/avanço automático) não passa
          // por `_applyQueue` — sem isto a janela de 5 s e a duração da
          // faixa anterior ficariam presas na faixa nova (C12 fix round 2).
          _positionStoreThrottle.reset();
          // Fix round 3: só descarta se `_durationForAudioId` ainda não é o
          // da faixa nova — o `durationStream` acima pode ter chegado
          // primeiro (com o id certo, via `player.currentIndex`), e não pode
          // ser jogado fora só porque o `currentIndexStream` chegou depois.
          final newTrackId = next >= 0 && next < state.queue.length
              ? state.queue[next].audioId
              : null;
          if (_durationForAudioId != newTrackId) {
            _durationForAudioId = null;
          }
        }
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
        _cancelBufferingWatchdog();
        state = state.copyWith(
          errorMessage: error.toString(),
          playing: false,
          buffering: false,
        );
      }),
    ]);
    return player;
  }

  /// Arma/desarma o [_bufferingWatchdog] conforme [buffering] muda.
  ///
  /// Só arma um timer novo quando não há um já em voo — `buffering` pode
  /// reemitir `true` várias vezes seguidas (`playerStateStream` do
  /// `just_audio`) sem que isso deva reiniciar a contagem a cada tick.
  void _updateBufferingWatchdog(bool buffering) {
    if (!buffering) {
      _cancelBufferingWatchdog();
      return;
    }
    if (_bufferingWatchdog != null) return;
    final gen = _generation;
    _bufferingWatchdog = Timer(audioBufferingTimeout, () {
      _bufferingWatchdog = null;
      // A fila mudou nesse meio-tempo (`retryCurrent`/nova faixa) — quem
      // está tocando agora tem seu próprio watchdog; este já não fala por
      // ninguém.
      if (gen != _generation) return;
      // Já saiu de buffering por conta própria entre o timer disparar e
      // rodar (corrida inofensiva) — nada a fazer.
      if (!state.buffering) return;
      debugPrint(
        '[audio] buffering travado por mais de $audioBufferingTimeout — '
        'vira erro visível',
      );
      state = state.copyWith(
        errorMessage: 'Carregamento travado',
        playing: false,
        buffering: false,
      );
    });
  }

  void _cancelBufferingWatchdog() {
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = null;
  }

  @override
  AudioPlayerSessionState build() {
    _playerFactory = ref.read(audioSessionPlayerFactoryProvider);
    _positionStore = ref.read(audioPlaybackPositionStoreProvider);
    if (ref.read(platformCapabilitiesProvider).isWeb) {
      _sourceResolver = ref.read(webAudioSourceResolverProvider);
      _mediaSession = ref.read(audioMediaSessionControllerProvider);
    }

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
      _cancelBufferingWatchdog();
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

  /// Grava a posição da faixa em foco (C12) — a cada 5 s enquanto toca
  /// (`force: false`, via `positionStream`) e na hora, no pause/stop
  /// (`force: true`).
  ///
  /// Junto vai a duração observada (`audioPlayerPositionProvider`, se já
  /// conhecida) — `AudioTrack.duration` nunca é populado em produção, então
  /// é essa duração gravada que sustenta o gate de "perto do fim" em
  /// [_resolveRestorePosition] (C12 fix round 1).
  void _persistCurrentPosition(Duration position, {bool force = false}) {
    final track = state.currentTrack;
    if (track == null) return;
    if (!force && !_positionStoreThrottle.shouldSend()) return;
    // Só usa a duração conhecida quando ela realmente pertence à faixa em
    // foco — sem isto uma duração "pendurada" da faixa anterior (troca em
    // fila, sem passar por `_applyQueue`) seria gravada sob o id errado
    // (C12 fix round 2).
    final knownDuration = ref.read(audioPlayerPositionProvider).duration;
    final durationBelongsToTrack = _durationForAudioId == track.audioId;
    unawaited(
      _positionStore.write(
        track.audioId,
        position,
        duration: durationBelongsToTrack && knownDuration > Duration.zero
            ? knownDuration
            : null,
      ),
    );
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

  /// Posição gravada a usar como `initialPosition` do `setAudioSources`
  /// (C12), ou `null` para começar do zero.
  ///
  /// Só considera a posição gravada no boot (`restoreQueue`, `!autoplay`) e
  /// só quando o `trackId` bate com [target] — `playQueue` (tocar da
  /// lista/busca) sempre começa do zero. Quando a duração já é conhecida —
  /// prefere a de [target], mas `AudioTrack.duration` nunca é populado em
  /// produção hoje, então cai pra duração observada gravada junto no store
  /// (C12 fix round 1) — e a posição gravada está a menos de 5 s do fim,
  /// não retoma (a faixa já tinha praticamente terminado).
  Duration? _resolveRestorePosition({
    required bool autoplay,
    required AudioTrack target,
  }) {
    if (autoplay) return null;
    final stored = _positionStore.read();
    if (stored == null || stored.trackId != target.audioId) return null;

    final duration = target.duration ?? stored.duration;
    if (duration != null && duration > const Duration(seconds: 5)) {
      final threshold = duration - const Duration(seconds: 5);
      if (stored.position >= threshold) return null;
    }
    return stored.position;
  }

  Future<void> _applyQueue(
    List<AudioTrack> tracks, {
    required int startIndex,
    required bool autoplay,
  }) async {
    if (tracks.isEmpty) return;
    final gen = ++_generation;
    // Fila nova: o watchdog da faixa anterior (se algum ficou armado) não
    // fala mais por ninguém — o `gen` já cuidaria disso no disparo, mas
    // cancelar aqui evita um `Timer` real pendurado à toa.
    _cancelBufferingWatchdog();
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    _positionStoreThrottle.reset();
    _durationForAudioId = null;
    // Posição gravada (C12): só no boot (`restoreQueue`) e só quando o
    // trackId bate — tocar a partir da lista/busca (`playQueue`) começa do
    // zero. Perto do fim (< 5s restantes, quando a duração é conhecida) não
    // vale a pena retomar.
    final initialPosition = _resolveRestorePosition(
      autoplay: autoplay,
      target: tracks[safeIndex],
    );
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
          initialPosition: initialPosition,
          preload: autoplay && !ref.read(platformCapabilitiesProvider).isWeb,
        );
      } finally {
        _sourcesInFlight--;
      }

      // Daqui para baixo é escrita de estado: só a geração vigente escreve.
      if (gen != _generation) return;
      state = state.copyWith(currentIndex: safeIndex, playing: false);
      // Trocar de fonte reseta a velocidade do player pro padrão — reaplica
      // a escolhida pelo usuário (C12). Padrão (1.0) não precisa de chamada
      // extra ao player — evita um `await` a mais em toda troca de faixa (e
      // uma janela extra pro `currentIndexStream` de um player de verdade
      // cuspir o índice de garantia — spec original do `_sourcesInFlight`).
      // `close()` reseta a velocidade do player de volta a 1.0 (fix round 3)
      // pra este atalho continuar seguro depois de um `close()`.
      if (state.speed != 1.0) {
        await player.setSpeed(state.speed);
      }
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
        // Pausa não pode esperar a janela de 5 s (C12).
        _persistCurrentPosition(
          ref.read(audioPlayerPositionProvider).position,
          force: true,
        );
      } else {
        await player.play();
      }
    } on Object catch (e) {
      _reportTransportFailure('playPause', e);
    }
  }

  /// ±10 s (C12) — clampado em `[0, duration]` (sem limite superior quando a
  /// duração ainda não é conhecida).
  Future<void> seekBy(Duration delta) async {
    final positionState = ref.read(audioPlayerPositionProvider);
    var target = positionState.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final duration = positionState.duration;
    if (duration > Duration.zero && target > duration) target = duration;
    await seek(target);
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

  /// Velocidade de reprodução (C12) — `0.75`, `1.0`, `1.25` ou `1.5` na UI.
  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    try {
      await _player?.setSpeed(speed);
    } on Object catch (e) {
      _reportTransportFailure('setSpeed', e);
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
    // Antes de zerar a posição em memória (C12) — precisa da posição atual,
    // ainda presente no provider.
    _persistCurrentPosition(
      ref.read(audioPlayerPositionProvider).position,
      force: true,
    );
    try {
      await _player?.stop();
    } on Object catch (e) {
      _reportTransportFailure('stop', e);
    }
    _cancelBufferingWatchdog();
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    _positionStoreThrottle.reset();
    state = state.copyWith(playing: false, buffering: false);
  }

  /// Encerra o player: para e limpa fila/posição (diferente de [stop]).
  Future<void> close() async {
    // Descarta uma `_applyQueue` em voo: sem isto ela repovoava a sessão
    // depois do fechamento. O contador de trocas de fonte não se mexe aqui —
    // é do player, e quem o incrementou devolve no próprio `finally`.
    _generation++;
    _cancelBufferingWatchdog();
    try {
      await _player?.stop();
      // Fix round 3 (Minor): `close()` não descarta `_player` — o mesmo
      // player de verdade é reaproveitado na próxima fila — e `stop()` não
      // mexe na velocidade. Sem isto, o player ficava grudado na velocidade
      // escolhida antes do close() mesmo com `state` (zerado abaixo) já
      // mostrando 1.0x, porque `_applyQueue` pula `setSpeed` quando o
      // padrão (1.0) já bate com o estado.
      await _player?.setSpeed(1.0);
    } on Object catch (e) {
      debugPrint('[audio] close falhou ao parar o player: $e');
    }
    _sourceResolver?.revokeAll();
    _mediaSession?.updateTrack(null);
    ref.read(audioPlayerPositionProvider.notifier).reset();
    _mediaSessionPositionThrottle.reset();
    _positionStoreThrottle.reset();
    state = const AudioPlayerSessionState();
    _persistFocusedAudioId(null);
  }
}

final audioPlayerSessionProvider =
    NotifierProvider<AudioPlayerSessionNotifier, AudioPlayerSessionState>(
      AudioPlayerSessionNotifier.new,
    );
