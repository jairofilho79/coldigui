import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import '../../domain/live_reconnect_policy.dart';
import '../../domain/ports/live_transport.dart';
import '../live_transport_ws.dart';

const kLiveClientIdPrefsKey = 'live_client_id';
const kLiveMyRoomCodePrefsKey = 'live_my_room_code';

final liveTransportProvider = Provider<LiveTransport>(
  (ref) => const WebSocketLiveTransport(),
);

/// `wss://<host de PLPCG_API_BASE_URL>/api/live/<code>/ws`.
///
/// Monta o `Uri` do zero — `Uri.replace(query: null)` **preserva** a query
/// original (`null` significa "sem mudança", não "remover"), e
/// `PLPCG_API_BASE_URL` não devia ter query nenhuma na sala ao vivo.
final liveWsUriProvider = Provider<Uri Function(String code)>((ref) {
  return (code) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return Uri(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/api/live/$code/ws',
    );
  };
});

/// Identidade anónima do aparelho (spec D2) — gerada uma vez, persistida.
final liveClientIdProvider = Provider<String>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final existing = prefs.getString(kLiveClientIdPrefsKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final random = Random.secure();
  final id = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  prefs.setString(kLiveClientIdPrefsKey, id);
  return id;
});

final liveReconnectPolicyProvider = Provider<LiveReconnectPolicy>(
  (ref) => LiveReconnectPolicy(),
);

/// Código da **minha** sala, cacheado depois do `POST /api/live/room` — é o
/// que diz ao controller quando mandar o token no `hello`.
class LiveMyRoomCodeNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(sharedPreferencesProvider).getString(kLiveMyRoomCodePrefsKey);

  void set(String? code) {
    state = code;
    final prefs = ref.read(sharedPreferencesProvider);
    if (code == null) {
      prefs.remove(kLiveMyRoomCodePrefsKey);
    } else {
      prefs.setString(kLiveMyRoomCodePrefsKey, code);
    }
  }
}

final liveMyRoomCodeProvider =
    NotifierProvider<LiveMyRoomCodeNotifier, String?>(
      LiveMyRoomCodeNotifier.new,
    );

/// Resolve a rota do leitor para a chave focada pelo gestor (foca a chip como
/// efeito). Sobrescrito em teste — o real precisa de catálogo e PDF.
final liveFocusResolverProvider =
    Provider<Future<String?> Function(String key)>((ref) {
      return (key) => ref
          .read(readerCarouselActionsProvider.notifier)
          .navigateToKey(key: key);
    });

/// Navega para a rota resolvida. Sobrescrito em teste.
final liveNavigatorProvider = Provider<void Function(String location)>((ref) {
  return (location) => ref.read(appRouterProvider).go(location);
});
