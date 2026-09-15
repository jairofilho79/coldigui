import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../../coldigom/data/coldigom_praise_cache_warmup.dart';
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

/// Aquece os caches Coldigom dos praises da lista do gestor
/// (`warmupColdigomPraiseIds`: pula o que já está em cache, nunca lança).
/// É o que permite ao consumidor escolher o **seu** material do louvor
/// antes de o leitor abrir. Sobrescrito em teste.
final liveWarmupProvider =
    Provider<Future<void> Function(Iterable<String> praiseIds)>((ref) {
      return (praiseIds) => warmupColdigomPraiseIds(ref, praiseIds);
    });
