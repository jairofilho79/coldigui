/// Teto da lista de favoritos — o Worker aplica o mesmo número.
const int kMaxFavoriteMaterialKinds = 5;

/// Preferência de material kinds Coldigom de uma conta: lista ordenada de
/// até [kMaxFavoriteMaterialKinds] ids, o material type preferido de cada um
/// (quando o kind tem mais de um, ex.: cifra em PDF ou em chords), o instante
/// da última edição e se ela ainda não subiu para o Worker.
///
/// É um documento inteiro, não N linhas: reordenar cinco itens é uma edição,
/// e o conflito entre aparelhos resolve por `updatedAt` (last-write-wins).
class MaterialKindPrefs {
  const MaterialKindPrefs._({
    required this.kindIds,
    required this.preferredTypeByKind,
    required this.updatedAt,
    required this.pendingPush,
  });

  /// Ids de `material_kinds`; índice 0 é o favorito nº 1.
  final List<String> kindIds;

  /// Material type (`pdf`/`chord`/...) preferido por kind favoritado.
  ///
  /// Kind sem entrada aqui usa o primeiro type disponível como padrão — ver
  /// `favorite_material_kinds_screen.dart`. Chave que não está em [kindIds]
  /// é possível (kind removido dos favoritos, preferência não limpa) e é
  /// inofensiva: ninguém a lê fora do card daquele kind.
  final Map<String, String> preferredTypeByKind;

  /// Última edição (UTC). Vai no PUT e decide quem ganha no sync.
  final DateTime updatedAt;

  /// `true` entre o `save` local e o PUT bem-sucedido.
  final bool pendingPush;

  /// Sem favoritos — o estado de quem nunca escolheu ou está deslogado.
  ///
  /// `final`, não `const`: `DateTime` não tem construtor const.
  static final MaterialKindPrefs empty = MaterialKindPrefs._(
    kindIds: const <String>[],
    preferredTypeByKind: const <String, String>{},
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    pendingPush: false,
  );

  /// Constrói validando o invariante; lança [ArgumentError] fora dele.
  factory MaterialKindPrefs.validated({
    required List<String> kindIds,
    required DateTime updatedAt,
    Map<String, String> preferredTypeByKind = const <String, String>{},
    bool pendingPush = false,
  }) {
    if (kindIds.length > kMaxFavoriteMaterialKinds) {
      throw ArgumentError.value(
        kindIds,
        'kindIds',
        'máximo $kMaxFavoriteMaterialKinds',
      );
    }
    if (kindIds.any((id) => id.isEmpty)) {
      throw ArgumentError.value(kindIds, 'kindIds', 'id vazio');
    }
    if (kindIds.toSet().length != kindIds.length) {
      throw ArgumentError.value(kindIds, 'kindIds', 'duplicata');
    }
    return MaterialKindPrefs._(
      kindIds: List.unmodifiable(kindIds),
      preferredTypeByKind: Map.unmodifiable(preferredTypeByKind),
      updatedAt: updatedAt.toUtc(),
      pendingPush: pendingPush,
    );
  }

  /// `kindId → posição` para o sheet ordenar.
  Map<String, int> get rank => {
    for (var i = 0; i < kindIds.length; i++) kindIds[i]: i,
  };

  MaterialKindPrefs copyWith({
    List<String>? kindIds,
    Map<String, String>? preferredTypeByKind,
    DateTime? updatedAt,
    bool? pendingPush,
  }) {
    return MaterialKindPrefs.validated(
      kindIds: kindIds ?? this.kindIds,
      preferredTypeByKind: preferredTypeByKind ?? this.preferredTypeByKind,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingPush: pendingPush ?? this.pendingPush,
    );
  }

  Map<String, Object?> toJson() => {
    'kindIds': kindIds,
    'preferredTypeByKind': preferredTypeByKind,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'pendingPush': pendingPush,
  };

  /// Leitura tolerante: `null` quando faltam campos obrigatórios ou a data é
  /// ilegível; ids repetidos ou além do teto são cortados (outra versão do
  /// app pode ter gravado mais) em vez de perder o documento.
  /// `preferredTypeByKind` ausente (documento de antes desta preferência
  /// existir) vira mapa vazio.
  static MaterialKindPrefs? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final rawIds = json['kindIds'];
    final rawUpdated = json['updatedAt'];
    if (rawIds is! List || rawUpdated is! String) return null;
    final updatedAt = DateTime.tryParse(rawUpdated);
    if (updatedAt == null) return null;
    final ids = <String>[];
    for (final id in rawIds) {
      if (id is! String || id.isEmpty || ids.contains(id)) continue;
      ids.add(id);
      if (ids.length == kMaxFavoriteMaterialKinds) break;
    }
    final rawTypes = json['preferredTypeByKind'];
    final types = <String, String>{};
    if (rawTypes is Map) {
      for (final entry in rawTypes.entries) {
        if (entry.key is String && entry.value is String) {
          types[entry.key as String] = entry.value as String;
        }
      }
    }
    return MaterialKindPrefs._(
      kindIds: List.unmodifiable(ids),
      preferredTypeByKind: Map.unmodifiable(types),
      updatedAt: updatedAt.toUtc(),
      pendingPush: json['pendingPush'] == true,
    );
  }
}
