import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/chord_reader_url_builder.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/chord_material.dart';

/// Resultado de decodificar um id de material como cifra.
///
/// Separa os dois casos que antes eram um `null` só: "não é cifra" ([isChord]
/// falso, siga pelo caminho de PDF) e "é cifra mas o cache está frio"
/// ([isChord] verdadeiro com [location] nula, não há para onde navegar).
class ChordRoute {
  const ChordRoute({required this.isChord, this.location});

  /// `true` quando o id decodifica para um material `.chord`.
  final bool isChord;

  /// Rota `/cifra`; `null` quando a cifra não está no cache.
  final String? location;
}

/// Classifica [materialId] como cifra e resolve a rota `/cifra` pelo cache.
///
/// Ponto único do desvio de cifra por rota: playlist e carousel/leitor
/// compartilham o mesmo espaço de ids, então o id só se revela cifra ao ser
/// decodificado.
ChordRoute chordRouteFor(
  String materialId,
  Map<String, ChordMaterial> chordCache,
) {
  if (materialIdKindOf(materialId) != MaterialKind.chord) {
    return const ChordRoute(isChord: false);
  }
  final chord = chordCache[materialId];
  if (chord == null) return const ChordRoute(isChord: true);
  return ChordRoute(
    isChord: true,
    location: buildChordReaderLocation(
      chordId: chord.chordId,
      titulo: chord.nome,
      subtitulo: chord.numero,
    ),
  );
}

/// Abre [chord] em `/cifra`, entrando na lista ativa como o PDF faz.
///
/// Espelha `openLouvorInReader`, sem a etapa de resolve local: o `.chord` é
/// buscado pelo `chordSongProvider`, que já está aquecido pelo sheet.
Future<void> openChordInReader({
  required WidgetRef ref,
  required BuildContext context,
  required ChordMaterial chord,
}) async {
  ref.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([chord]);

  await ref
      .read(playlistsProvider.notifier)
      .addLouvorToActivePlaylist(chord.chordId);

  if (!context.mounted) return;

  unawaited(
    context.push(
      buildChordReaderLocation(
        chordId: chord.chordId,
        titulo: chord.nome,
        subtitulo: chord.numero,
      ),
    ),
  );
}
