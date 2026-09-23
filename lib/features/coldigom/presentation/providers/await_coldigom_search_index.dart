import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/search/coldigom_search_index.dart';
import 'coldigom_catalog_providers.dart';

final _log = AppLogger.of('coldigom');

/// Prazo que o import de um link `?p=` espera o catálogo local (spec
/// fim-fonte-plpcg §4.3/§8). Cobre o arranque a frio, que baixa o dump
/// (~950 KB) e hidrata aos bocados; esgotado, o link cai em «link inválido».
const sharedPlaylistCatalogTimeout = Duration(seconds: 20);

/// O índice do catálogo **com conteúdo**, esperando até [timeout].
///
/// Já hidratado: devolve na hora, sem rede. Vazio: escuta
/// [coldigomSearchIndexProvider] (a escuta também acorda a hidratação) e pede
/// [ColdigomCatalogSyncNotifier.sync] — deduplicado; cobre o aparelho que
/// nunca sincronizou e o caminho sem Isar. O primeiro índice não vazio
/// responde.
///
/// Devolve [ColdigomSearchIndex.empty] — e o import vira «link inválido» —
/// no prazo esgotado ou, antes dele, quando o catálogo desiste:
/// [catalogIndexStatusProvider] em [CatalogIndexStatus.failed] **depois** de
/// o sync pedido aqui terminar. Nem o desfecho do sync nem o status bastam
/// sozinhos: um [ColdigomCatalogSyncFailed] com a hidratação do Isar ainda em
/// curso (arranque a frio offline, com catálogo local) não é desistência — o
/// status fica `loading` e o índice ainda chega; e um `failed` que já estava
/// lá antes (sync do boot sem rede) não conta, porque o sync pedido aqui é
/// uma nova tentativa.
///
/// [ref] tem de ser de um provider que não reconstrói durante a espera (ex.:
/// um `Provider` sem `watch`); as escutas são fechadas no fim.
Future<ColdigomSearchIndex> awaitColdigomSearchIndex(
  Ref ref, {
  Duration timeout = sharedPlaylistCatalogTimeout,
}) async {
  final current = ref.read(coldigomSearchIndexProvider);
  if (!current.isEmpty) return current;

  final outcome = Completer<ColdigomSearchIndex>();
  var syncSettled = false;

  void giveUpIfCatalogFailed(CatalogIndexStatus status) {
    if (!syncSettled || status != CatalogIndexStatus.failed) return;
    if (outcome.isCompleted) return;
    _log.warn('catálogo vazio e o sync falhou — import sem índice');
    outcome.complete(ColdigomSearchIndex.empty);
  }

  final indexSubscription = ref.listen<ColdigomSearchIndex>(
    coldigomSearchIndexProvider,
    (_, next) {
      if (!next.isEmpty && !outcome.isCompleted) outcome.complete(next);
    },
    fireImmediately: true,
  );
  final statusSubscription = ref.listen<CatalogIndexStatus>(
    catalogIndexStatusProvider,
    (_, next) => giveUpIfCatalogFailed(next),
  );
  final timer = Timer(timeout, () {
    if (outcome.isCompleted) return;
    _log.warn(
      'catálogo ainda vazio após ${timeout.inMilliseconds} ms — '
      'import sem índice',
    );
    outcome.complete(ColdigomSearchIndex.empty);
  });

  final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
  unawaited(
    syncNotifier
        .sync()
        .then<void>(
          (_) {},
          onError: (Object e) =>
              _log.warn('sync do catálogo para o import falhou', e),
        )
        .whenComplete(() {
          if (outcome.isCompleted || !ref.mounted) return;
          syncSettled = true;
          giveUpIfCatalogFailed(ref.read(catalogIndexStatusProvider));
        }),
  );

  try {
    return await outcome.future;
  } finally {
    timer.cancel();
    indexSubscription.close();
    statusSubscription.close();
  }
}
