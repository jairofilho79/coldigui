import '../../../../core/database/collections/louvor_cache.dart';
import '../../domain/entities/louvor.dart';

/// Converte entidade de domínio [Louvor] para documento Isar [LouvorCache].
///
/// Persiste [Louvor.groupId] para paridade offline com o catálogo D1.
extension LouvorToCache on Louvor {
  LouvorCache toCache() => LouvorCache()
    ..pdfId = pdfId
    ..nome = nome
    ..numero = numero
    ..categoria = categoria
    ..classificacao = classificacao
    ..pdf = pdf
    ..groupId = groupId;
}

/// Converte documento Isar [LouvorCache] para entidade [Louvor].
///
/// Restaura [Louvor.groupId] do cache; [Louvor.fromManifest] normaliza [Louvor.numero].
extension LouvorCacheToEntity on LouvorCache {
  Louvor toEntity() => Louvor.fromManifest(
        nome: nome,
        numero: numero,
        categoria: categoria,
        classificacao: classificacao,
        pdf: pdf,
        pdfId: pdfId,
        groupId: groupId,
      );
}
