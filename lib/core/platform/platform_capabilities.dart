import 'platform_capabilities_native.dart'
    if (dart.library.js_interop) 'platform_capabilities_web.dart';

/// Capacidades que variam entre web e nativo.
///
/// Reúne num só lugar as diferenças de plataforma que antes vazavam como
/// `kIsWeb` espalhado pela presentation (spec §E.3, exploração §E13):
/// suporte a áudio em background, necessidade de gesto do usuário para
/// desbloquear áudio, salvamento de arquivo local e a Fullscreen API do
/// navegador.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isWeb,
    required this.supportsBackgroundAudio,
    required this.needsUserGestureForAudio,
    required this.supportsFileSave,
    required this.supportsFullscreenApi,
  });

  final bool isWeb;
  final bool supportsBackgroundAudio;
  final bool needsUserGestureForAudio;
  final bool supportsFileSave;
  final bool supportsFullscreenApi;

  static const web = PlatformCapabilities(
    isWeb: true,
    supportsBackgroundAudio: false,
    needsUserGestureForAudio: true,
    supportsFileSave: false,
    supportsFullscreenApi: true,
  );

  static const native = PlatformCapabilities(
    isWeb: false,
    supportsBackgroundAudio: true,
    needsUserGestureForAudio: false,
    supportsFileSave: true,
    supportsFullscreenApi: false,
  );
}

/// Capacidades da plataforma em vigor (conditional import): nativo devolve
/// [PlatformCapabilities.native], web devolve [PlatformCapabilities.web].
PlatformCapabilities currentPlatformCapabilities() =>
    currentPlatformCapabilitiesImpl();
