import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';

import '../models/praise_dto.dart';

/// Converte louvores coldigom em entidades [Louvor] do domínio PLPCG.
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

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }
}
