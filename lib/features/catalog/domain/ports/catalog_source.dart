import '../entities/catalog_material.dart';
import '../entities/louvor_group.dart';

/// Porta de leitura do catálogo por id — um vocabulário só para os dois acervos.
///
/// PLPCG (manifest) e Coldigom (caches por tipo) respondem às mesmas três
/// perguntas; quem chama (o desvio da playlist, o resolver de material, o botão
/// de trocar material) deixa de escolher a fonte e de conhecer os caches.
///
/// Os métodos são assíncronos porque uma implementação futura pode precisar de
/// rede (buscar o praise que ainda não está em cache); as implementações atuais
/// só leem memória e resolvem no mesmo microtask.
abstract class CatalogSource {
  /// Louvor lógico [groupId], ou `null` se a fonte não o conhece.
  Future<LouvorGroup?> groupById(String groupId);

  /// Material endereçável [materialId] (PDF, cifra ou áudio).
  ///
  /// `null` quando o id não é endereçável (YouTube, gesto, id inválido) ou
  /// quando a fonte ainda não tem o material.
  Future<CatalogMaterial?> materialById(String materialId);

  /// Louvor lógico ao qual [materialId] pertence, ou `null` se desconhecido.
  Future<LouvorGroup?> groupForMaterial(String materialId);
}
