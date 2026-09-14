import '../../domain/entities/live_snapshot.dart';

/// Fases do controller (spec §6.1; `live` da spec = [connected]).
///
/// [unavailable] e [notFound] são terminais: sem retry automático.
enum LivePhase {
  idle,
  joining,
  connected,
  reconnecting,
  ended,
  left,
  unavailable,
  notFound,
}

final class LiveSessionState {
  const LiveSessionState({
    this.phase = LivePhase.idle,
    this.code,
    this.role,
    this.roomStatus,
    this.ownerName = '',
    this.version = 0,
    this.snapshot,
    this.leaderPresent = false,
    this.viewers = 0,
    this.followingFocus = true,
    this.endReason,
    this.handshakeFailures = 0,
    this.lastError,
  });

  final LivePhase phase;
  final String? code;
  final LiveRole? role;
  final LiveRoomStatus? roomStatus;
  final String ownerName;
  final int version;

  /// Último snapshot recebido — sobrevive a [LivePhase.ended] para «Guardar cópia».
  final LiveSnapshot? snapshot;
  final bool leaderPresent;
  final int viewers;

  /// D3: `false` depois de o consumidor navegar por conta própria.
  final bool followingFocus;
  final LiveEndReason? endReason;
  final int handshakeFailures;

  /// Último `error{code}` do DO relevante para a UI (`not_leader`, `unauthorized`).
  final String? lastError;

  bool get isConnectedOrRetrying =>
      phase == LivePhase.connected || phase == LivePhase.reconnecting;

  /// Consumidor numa sala `live`: a lista ativa é a projeção.
  bool get isFollowing =>
      role == LiveRole.consumer &&
      isConnectedOrRetrying &&
      roomStatus == LiveRoomStatus.live;

  /// Gestor numa sala `live`, conectado.
  bool get isLeading =>
      role == LiveRole.leader &&
      isConnectedOrRetrying &&
      roomStatus == LiveRoomStatus.live;

  LiveSessionState copyWith({
    LivePhase? phase,
    String? code,
    LiveRole? role,
    LiveRoomStatus? roomStatus,
    String? ownerName,
    int? version,
    LiveSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? leaderPresent,
    int? viewers,
    bool? followingFocus,
    LiveEndReason? endReason,
    bool clearEndReason = false,
    int? handshakeFailures,
    String? lastError,
    bool clearLastError = false,
  }) => LiveSessionState(
    phase: phase ?? this.phase,
    code: code ?? this.code,
    role: role ?? this.role,
    roomStatus: roomStatus ?? this.roomStatus,
    ownerName: ownerName ?? this.ownerName,
    version: version ?? this.version,
    snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
    leaderPresent: leaderPresent ?? this.leaderPresent,
    viewers: viewers ?? this.viewers,
    followingFocus: followingFocus ?? this.followingFocus,
    endReason: clearEndReason ? null : (endReason ?? this.endReason),
    handshakeFailures: handshakeFailures ?? this.handshakeFailures,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
  );
}
