import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' hide AudioTrack;

import '../domain/entities/audio_track.dart';
import 'audio_media_session_stub.dart';

/// Media Session + Audio Session (Safari) + reclaim ao voltar do background.
class AudioMediaSessionController {
  AudioMediaSessionController() {
    _visibilityListener = ((Event _) {
      if (document.visibilityState != 'visible') return;
      if (!_wasPlayingBeforeHide) return;
      _wasPlayingBeforeHide = false;
      unawaited(_callbacks?.onPlay());
    }).toJS;
    document.addEventListener('visibilitychange', _visibilityListener);
  }

  AudioMediaSessionCallbacks? _callbacks;
  JSFunction? _visibilityListener;
  bool _wasPlayingBeforeHide = false;

  void attach({required AudioMediaSessionCallbacks callbacks}) {
    _callbacks = callbacks;
    _configureAudioSessionType();
    _registerHandlers();
  }

  void detach() {
    _callbacks = null;
    final session = window.navigator.mediaSession;
    for (final action in _actions) {
      session.setActionHandler(action, null);
    }
    session.metadata = null;
  }

  void updateTrack(AudioTrack? track) {
    if (track == null) {
      window.navigator.mediaSession.metadata = null;
      return;
    }
    window.navigator.mediaSession.metadata = MediaMetadata(
      MediaMetadataInit(
        title: track.categoria.isNotEmpty ? track.categoria : track.nome,
        artist: track.author.isNotEmpty
            ? track.author
            : (track.numero.isNotEmpty ? track.numero : 'PLPCG'),
        album: track.nome,
      ),
    );
  }

  void updatePlaybackState({required bool playing}) {
    window.navigator.mediaSession.playbackState = playing
        ? 'playing'
        : 'paused';
    if (!playing && document.visibilityState != 'visible') {
      _wasPlayingBeforeHide = true;
    }
  }

  void updatePosition({
    required Duration position,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) return;
    window.navigator.mediaSession.setPositionState(
      MediaPositionState(
        duration: duration.inMilliseconds / 1000.0,
        playbackRate: 1,
        position: position.inMilliseconds / 1000.0,
      ),
    );
  }

  static const _actions = [
    'play',
    'pause',
    'previoustrack',
    'nexttrack',
    'seekto',
  ];

  void _registerHandlers() {
    final session = window.navigator.mediaSession;
    session.setActionHandler(
      'play',
      ((JSObject _) {
        unawaited(_callbacks?.onPlay());
      }).toJS,
    );
    session.setActionHandler(
      'pause',
      ((JSObject _) {
        unawaited(_callbacks?.onPause());
      }).toJS,
    );
    session.setActionHandler(
      'previoustrack',
      ((JSObject _) {
        unawaited(_callbacks?.onPrevious());
      }).toJS,
    );
    session.setActionHandler(
      'nexttrack',
      ((JSObject _) {
        unawaited(_callbacks?.onNext());
      }).toJS,
    );
    session.setActionHandler(
      'seekto',
      ((JSObject details) {
        final seekRaw = details['seekTime'];
        if (seekRaw == null || !seekRaw.isA<JSNumber>()) return;
        final seekTime = (seekRaw as JSNumber).toDartDouble;
        if (!seekTime.isFinite) return;
        unawaited(
          _callbacks?.onSeek(Duration(milliseconds: (seekTime * 1000).round())),
        );
      }).toJS,
    );
  }

  void _configureAudioSessionType() {
    try {
      final nav = window.navigator as JSObject;
      final session = nav['audioSession'];
      if (session != null && session.isA<JSObject>()) {
        (session as JSObject)['type'] = 'playback'.toJS;
      }
    } on Object {
      // Safari antigo / outros browsers — opcional.
    }
  }
}

AudioMediaSessionController createAudioMediaSessionController() {
  return AudioMediaSessionController();
}
