/// Posição do item corrente dentro da face de partituras, vista do leitor.
///
/// Depois do D3 a seleção admite o mesmo louvor repetido, então "onde estou"
/// deixou de ser respondível só pelo id: a identidade de uma entrada é a
/// [currentKey] (a chave por ocorrência de `ActiveEntry`). Os vizinhos vêm em
/// par — [previousKey]/[nextKey] dizem **qual ocorrência** focar e
/// [previousMaterialId]/[nextMaterialId] dizem **o que abrir** na rota.
///
/// Sem wrap circular: as extremidades dão `null` nos dois lados.
class CarouselReaderPosition {
  /// [previousMaterialId]/[nextMaterialId] são o contrato novo; `previousPdfId`
  /// e `nextPdfId` continuam aceitos como apelidos enquanto os widgets do
  /// carousel não foram reescritos (Tarefas 12–16).
  const CarouselReaderPosition({
    required this.currentIndex,
    required this.total,
    this.currentKey = '',
    this.previousKey,
    this.nextKey,
    String? previousMaterialId,
    String? nextMaterialId,
    @Deprecated('use previousMaterialId') String? previousPdfId,
    @Deprecated('use nextMaterialId') String? nextPdfId,
  }) : previousMaterialId = previousMaterialId ?? previousPdfId,
       nextMaterialId = nextMaterialId ?? nextPdfId;

  /// Índice 1-based na face de partituras da lista ativa.
  final int currentIndex;

  /// Total de itens na face de partituras.
  final int total;

  /// Chave da ocorrência corrente (`id`, `id#1`, …).
  final String currentKey;

  /// Chave da ocorrência anterior, ou `null` no primeiro item.
  final String? previousKey;

  /// Chave da próxima ocorrência, ou `null` no último item.
  final String? nextKey;

  /// Material anterior ou `null` no primeiro item.
  final String? previousMaterialId;

  /// Próximo material ou `null` no último item.
  final String? nextMaterialId;

  bool get canGoPrevious => previousMaterialId != null;

  bool get canGoNext => nextMaterialId != null;

  @Deprecated('use previousMaterialId')
  String? get previousPdfId => previousMaterialId;

  @Deprecated('use nextMaterialId')
  String? get nextPdfId => nextMaterialId;
}

/// Direção de navegação no carousel do leitor.
enum CarouselReaderDirection { previous, next }
