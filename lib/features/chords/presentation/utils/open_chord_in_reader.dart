import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/chord_reader_url_builder.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/chord_material.dart';

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
