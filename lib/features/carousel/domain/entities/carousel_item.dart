import '../../../../core/utils/material_id_kind.dart';
import '../../../catalog/domain/entities/louvor_data_source.dart';
import '../../../playlists/domain/entities/active_entry.dart';

export '../../../../core/utils/material_id_kind.dart' show MaterialKind;

/// Uma entrada da lista ativa pronta para a UI (D3).
///
/// Deixou de ser uma linha persistida: é uma **view** de `ActiveEntry` de uma
/// das faces da lista ativa, enriquecida com os metadados do manifest/caches.
/// [index] é a posição **dentro da face** (0..n-1) e [key] é a chave estável
/// por ocorrência — duas ocorrências do mesmo louvor têm a mesma [materialId]
/// e chaves diferentes.
class CarouselItem {
  /// [materialId], [kind], [index] e [key] são o contrato novo; `pdfId` e
  /// `sortOrder` continuam aceitos como apelidos enquanto os widgets antigos
  /// não foram reescritos (Tarefas 12–16).
  ///
  /// Sem [key] a chave é a da **primeira** ocorrência ([entryKeyFor] com
  /// `occurrence == 0`, que é o próprio id); sem [kind] o item entra como
  /// [MaterialKind.pdf] — quem constrói pela API antiga está sempre montando
  /// um chip da face de partituras.
  const CarouselItem({
    String? materialId,
    MaterialKind? kind,
    int? index,
    String? key,
    @Deprecated('use materialId') String? pdfId,
    @Deprecated('use index') int? sortOrder,
    required this.numero,
    required this.nome,
    required this.categoria,
    required this.classificacao,
    this.source = LouvorDataSource.plpcg,
  }) : assert(
         materialId != null || pdfId != null,
         'CarouselItem precisa de materialId',
       ),
       materialId = materialId ?? pdfId ?? '',
       kind = kind ?? MaterialKind.pdf,
       index = index ?? sortOrder ?? 0,
       key = key ?? materialId ?? pdfId ?? '';

  /// Identificador estável do material (Base64 URL-safe do path).
  final String materialId;

  /// Tipo do material — define a face em que o item aparece.
  final MaterialKind kind;

  /// Posição dentro da face — contígua 0..n-1.
  final int index;

  /// Chave estável por ocorrência (`id`, `id#1`, …) — ver [entryKeyFor].
  final String key;

  /// Número do louvor (manifest `numero`).
  final String numero;

  /// Título do louvor (manifest `nome`).
  final String nome;

  /// Material: Partitura, Cifra, Gestos em Gravura, etc.
  final String categoria;

  /// Classificação normalizada (ex.: ColAdultos).
  final String classificacao;

  /// Origem dos metadados — define cor do chip na UI.
  final LouvorDataSource source;

  /// Rótulo legado — tipicamente `numero — nome` (folheto UC-08).
  String get label => numero.isEmpty ? nome : '$numero — $nome';

  /// `true` se o item pertence à face de áudio.
  bool get isAudio => kind == MaterialKind.audio;

  @Deprecated('use materialId')
  String get pdfId => materialId;

  @Deprecated('use index')
  int get sortOrder => index;
}
