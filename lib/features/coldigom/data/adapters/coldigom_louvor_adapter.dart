import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/utils/youtube_url.dart';

import '../models/praise_dto.dart';

/// Converte louvores coldigom em entidades [Louvor] / [AudioTrack] / YouTube.
abstract final class ColdigomLouvorAdapter {
  /// Metadados do praise para o sheet Coldigom (tom, autor, ritmo, tags…).
  static ColdigomPraiseMetadata toMetadata(PraiseDetailDto praise) {
    return ColdigomPraiseMetadata(
      name: praise.name,
      tonality: praise.tonality,
      author: praise.author,
      rhythm: praise.rhythm,
      category: praise.category,
      tagNames: praise.tagNames,
    );
  }

  /// Um [Louvor] por material PDF com `r2_key` válido.
  static List<Louvor> toLouvores(PraiseDetailDto praise) {
    final louvores = <Louvor>[];

    for (final material in praise.materials) {
      if (_kindOfType(material.type) != MaterialKind.pdf) continue;
      final r2Key = material.r2Key;
      if (r2Key == null || r2Key.isEmpty) continue;

      final pdfFileName = _basename(r2Key);
      louvores.add(
        Louvor.fromManifest(
          nome: praise.name,
          numero: praise.number,
          categoria: material.materialKindName ?? 'PDF',
          classificacao: praise.rhythm,
          pdf: pdfFileName,
          pdfId: encodePdfId(r2Key),
          groupId: praise.id,
          source: LouvorDataSource.coldigom,
        ),
      );
    }

    return louvores;
  }

  /// Uma [AudioTrack] por material `mp3`/`audio` com `r2_key` válido.
  static List<AudioTrack> toAudioTracks(PraiseDetailDto praise) {
    final tracks = <AudioTrack>[];

    for (final material in praise.materials) {
      if (_kindOfType(material.type) != MaterialKind.audio) continue;
      final r2Key = material.r2Key;
      if (r2Key == null || r2Key.isEmpty) continue;

      tracks.add(
        AudioTrack(
          audioId: encodePdfId(r2Key),
          r2Key: r2Key,
          nome: praise.name,
          numero: praise.number,
          groupId: praise.id,
          categoria: material.materialKindName ?? 'Áudio',
          classificacao: praise.rhythm,
          author: praise.author,
          source: LouvorDataSource.coldigom,
        ),
      );
    }

    return tracks;
  }

  /// Um [YoutubeMaterial] por `type: youtube` com URL HTTPS válida.
  static List<YoutubeMaterial> toYoutubeMaterials(PraiseDetailDto praise) {
    final items = <YoutubeMaterial>[];

    for (final material in praise.materials) {
      if (_kindOfType(material.type) != MaterialKind.youtube) continue;
      if (!YoutubeUrl.isValid(material.url)) continue;

      items.add(
        YoutubeMaterial(
          id: material.id,
          url: material.url!.trim(),
          nome: praise.name,
          numero: praise.number,
          groupId: praise.id,
          categoria: material.materialKindName ?? 'YouTube',
          classificacao: praise.rhythm,
          author: praise.author,
          source: LouvorDataSource.coldigom,
        ),
      );
    }

    return items;
  }

  /// Um [ChordMaterial] por `type: chord` com `r2_key` válido.
  static List<ChordMaterial> toChordMaterials(PraiseDetailDto praise) {
    final items = <ChordMaterial>[];

    for (final material in praise.materials) {
      if (_kindOfType(material.type) != MaterialKind.chord) continue;
      final r2Key = material.r2Key;
      if (r2Key == null || r2Key.isEmpty) continue;

      items.add(
        ChordMaterial(
          chordId: encodePdfId(r2Key),
          r2Key: r2Key,
          nome: praise.name,
          numero: praise.number,
          groupId: praise.id,
          categoria: material.materialKindName ?? 'Cifra',
          classificacao: praise.rhythm,
          author: praise.author,
          source: LouvorDataSource.coldigom,
        ),
      );
    }

    return items;
  }

  /// Único ponto que traduz o `type` do worker para o vocabulário do app.
  static MaterialKind _kindOfType(String type) {
    return switch (type.toLowerCase()) {
      'pdf' => MaterialKind.pdf,
      'chord' => MaterialKind.chord,
      'mp3' || 'audio' => MaterialKind.audio,
      'youtube' => MaterialKind.youtube,
      _ => MaterialKind.unknown,
    };
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }
}
