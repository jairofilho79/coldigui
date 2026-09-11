import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_capabilities.dart';

/// Capacidades da plataforma em vigor — overridável nos testes que precisam
/// simular a web (Tarefa 17, `standardTestOverrides`).
final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (_) => currentPlatformCapabilities(),
);
