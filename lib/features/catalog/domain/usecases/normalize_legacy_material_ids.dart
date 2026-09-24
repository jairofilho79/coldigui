import 'package:flutter/foundation.dart';

import '../legacy_ids/legacy_id_store.dart';

/// Crosswalk legado → coldigom (C9: `ColdigomRemoteDatasource.resolveLegacyPdfIds`).
typedef LegacyPdfIdResolver = Future<Map<String, String>> Function(
  Iterable<String> legacyPdfIds,
);

/// Desfecho de uma rodada de [NormalizeLegacyMaterialIds].
final class LegacyIdNormalizationOutcome {
  const LegacyIdNormalizationOutcome({
    this.legacy = 0,
    this.resolved = 0,
    this.rewritten = 0,
    this.pending = false,
    this.deferred = false,
  });

  static const nothingToDo = LegacyIdNormalizationOutcome();

  /// Ids legados distintos encontrados.
  final int legacy;

  /// Quantos o crosswalk conhecia.
  final int resolved;

  /// Registos reescritos, somados de todas as stores.
  final int rewritten;

  /// Crosswalk indisponível: nada foi escrito, tenta no próximo gatilho.
  final bool pending;

  /// Alguma store adiou a escrita ([LegacyIdStoreDeferred]) — as outras
  /// reescreveram. Para agendar conta como pendente, mas o gatilho é o
  /// recurso soltar (o lock de manutenção offline), não o próximo evento.
  final bool deferred;

  /// Legados que o crosswalk não conhece (0 enquanto [pending]).
  int get unknown => pending ? 0 : legacy - resolved;
}

/// Normaliza **uma vez** os ids legados guardados no aparelho (spec §6.2).
///
/// Recolhe os ids de todas as [stores], pergunta ao crosswalk numa só
/// chamada e entrega a mesma [LegacyIdResolution] a cada store que tinha
/// legados. Sem legados não há rede nem escrita; [resolve] a falhar deixa
/// tudo como está ([LegacyIdNormalizationOutcome.pending]). Uma store que
/// falha não trava as outras; uma que adia marca
/// [LegacyIdNormalizationOutcome.deferred]. Idempotente — sem flag de «feito», e por isso
/// também apanha ids legados que um cliente antigo volte a empurrar.
class NormalizeLegacyMaterialIds {
  const NormalizeLegacyMaterialIds({
    required this.stores,
    required this.resolve,
  });

  final List<LegacyIdStore> stores;
  final LegacyPdfIdResolver resolve;

  Future<LegacyIdNormalizationOutcome> call() async {
    final withLegacy = <LegacyIdStore>[];
    final all = <String>{};
    for (final store in stores) {
      try {
        final ids = await store.collectLegacyIds();
        if (ids.isEmpty) continue;
        withLegacy.add(store);
        all.addAll(ids);
      } on Object catch (e) {
        debugPrint('[legacy-ids] ${store.name}: coleta falhou: $e');
      }
    }
    if (all.isEmpty) return LegacyIdNormalizationOutcome.nothingToDo;

    final Map<String, String> answer;
    try {
      answer = await resolve(all);
    } on Object catch (e) {
      debugPrint('[legacy-ids] ${all.length} ids legados pendentes: $e');
      return LegacyIdNormalizationOutcome(legacy: all.length, pending: true);
    }

    final resolution = LegacyIdResolution(
      queried: all,
      resolved: {
        for (final MapEntry(:key, :value) in answer.entries)
          if (all.contains(key)) key: value,
      },
    );
    var rewritten = 0;
    var deferred = false;
    for (final store in withLegacy) {
      try {
        rewritten += await store.rewrite(resolution);
      } on LegacyIdStoreDeferred catch (e) {
        deferred = true;
        debugPrint('[legacy-ids] ${store.name}: adiada (${e.reason})');
      } on Object catch (e) {
        debugPrint('[legacy-ids] ${store.name}: reescrita falhou: $e');
      }
    }
    final resolved = resolution.resolved.length;
    // O log conta os casos: é por ele que se decide remover o normalizador
    // (spec §12, follow-up).
    debugPrint(
      '[legacy-ids] ${all.length} legados: $resolved resolvidos, '
      '${all.length - resolved} desconhecidos, $rewritten registos reescritos',
    );
    return LegacyIdNormalizationOutcome(
      legacy: all.length,
      resolved: resolved,
      rewritten: rewritten,
      deferred: deferred,
    );
  }
}
