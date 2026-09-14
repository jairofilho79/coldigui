import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';

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
