import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../data/providers/chord_providers.dart';
import '../../domain/entities/chord_material.dart';

/// Cifras do louvor [groupId] que têm arquivo publicado e com letra.
///
/// Uma requisição por cifra (tipicamente 1–2 por louvor), em paralelo. O
/// resultado alimenta o cache de [chordSongProvider], então abrir o sheet
/// pré-aquece o leitor: ao tocar na cifra, o conteúdo já está em memória.
///
/// Lê de [coldigomChordMaterialsCacheProvider] em vez de receber a lista por
/// parâmetro porque chave de `family` precisa de `==` estável, e `List` em Dart
/// usa identidade.
final availableChordsProvider = FutureProvider.autoDispose
    .family<List<ChordMaterial>, String>((ref, groupId) async {
      final chords =
          ref
              .watch(coldigomChordMaterialsCacheProvider)
              .values
              .where((chord) => chord.groupId == groupId)
              .toList()
            ..sort((a, b) => a.categoria.compareTo(b.categoria));

      if (chords.isEmpty) return const [];

      final songs = await Future.wait([
        for (final chord in chords)
          ref.watch(chordSongProvider(chord.r2Key).future),
      ]);

      return [
        for (var i = 0; i < chords.length; i++)
          if (songs[i] != null) chords[i],
      ];
    });
