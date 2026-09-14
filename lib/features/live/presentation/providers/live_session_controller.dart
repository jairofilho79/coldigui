import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../../playlists/presentation/providers/active_playlist_provider.dart';
import '../../data/providers/live_providers.dart';
import '../../domain/entities/live_snapshot.dart';
import '../../domain/live_reconnect_policy.dart';
import '../../domain/ports/live_transport.dart';
import '../../domain/protocol/live_frames.dart';
import 'live_leader_session_prefs.dart';
import 'live_projection_provider.dart';
import 'live_session_state.dart';

export 'live_session_state.dart';

final _log = AppLogger.of('live');

/// Espera pelo `pong` da prova de vida ao voltar do segundo plano.
const kLivePingProbeTimeout = Duration(seconds: 5);

/// Debounce entre a última mudança da lista ativa do gestor e o `set`.
const kLiveLeaderSetDebounce = Duration(milliseconds: 300);

/// Close codes do DO (`room_core.ts`).
const int kLiveCloseEnded = 4001;
const int kLiveCloseReplaced = 4002;
const int kLiveCloseRetired = 4003;
const int kLiveCloseNotFound = 4004;

/// A lista ativa (com override otimista) + foco, no formato do DO.
LiveSnapshot liveSnapshotOfActiveList(Ref ref) {
  final playlist = ref.read(activePlaylistProvider);
  final entries = ref.read(activeEntriesProvider);
  final focus = ref.read(carouselFocusedKeyProvider);
  return LiveSnapshot(
    playlistId: playlist?.playlistId ?? '',
    name: playlist?.nome ?? '',
    entries: [for (final e in entries) e.entry],
    focusKey: focus != null && entries.any((e) => e.key == focus)
        ? focus
        : null,
  );
}

/// A sessão ao vivo do app inteiro (spec 2026-09-12-lista-ao-vivo, §6.1).
///
/// Único, `keepAlive` (provider sem `autoDispose`), vive o container todo:
/// sobrevive a rotas, e `ref.onDispose` fecha o socket quando o container
/// morre (hot restart, logout com `ProviderScope` novo). Toda conexão tem uma
/// **geração** (`_gen`): frames e fechos de uma geração antiga são ignorados
/// — é isto que impede o "socket fantasma" depois de `leave()`.
class LiveSessionController extends Notifier<LiveSessionState> {
  LiveConnection? _conn;
  StreamSubscription<String>? _sub;
  int _gen = 0;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _probeTimer;
  bool _paused = false;
  Future<void>? _connecting;
  String? _leaderFocusKey;
  bool _applyingFocus = false;
  Timer? _setDebounce;

  /// `startLive` pediu `start` mas a sala ainda não confirmou `live` — se o
  /// primeiro handshake falhar, o `room{idle}` da reconexão reenvia o `start`.
  bool _pendingStart = false;

  /// `_gen` de quando o `start` mais recente foi de fato mandado (`_conn`
  /// não nulo) — `null` enquanto nenhum foi mandado nesta conexão.
  ///
  /// RoomCore responde ao `hello` (`room{idle}`) **antes** de processar o
  /// `start` já enfileirado atrás dele (`await authenticate` dentro do
  /// `hello`); o `room{live}` que confirma o `start` chega **na mesma
  /// conexão** em que ele foi mandado. Comparar com `_gen` distingue esse eco
  /// (nada a fazer) de um `room{idle}`/`room{live}` de uma conexão nova
  /// (reconexão/retomada — reenviar `start` ou `set`, respectivamente).
  int? _startSentGen;

  @override
  LiveSessionState build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _probeTimer?.cancel();
      _setDebounce?.cancel();
      _teardownConnection(closeCode: 1000);
    });
    ref.listen(
      carouselFocusedKeyProvider,
      (_, key) => _onLocalFocusChanged(key),
    );
    ref.listen(activeEntriesProvider, (_, _) => _onLocalListChanged());
    return const LiveSessionState();
  }

  // ---- API pública -----------------------------------------------------

  /// Entra na sala [code]. Single-flight: repetir o mesmo código não abre
  /// outro socket; outro código sai da sala atual primeiro.
  Future<void> join(String code) async {
    if (state.code == code &&
        (state.phase == LivePhase.joining || state.isConnectedOrRetrying)) {
      if (state.phase == LivePhase.joining &&
          _connecting == null &&
          _conn == null) {
        // Handshake falhou enquanto pausado (§_shouldReconnectNow): nenhum
        // socket aberto, nada em voo, e `_scheduleReconnect` não armou timer
        // nenhum — repetir o `join` do mesmo código é quem religa. (Um
        // handshake que teve sucesso e só espera o `room` do servidor tem
        // `_conn` != null e continua single-flight.)
        return _connect();
      }
      return _connecting ?? Future.value();
    }
    if (state.code != null && state.code != code) await leave();
    _reconnectAttempt = 0;
    state = LiveSessionState(phase: LivePhase.joining, code: code);
    await _connect();
  }

  /// Sai da sala: fecha com 1000, limpa a projeção. Idempotente.
  Future<void> leave() async {
    _reconnectTimer?.cancel();
    _probeTimer?.cancel();
    _setDebounce?.cancel();
    _pendingStart = false;
    _teardownConnection(closeCode: 1000);
    _clearProjection();
    if (state.phase == LivePhase.idle) return;
    state = state.copyWith(phase: LivePhase.left, followingFocus: true);
  }

  /// Ciclo de vida da app: em `paused` nenhum timer religa; em `resumed`
  /// religa na hora (ou prova o socket com `ping`).
  void onAppLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _paused = true;
        _reconnectTimer?.cancel();
      case AppLifecycleState.resumed:
        _paused = false;
        if (_shouldReconnectNow()) {
          _reconnectNow();
        } else if (state.phase == LivePhase.connected) {
          _probe();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Evento de conectividade: online + `reconnecting`/`joining` parado → religa já.
  void onConnectivity(bool online) {
    if (online && !_paused && _shouldReconnectNow()) _reconnectNow();
  }

  /// Gestor: entra na própria sala e começa a transmitir a lista ativa.
  /// [code] é a sala do usuário (Task 14) e [playlistId] tem de ser a lista
  /// ativa (a UI chama `activate` antes).
  Future<void> startLive({
    required String code,
    required String playlistId,
  }) async {
    // O login já devia estar resolvido a esta altura (a UI só chega aqui
    // depois do boot) — mas sem esperar, um `hello` correndo antes do
    // `AsyncNotifier` sair de `AsyncLoading` sai sem `sessionToken` e o
    // gestor vira consumidor da própria sala em silêncio.
    try {
      await ref.read(authStateProvider.future);
    } on Object {
      // Login em erro: segue sem token — `_sessionTokenFor` manda `hello`
      // sem `sessionToken`.
    }
    if (!ref.mounted) return;
    ref.read(liveMyRoomCodeProvider.notifier).set(code);
    await ref
        .read(liveLeaderSessionPrefsProvider)
        .write(
          LiveLeaderSession(
            code: code,
            playlistId: playlistId,
            playlistName: ref.read(activePlaylistProvider)?.nome ?? '',
          ),
        );
    if (!ref.mounted) return;
    ref.invalidate(pendingLeaderSessionProvider);
    _pendingStart = true;
    if (state.code != code || !state.isConnectedOrRetrying) {
      await join(code);
      if (!ref.mounted) return;
    }
    final conn = _conn;
    if (conn != null) {
      conn.send(encodeLiveStart(liveSnapshotOfActiveList(ref)));
      _startSentGen = _gen;
    }
    state = state.copyWith(
      role: LiveRole.leader,
      roomStatus: LiveRoomStatus.live,
    );
  }

  /// Gestor: encerra a sessão para todos.
  Future<void> endLive() async {
    _setDebounce?.cancel();
    _pendingStart = false;
    _startSentGen = null;
    _conn?.send(encodeLiveEnd());
    await ref.read(liveLeaderSessionPrefsProvider).clear();
    if (!ref.mounted) return;
    ref.invalidate(pendingLeaderSessionProvider);
    _finish(LivePhase.ended, reason: LiveEndReason.leader);
  }

  /// Boot: retoma a sessão gravada. Se o DO já encerrou por inatividade, o
  /// `room{ended}` que volta limpa a pref (`_onRoomAsLeader`).
  Future<void> resumeLeader(LiveLeaderSession session) async {
    try {
      await ref.read(authStateProvider.future);
    } on Object {
      // Idem `startLive`.
    }
    if (!ref.mounted) return;
    ref.read(liveMyRoomCodeProvider.notifier).set(session.code);
    await join(session.code);
  }

  Future<void> discardLeaderSession() async {
    _pendingStart = false;
    _startSentGen = null;
    await ref.read(liveLeaderSessionPrefsProvider).clear();
    if (!ref.mounted) return;
    ref.invalidate(pendingLeaderSessionProvider);
  }

  /// `reconnecting` sempre religa; `joining` sem `_doConnect` em voo é um
  /// handshake que falhou enquanto pausado — `_scheduleReconnect` não armou
  /// timer nenhum (§ paused), então é `resumed`/conectividade quem tenta de
  /// novo.
  bool _shouldReconnectNow() =>
      state.phase == LivePhase.reconnecting ||
      (state.phase == LivePhase.joining &&
          _connecting == null &&
          _conn == null);

  // ---- conexão -----------------------------------------------------------

  Future<void> _connect() {
    final pending = _connecting;
    if (pending != null) return pending;
    final future = _doConnect();
    _connecting = future;
    return future.whenComplete(() {
      if (identical(_connecting, future)) _connecting = null;
    });
  }

  Future<void> _doConnect() async {
    final code = state.code;
    if (code == null) return;
    final gen = ++_gen;
    LiveConnection conn;
    try {
      conn = await ref
          .read(liveTransportProvider)
          .connect(ref.read(liveWsUriProvider)(code));
    } on Object catch (e) {
      if (gen != _gen || !ref.mounted) return;
      _log.warn('handshake da sala $code falhou', e);
      _onHandshakeFailure();
      return;
    }
    if (gen != _gen || !ref.mounted) {
      unawaited(conn.close());
      return;
    }
    _conn = conn;
    _sub = conn.messages.listen((text) => _onMessage(gen, text));
    unawaited(conn.done.then((d) => _onDisconnect(gen, d)));
    conn.send(
      encodeLiveHello(
        room: code,
        since: state.version,
        clientId: ref.read(liveClientIdProvider),
        sessionToken: _sessionTokenFor(code),
      ),
    );
  }

  /// Token só quando faz sentido ser gestor: logado **e** (a sala é a minha
  /// ou ainda não sei qual é a minha). Evita um lookup em D1 por consumidor.
  String? _sessionTokenFor(String code) {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return null;
    final mine = ref.read(liveMyRoomCodeProvider);
    return (mine == null || mine == code) ? user.sessionToken : null;
  }

  void _onHandshakeFailure() {
    final failures = state.handshakeFailures + 1;
    if (state.phase == LivePhase.joining &&
        failures >= kLiveMaxHandshakeFailures) {
      // Terminal: sem retry automático — uma `startLive`/`resumeLeader`
      // futura é que decide se tenta de novo, não uma pendência velha.
      _pendingStart = false;
      _startSentGen = null;
      state = state.copyWith(
        phase: LivePhase.unavailable,
        handshakeFailures: failures,
      );
      return;
    }
    state = state.copyWith(
      phase: state.phase == LivePhase.joining
          ? LivePhase.joining
          : LivePhase.reconnecting,
      handshakeFailures: failures,
    );
    _scheduleReconnect();
  }

  void _onDisconnect(int gen, LiveDisconnect disconnect) {
    if (gen != _gen || !ref.mounted) return;
    _sub = null;
    _conn = null;
    switch (state.phase) {
      case LivePhase.ended:
      case LivePhase.left:
      case LivePhase.unavailable:
      case LivePhase.notFound:
      case LivePhase.idle:
        return;
      case LivePhase.joining:
      case LivePhase.connected:
      case LivePhase.reconnecting:
        break;
    }
    switch (disconnect.code) {
      case kLiveCloseEnded:
        _finish(
          LivePhase.ended,
          reason: state.endReason ?? LiveEndReason.leader,
        );
      case kLiveCloseReplaced:
        _finish(LivePhase.ended, reason: LiveEndReason.replaced);
      case kLiveCloseRetired:
        _finish(LivePhase.ended, reason: LiveEndReason.retired);
      case kLiveCloseNotFound:
        _finish(LivePhase.notFound);
      default:
        state = state.copyWith(phase: LivePhase.reconnecting);
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_paused) return;
    final delay = ref
        .read(liveReconnectPolicyProvider)
        .delayFor(_reconnectAttempt++);
    _reconnectTimer = Timer(delay, () {
      if (!ref.mounted) return;
      unawaited(_connect());
    });
  }

  void _reconnectNow() {
    _reconnectTimer?.cancel();
    unawaited(_connect());
  }

  /// `ping` → o DO responde `pong` na borda; sem resposta em 5 s o socket
  /// está morto (iOS mata em segundo plano sem close frame).
  void _probe() {
    final conn = _conn;
    if (conn == null) return;
    // Presa à conexão que recebeu o `ping`: uma geração nova (reconexão
    // no meio da espera) invalida esta prova — não pode derrubar a conexão
    // saudável que já a substituiu.
    final gen = _gen;
    conn.send('ping');
    _probeTimer?.cancel();
    _probeTimer = Timer(kLivePingProbeTimeout, () {
      if (gen != _gen || !ref.mounted || state.phase != LivePhase.connected) {
        return;
      }
      _teardownConnection(closeCode: 1001);
      state = state.copyWith(phase: LivePhase.reconnecting);
      // Em segundo plano `_reconnectNow` fica para o próximo `resumed`
      // (spec: nunca religar em `paused`/`detached`).
      if (!_paused) _reconnectNow();
    });
  }

  void _teardownConnection({required int closeCode}) {
    _gen++;
    // Uma geração nova invalida qualquer `_doConnect` em voo: sem isto, o
    // `join` seguinte a um `leave()` no meio do handshake devolvia o
    // `Future` velho (via `_connect`) e nada religava quando ele terminasse
    // (fechando a própria conexão pela checagem de geração, sem reconectar).
    _connecting = null;
    unawaited(_sub?.cancel());
    _sub = null;
    final conn = _conn;
    _conn = null;
    if (conn != null) unawaited(conn.close(code: closeCode));
  }

  void _finish(LivePhase phase, {LiveEndReason? reason}) {
    _reconnectTimer?.cancel();
    _setDebounce?.cancel();
    _teardownConnection(closeCode: 1000);
    _clearProjection();
    _pendingStart = false;
    _startSentGen = null;
    if (state.role == LiveRole.leader &&
        (reason == LiveEndReason.replaced ||
            reason == LiveEndReason.inactivity ||
            reason == LiveEndReason.retired)) {
      // Outro aparelho assumiu a sala, ou o DO encerrou por inatividade/
      // regeneração de link: a sessão gravada já não vale.
      unawaited(ref.read(liveLeaderSessionPrefsProvider).clear());
      ref.invalidate(pendingLeaderSessionProvider);
    }
    state = state.copyWith(
      phase: phase,
      endReason: reason,
      followingFocus: true,
    );
  }

  // ---- frames ------------------------------------------------------------

  void _onMessage(int gen, String text) {
    if (gen != _gen || !ref.mounted) return;
    if (text == 'pong') {
      _probeTimer?.cancel();
      return;
    }
    final frame = decodeLiveServerFrame(text);
    if (frame == null) return;
    if (frame is LiveErrorFrame && frame.code == 'not_found') {
      _finish(LivePhase.notFound);
      return;
    }
    if (frame.room != state.code) return;

    switch (frame) {
      case LiveRoomFrame():
        _onRoom(frame);
      case LiveSnapshotFrame():
        if (frame.version <= state.version) return;
        state = state.copyWith(
          version: frame.version,
          snapshot: frame.snapshot,
          viewers: frame.viewers,
        );
        _syncProjection();
      case LivePresenceFrame():
        state = state.copyWith(
          leaderPresent: frame.leaderPresent,
          viewers: frame.viewers,
        );
      case LiveAckFrame():
        state = state.copyWith(version: frame.version, viewers: frame.viewers);
      case LiveEndedFrame():
        // O DO fecha o socket logo a seguir; `_onDisconnect` respeita `ended`.
        _finish(LivePhase.ended, reason: frame.reason);
      case LiveErrorFrame():
        _log.warn('sala ${state.code}: error ${frame.code}');
        state = state.copyWith(lastError: frame.code);
    }
  }

  void _onRoom(LiveRoomFrame frame) {
    _reconnectAttempt = 0;
    final keepSnapshot =
        frame.version <= state.version && state.snapshot != null;
    state = state.copyWith(
      phase: LivePhase.connected,
      role: frame.role,
      roomStatus: frame.status,
      ownerName: frame.ownerName,
      version: keepSnapshot ? state.version : frame.version,
      snapshot: keepSnapshot ? state.snapshot : frame.snapshot,
      leaderPresent: frame.leaderPresent,
      viewers: frame.viewers,
      handshakeFailures: 0,
      clearLastError: true,
    );
    _syncProjection();
    _onRoomAsLeader(frame);
  }

  // ---- projeção e foco (consumidor) -----------------------------------------

  void _syncProjection() {
    final snapshot = state.snapshot;
    if (!state.isFollowing || snapshot == null) {
      _clearProjection();
      return;
    }
    ref
        .read(liveProjectionProvider.notifier)
        .set(
          LiveProjection(
            ownerName: state.ownerName,
            playlistId: snapshot.playlistId,
            name: snapshot.name,
            entries: snapshot.entries,
          ),
        );
    final focus = snapshot.focusKey;
    if (focus != _leaderFocusKey) {
      _leaderFocusKey = focus;
      if (state.followingFocus && focus != null) {
        unawaited(_applyLeaderFocus(focus));
      }
    }
  }

  void _clearProjection() {
    _leaderFocusKey = null;
    if (ref.read(liveProjectionProvider) != null) {
      ref.read(liveProjectionProvider.notifier).clear();
    }
  }

  Future<void> _applyLeaderFocus(String key) async {
    final items = ref.read(carouselItemsProvider);
    final index = items.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _applyingFocus = true;
    try {
      if (items[index].isAudio) {
        ref.read(carouselFocusedIndexProvider.notifier).focusKey(key);
        return;
      }
      final location = await ref.read(liveFocusResolverProvider)(key);
      // Depois do `await` o gestor pode já ter focado outra coisa — quem
      // resolveu por último é quem navega.
      if (location == null ||
          !ref.mounted ||
          !state.isFollowing ||
          _leaderFocusKey != key) {
        return;
      }
      ref.read(liveNavigatorProvider)(location);
    } on Object catch (e, stack) {
      _log.error('não foi possível seguir o foco $key', e, stack);
    } finally {
      _applyingFocus = false;
    }
  }

  /// D3: o consumidor desviou e quer voltar para onde o gestor está.
  void returnToLeader() {
    if (!state.isFollowing) return;
    state = state.copyWith(followingFocus: true);
    final focus = _leaderFocusKey;
    if (focus != null) unawaited(_applyLeaderFocus(focus));
  }

  void _onLocalFocusChanged(String? key) {
    if (state.isFollowing) {
      if (_applyingFocus) return;
      if (key != null && key != _leaderFocusKey && state.followingFocus) {
        state = state.copyWith(followingFocus: false);
      }
      return;
    }
    _scheduleLeaderSet();
  }

  void _onLocalListChanged() => _scheduleLeaderSet();

  void _scheduleLeaderSet() {
    if (!state.isLeading || _conn == null) return;
    _setDebounce?.cancel();
    _setDebounce = Timer(kLiveLeaderSetDebounce, () {
      if (!ref.mounted || !state.isLeading) return;
      _conn?.send(encodeLiveSet(liveSnapshotOfActiveList(ref)));
    });
  }

  void _onRoomAsLeader(LiveRoomFrame frame) {
    if (frame.role != LiveRole.leader) return;
    if (frame.status == LiveRoomStatus.live) {
      _pendingStart = false;
      // Eco do nosso próprio `start` nesta mesma conexão (mesmo `_gen`):
      // RoomCore responde ao `hello` com `room{idle}` antes de processar o
      // `start` já enfileirado atrás dele — o `room{live}` seguinte não é
      // uma reconexão, não precisa de `set` nenhum.
      final isEchoOfOwnStart = _startSentGen == _gen;
      _startSentGen = null;
      if (isEchoOfOwnStart) return;
      // Religou (ou retomou) numa conexão nova: o que está no aparelho
      // vence o que o DO tem.
      _conn?.send(encodeLiveSet(liveSnapshotOfActiveList(ref)));
      return;
    }
    if (_pendingStart && _startSentGen != _gen) {
      // O `start` ainda não foi mandado nesta conexão (primeiro handshake
      // falhou antes de `startLive` conseguir mandar, ou é uma reconexão
      // nova): manda agora.
      _conn?.send(encodeLiveStart(liveSnapshotOfActiveList(ref)));
      _startSentGen = _gen;
      state = state.copyWith(roomStatus: LiveRoomStatus.live);
      return;
    }
    if (_pendingStart) {
      // `start` já foi mandado nesta conexão — este `room{idle}` é só o eco
      // do `hello` que chega antes dele; nada a reenviar.
      return;
    }
    // Sala idle/ended sem pendência: a sessão gravada já não vale.
    unawaited(ref.read(liveLeaderSessionPrefsProvider).clear());
    ref.invalidate(pendingLeaderSessionProvider);
  }
}

final liveSessionProvider =
    NotifierProvider<LiveSessionController, LiveSessionState>(
      LiveSessionController.new,
    );
