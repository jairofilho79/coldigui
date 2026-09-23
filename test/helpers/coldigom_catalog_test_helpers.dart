import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';

/// Um praise do catálogo montado como a hidratação o monta (adapter +
/// `coldigomMeta`) — para testes de filtros, /biblioteca e página inicial
/// sem Isar nem rede.
///
/// [pdfKinds]/[audioKinds]: `kindId → nome do kind`; cada entrada vira um
/// material (`pdf`/`mp3`) com `materialKindId`. Precisa de pelo menos um
/// material, senão não há grupo.
LouvorGroup catalogGroup({
  required String praiseId,
  required String name,
  String number = '',
  String tonality = '',
  String rhythm = '',
  String category = '',
  List<String> tags = const [],
  Map<String, String> pdfKinds = const {'k-partitura': 'Partitura'},
  Map<String, String> audioKinds = const {},
  String? shortId,
}) {
  final materials = <MaterialDto>[
    for (final kind in pdfKinds.entries)
      MaterialDto(
        id: 'pdf-${kind.key}',
        type: 'pdf',
        r2Key: 'assets/praises/$praiseId/pdf-${kind.key}.pdf',
        materialKindId: kind.key,
        materialKindName: kind.value,
      ),
    for (final kind in audioKinds.entries)
      MaterialDto(
        id: 'mp3-${kind.key}',
        type: 'mp3',
        r2Key: 'assets/praises/$praiseId/mp3-${kind.key}.mp3',
        materialKindId: kind.key,
        materialKindName: kind.value,
      ),
  ];
  final detail = PraiseDetailDto(
    id: praiseId,
    name: name,
    number: number,
    rhythm: rhythm,
    tonality: tonality,
    category: category,
    tagNames: tags,
    shortId: shortId,
    materials: materials,
  );
  return LouvorGroup.fromLouvores(
    ColdigomLouvorAdapter.toLouvores(detail),
    audioTracks: ColdigomLouvorAdapter.toAudioTracks(detail),
    coldigomMetaByGroupId: {praiseId: ColdigomLouvorAdapter.toMetadata(detail)},
  ).single;
}

/// Índice com [groups], tokens de busca calculados como no sync.
ColdigomSearchIndex catalogIndexOf(List<LouvorGroup> groups) {
  return ColdigomSearchIndex.build([
    for (final group in groups)
      ColdigomIndexedPraise.build(
        praiseId: group.groupId,
        numero: group.numero,
        nome: group.nome,
        searchTokens: ColdigomPraiseCacheMapper.buildSearchTokens(
          name: group.nome,
          number: group.numero,
          author: group.coldigomMeta?.author ?? '',
          tags: group.coldigomMeta?.tagNames ?? const [],
        ),
        group: group,
      ),
  ]);
}
