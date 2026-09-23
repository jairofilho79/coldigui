import '../../../../core/utils/material_id_kind.dart';
import '../../../playlists/domain/entities/active_entry.dart';

export '../../../../core/utils/material_id_kind.dart' show MaterialKind;

/// Uma entrada da lista ativa pronta para a UI (D3).
///
/// Deixou de ser uma linha persistida: é uma **view** de `ActiveEntry` da
/// lista ativa (sem faces, spec 2026-09-12 D1 — PDF, cifra, gesto e áudio na
/// mesma lista), enriquecida com os metadados do catálogo.
/// [index] é a posição **na lista inteira** (0..n-1) e [key] é a chave
/// estável por ocorrência — duas ocorrências do mesmo louvor têm a mesma
/// [materialId] e chaves diferentes.
class CarouselItem {
  /// Sem [key] a chave é a da **primeira** ocorrência ([entryKeyFor] com
  /// `occurrence == 0`, que é o próprio id); sem [kind] o item entra como
  /// [MaterialKind.pdf] — um chip solto (card do catálogo, lista salva) é
  /// sempre de partitura.
  const CarouselItem({
    required this.materialId,
    MaterialKind? kind,
    required this.index,
    String? key,
    required this.numero,
    required this.nome,
    required this.categoria,
    required this.classificacao,
  }) : kind = kind ?? MaterialKind.pdf,
       key = key ?? materialId;

  /// Identificador estável do material (Base64 URL-safe do path).
  final String materialId;

  /// Tipo do material — PDF, cifra, gesto ou áudio.
  final MaterialKind kind;

  /// Posição na lista ativa inteira — contígua 0..n-1.
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

  /// Rótulo legado — tipicamente `numero — nome` (folheto UC-08).
  String get label => numero.isEmpty ? nome : '$numero — $nome';

  /// `true` se o item é uma entrada de áudio.
  bool get isAudio => kind == MaterialKind.audio;
}
