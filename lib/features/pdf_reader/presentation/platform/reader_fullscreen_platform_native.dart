import 'package:flutter/services.dart';

import 'reader_fullscreen_platform.dart';

ReaderFullscreenPlatform createReaderFullscreenPlatformImpl() =>
    _NativeReaderFullscreenPlatform();

/// Nativo: modo imersivo via [SystemChrome] — sem Fullscreen API de SO, e
/// portanto sem evento equivalente ao `fullscreenchange` da web.
class _NativeReaderFullscreenPlatform implements ReaderFullscreenPlatform {
  @override
  Future<void> enter() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Future<void> exit() {
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Stream<bool> get changes => const Stream.empty();
}
