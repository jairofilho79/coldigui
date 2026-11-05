import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/reading_navigation.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/score_reader_url_builder.dart';
import '../../domain/entities/score_material.dart';

/// Resultado de decodificar um id de material como partitura editável.
///
/// [isScore] falso = siga pelo caminho de PDF; verdadeiro com [location] nula
/// = é partitura, mas o cache está frio (não há para onde navegar).
class ScoreRoute {
  const ScoreRoute({required this.isScore, this.location});

  final bool isScore;
  final String? location;
}

/// Classifica [materialId] como partitura e resolve a rota `/partitura`.
///
/// Diferente de gestos, o cache frio ainda navega: a tela só precisa do id
/// (o `r2Key` sai dele), então o título é o único dado que se perde.
ScoreRoute scoreRouteFor(
  String materialId,
  Map<String, ScoreMaterial> scoreCache,
) {
  if (materialIdKindOf(materialId) != MaterialKind.score) {
    return const ScoreRoute(isScore: false);
  }
  final score = scoreCache[materialId];
  return ScoreRoute(
    isScore: true,
    location: buildScoreReaderLocation(
      scoreId: materialId,
      titulo: score?.nome,
      subtitulo: score?.numero,
    ),
  );
}

/// Abre [score] em `/partitura` sem alterar a lista ativa.
///
/// A partitura é buscada pelo `scoreDocumentProvider` na própria tela.
Future<void> openScoreInReader({
  required WidgetRef ref,
  required BuildContext context,
  required ScoreMaterial score,
}) async {
  openReadingLocation(
    context,
    buildScoreReaderLocation(
      scoreId: score.scoreId,
      titulo: score.nome,
      subtitulo: score.numero,
    ),
  );
}
