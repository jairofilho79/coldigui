import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';

import '../models/praise_dto.dart';

/// Converte louvores coldigom em entidades [Louvor] / [AudioTrack] do PLPCG.
abstract final class ColdigomLouvorAdapter {
  /// Um [Louvor] por material PDF com `r2_key` válido.
  static List<Louvor> toLouvores(PraiseDetailDto praise) {
    final louvores = <Louvor>[];

    for (final material in praise.materials) {
      if (material.type != 'pdf') continue;
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
      if (!_isAudioType(material.type)) continue;
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

  static bool _isAudioType(String type) {
    final lower = type.toLowerCase();
    return lower == 'mp3' || lower == 'audio';
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }
}
