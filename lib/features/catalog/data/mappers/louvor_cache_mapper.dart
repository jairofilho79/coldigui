import '../../../../core/database/collections/louvor_cache.dart';
import '../../domain/entities/louvor.dart';

/// Converte entidade de domínio [Louvor] para documento Isar [LouvorCache].
extension LouvorToCache on Louvor {
  LouvorCache toCache() => LouvorCache()
    ..pdfId = pdfId
    ..nome = nome
    ..numero = numero
    ..categoria = categoria
    ..classificacao = classificacao
    ..pdf = pdf;
}

/// Converte documento Isar [LouvorCache] para entidade [Louvor].
extension LouvorCacheToEntity on LouvorCache {
  Louvor toEntity() => Louvor.fromManifest(
        nome: nome,
        numero: numero,
        categoria: categoria,
        classificacao: classificacao,
        pdf: pdf,
        pdfId: pdfId,
      );
}
