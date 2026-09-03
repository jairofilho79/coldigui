import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/chord_reader_url_builder.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/chord_material.dart';

/// Rota `/cifra` de [materialId] quando ele é cifra e está em [chordCache].
///
/// `null` quando o id não é cifra **ou** quando o cache está frio — cabe a quem
/// chama decidir o que fazer (seguir para o caminho de PDF, logar, avisar).
/// Ponto único do desvio de cifra: playlist e carousel/leitor compartilham o
/// mesmo espaço de ids, então o id só se revela cifra ao ser decodificado.
String? chordReaderLocationFor(
  String materialId,
  Map<String, ChordMaterial> chordCache,
) {
  if (materialIdKindOf(materialId) != MaterialKind.chord) return null;
  final chord = chordCache[materialId];
  if (chord == null) return null;
  return buildChordReaderLocation(
    chordId: chord.chordId,
    titulo: chord.nome,
    subtitulo: chord.numero,
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
