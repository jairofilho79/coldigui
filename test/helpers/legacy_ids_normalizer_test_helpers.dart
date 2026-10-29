import 'package:coldigui/features/catalog/domain/usecases/normalize_legacy_material_ids.dart';
import 'package:coldigui/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';
import 'package:flutter_riverpod/misc.dart';

/// Normalizador que só conta os pedidos: não monta store nenhuma, não
/// pergunta ao crosswalk e não escuta a conectividade (spec fim-fonte-plpcg
/// §6.2).
class CountingLegacyMaterialIdsNormalizer extends LegacyMaterialIdsNormalizer {
  var runs = 0;

  @override
  LegacyIdNormalizationOutcome? build() => null;

  @override
  Future<LegacyIdNormalizationOutcome> run() async {
    runs++;
    return LegacyIdNormalizationOutcome.nothingToDo;
  }
}

/// Override para quem hidrata a sessão de playlists ou corre a sync delas
/// sem querer a normalização de verdade (nem rede, nem stores).
///
/// Passe [normalizer] para contar os pedidos.
Override noOpLegacyMaterialIdsNormalizerOverride([
  CountingLegacyMaterialIdsNormalizer? normalizer,
]) => legacyMaterialIdsNormalizerProvider.overrideWith(
  () => normalizer ?? CountingLegacyMaterialIdsNormalizer(),
);
