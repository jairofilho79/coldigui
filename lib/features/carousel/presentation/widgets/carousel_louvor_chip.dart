import 'package:coldigui/core/presentation/widgets/highlighted_text.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import 'chip_parts/chip_body.dart';
import 'chip_parts/chip_buttons.dart';
import 'chip_parts/chip_group_label.dart';
import 'chip_parts/chip_nav_zone.dart';
import 'chip_parts/metadata_row.dart';
import 'chip_parts/peanut_lobe_border.dart';
import 'chip_parts/share_overflow_button.dart';

export 'chip_parts/chip_buttons.dart'
    show CarouselLouvorAddButton, ChipAddedIndicator;

/// Altura do chip na variante modal/pill (usada pelos cartões «Abertos
/// recentemente» da home).
const carouselChipBarHeight = 58.0;

/// Altura do chip na barra superior do shell (variante retangular).
const carouselChipTopBarHeight = 52.0;

/// Largura de referência do chip na barra (compacto).
const carouselChipMaxWidth = 168.0;

/// Largura abaixo da qual a linha de metadados exibe apenas ícones (com
/// [Tooltip]).
const carouselChipMetadataCompactWidth = 180.0;

/// Largura abaixo da qual classificação e categoria usam ícone + texto
/// truncável; acima disso, classificação fica só texto e categoria ícone +
/// texto.
const carouselChipMetadataMediumWidth = 280.0;

/// Raio da pílula (variante modal) — também o das pontas do amendoim
/// (`PeanutLobeBorder`).
const carouselChipModalRadius = 24.0;
const _topBarChipRadius = 8.0;
const _compactWidth = carouselChipMetadataCompactWidth;

/// Largura aproximada do chip «novo» (padding + texto de 10px + borda) —
/// reservada da linha de metadados quando ele aparece ao lado dela.
const _newChipReserve = 44.0;

/// Layout do chip — barra superior do shell vs modal/leitor.
enum CarouselLouvorChipVariant {
  /// Pill (`borderRadius` 24); `#numero — nome` na linha do título.
  modal,

  /// Retangular (`borderRadius` 8); só `nome` no título; `#numero` à esquerda
  /// da linha de metadados — usado em [CarouselChips].
  topBar,
}

/// Chip temático PLPCG — fundo vermelho, borda dourada, duas linhas de info.
///
/// Usado na [CarouselNavigatorBar] (variante [CarouselLouvorChipVariant.topBar]),
/// no modal de seleção (variante [CarouselLouvorChipVariant.modal]),
/// em [PlaylistListTile] (`onRemove`) e em [LouvorCard] — pesquisa/biblioteca
/// (`onAdd`, `isAdded`, `loading`, `onShare`, `shareLoading`).
///
/// A linha de metadados (classificação + categoria) é responsiva à largura do
/// chip ([LayoutBuilder]) — ver [ChipMetadataRow]:
///
/// - &lt; [carouselChipMetadataCompactWidth]: só ícones com [Tooltip].
/// - [carouselChipMetadataCompactWidth]–[carouselChipMetadataMediumWidth]:
///   ícone + texto truncável para classificação **e** categoria.
/// - ≥ [carouselChipMetadataMediumWidth]: classificação só texto; categoria
///   ícone + texto.
///
/// **Trailing (prioridade):** [loading] → spinner; senão [onRemove] → botão X;
/// senão [isAdded] → check; senão [onAdd] → botão +; depois menu ⋮ se
/// [onShare] (UC-04).
///
/// [onTap] abre o louvor no leitor (UC-04/05) — toque no corpo do chip, sem
/// interferir no trailing nem no drag handle do modal.
///
/// [showNavArrows] transforma o próprio chip no carrossel: as bordas ganham
/// zonas «‹ ›» ([ChipNavZone]) para trocar de louvor sem sair da barra — só a
/// barra do shell/leitor usa (D5).
///
/// Corpo, botões, linha de metadados, setas e menu de compartilhar (E4) vivem
/// em `chip_parts/` ([ChipBody], [ChipRemoveButton]/[ChipAddButton]/
/// [ChipAddedIndicator]/[CircleActionButton], [ChipMetadataRow]
/// (com `MaterialKindsRow` na variante de card, C5), [ChipNavZone],
/// [ShareOverflowButton]).
class CarouselLouvorChip extends StatelessWidget {
  const CarouselLouvorChip({
    required this.item,
    this.variant = CarouselLouvorChipVariant.modal,
    this.metadataSummary,
    this.materialKindsGroup,
    this.onMaterialKindTap,
    this.highlightQuery,
    this.lyricsSnippet,
    this.showDragHandle = false,
    this.onTap,
    this.onLongPress,
    this.onRemove,
    this.onAdd,
    this.onShare,
    this.isAdded = false,
    this.loading = false,
    this.shareLoading = false,
    this.offlineAvailability = PdfOfflineAvailability.notAvailable,
    this.showNavArrows = false,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.onPrevious,
    this.onNext,
    this.isNew = false,
    this.lobePosition,
    this.groupLabel,
    this.dimmed = false,
    this.isCurrent = false,
    this.dragHandleTargetId,
    this.bodyTargetId,
    this.removeTargetId,
    super.key,
  }) : assert(
         lobePosition == null ||
             (variant == CarouselLouvorChipVariant.modal && !showNavArrows),
         'gomo do amendoim só na variante modal, sem setas',
       );

  /// ID opcional de alvo de tutorial para a alça de arrasto.
  final String? dragHandleTargetId;

  /// ID opcional de alvo de tutorial para o corpo/toque do chip.
  final String? bodyTargetId;

  /// ID opcional de alvo de tutorial para o botão de remoção.
  final String? removeTargetId;

  /// Louvor enriquecido com metadados do manifest (`numero`, `nome`, etc.).
  final CarouselItem item;

  /// `topBar` na barra do shell; `modal` (pill) em listas, modal e leitor.
  final CarouselLouvorChipVariant variant;

  /// Substitui categoria/classificação — ex.: progresso de download. Tem
  /// prioridade sobre [materialKindsGroup].
  final String? metadataSummary;

  /// Variante de card da Home/Biblioteca (C5): quando presente, a linha de
  /// metadados vira [MaterialKindsRow] — ícones por tipo de material do
  /// grupo — no lugar de classificação/categoria.
  final LouvorGroup? materialKindsGroup;

  /// Toque num ícone de [materialKindsGroup] — ex.: abrir o `MaterialSheet`.
  final void Function(MaterialKind kind)? onMaterialKindTap;

  /// Termo buscado (Home) a destacar no título — cor ouro do tema (C5). Sem
  /// termo ou sem match, o título renderiza normal.
  final String? highlightQuery;

  /// Trecho de uma linha da letra ao redor do match da busca (C5.1) — vem de
  /// `LouvorGroup.coldigomMeta?.lyricsExcerpt`. `null`/vazio não desenha
  /// linha nenhuma; o card fica igual ao de hoje.
  final String? lyricsSnippet;

  /// Exibe ícone de drag à esquerda — usado no [ReorderableListView] do modal.
  final bool showDragHandle;

  /// Toque no corpo do chip — tipicamente [openCarouselPdfInReader].
  final VoidCallback? onTap;

  /// Pressionar e segurar o corpo do chip — no card da Pesquisar (C5),
  /// abre direto o material favorito do grupo, sem passar pelo sheet.
  final VoidCallback? onLongPress;

  /// Botão "X" no trailing — usado no modal de seleção e em [PlaylistListTile].
  final VoidCallback? onRemove;

  /// Botão "+" — usado em [LouvorCard] (catálogo/biblioteca).
  final VoidCallback? onAdd;

  /// Menu overflow (⋮) com **Compartilhar** — UC-04, paridade com o leitor.
  final void Function(Rect sharePositionOrigin)? onShare;

  /// Indica que o louvor já está na seleção (exibe check no trailing).
  final bool isAdded;

  /// Spinner no trailing enquanto uma ação assíncrona está em curso.
  final bool loading;

  /// Spinner no menu ⋮ enquanto o share está em curso.
  final bool shareLoading;

  /// Badge de disponibilidade offline no catálogo (permanente vs LRU).
  final PdfOfflineAvailability offlineAvailability;

  /// Zonas «‹ ›» nas bordas do chip (só a barra do shell/leitor usa).
  final bool showNavArrows;

  /// Habilita a zona esquerda — falso nos extremos da lista.
  final bool canGoPrevious;

  /// Habilita a zona direita — falso nos extremos da lista.
  final bool canGoNext;

  /// Ação da zona esquerda — sem efeito se [showNavArrows] for falso.
  final VoidCallback? onPrevious;

  /// Ação da zona direita — sem efeito se [showNavArrows] for falso.
  final VoidCallback? onNext;

  /// Grupo que só o remoto trouxe (§6.3) — chip «novo» ao lado do badge
  /// offline, sem competir com o título.
  final bool isNew;

  /// Gomo do amendoim (spec louvores-agrupados §6.2): troca a pílula pela
  /// [PeanutLobeBorder] desta posição, sem sombra própria (o cluster pinta
  /// uma só) e com padding 20/12 — a curva da junta recua na altura do «+».
  final LobePosition? lobePosition;

  /// Etiqueta dourada da versão, entre o corpo e o «+» (§5).
  final String? groupLabel;

  /// Membro do grupo que não casou com a busca ou os filtros: esmaece só o
  /// conteúdo; fundo e contorno ficam inteiros e o toque continua ativo (D3).
  final bool dimmed;

  /// Quando `true`, indica que este é o louvor atualmente aberto/em exibição no leitor.
  /// Recebe borda nobre [AppColors.goldLight] e aura suave [AppColors.goldGlow].
  final bool isCurrent;

  bool get _isTopBar => variant == CarouselLouvorChipVariant.topBar;

  Widget? get _trailingAction {
    if (loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
      );
    }
    if (onRemove != null) {
      final btn = ChipRemoveButton(onPressed: onRemove!);
      return removeTargetId != null
          ? SpotlightGuideTarget(
              id: removeTargetId!,
              child: btn,
            )
          : btn;
    }
    if (isAdded) return const ChipAddedIndicator();
    if (onAdd != null) return ChipAddButton(onPressed: onAdd!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final classificationLabel = LouvorClassification.displayLabel(
      item.classificacao,
    );
    // Áudio, cifra e gesto já sabem o que são; só PDF depende da categoria
    // (o manifest mistura Partitura/Cifra/Gestos em `type: pdf`).
    final categoryIcon = LouvorMaterialIcons.forKind(switch (item.kind) {
      MaterialKind.pdf || MaterialKind.unknown =>
        LouvorMaterialIcons.kindForCategory(item.categoria),
      _ => item.kind,
    });
    final chipRadius = _isTopBar ? _topBarChipRadius : carouselChipModalRadius;
    final padding = _isTopBar
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : lobePosition != null
        ? const EdgeInsets.fromLTRB(20, 6, 12, 6)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    const backgroundColor = AppColors.title;

    final l10n = AppLocalizations.of(context);
    // `labelTextWidth` só importa com etiqueta: aí a `Row` passa por um
    // `LayoutBuilder` (abaixo) que mede a largura da linha de conteúdo.
    Widget contentRow({
      double labelTextWidth = ChipGroupLabel.maxTextWidth,
    }) {
      final dragIcon = Icon(
        Icons.drag_indicator,
        color: AppColors.textLight.withValues(alpha: 0.7),
        size: 20,
      );

      final chipBody = ChipBody(
        borderRadius: _inkRadius(chipRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // O chip «novo» tira espaço da linha de metadados — reserva
            // essa largura antes de decidir o breakpoint (compacto vs.
            // médio), senão `ChipMetadataRow` escolhe um layout largo
            // demais para o que sobra e estoura.
            final metadataWidth = isNew
                ? (width - _newChipReserve).clamp(0.0, width)
                : width;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                HighlightedText(
                  text: _titleLine(item, _isTopBar),
                  query: highlightQuery ?? '',
                  style: AppTypography.headline.copyWith(
                    fontSize: width < _compactWidth ? 12 : 14,
                    height: 1.1,
                    color: AppColors.textLight,
                    shadows: const [],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((lyricsSnippet ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  HighlightedText(
                    text: lyricsSnippet!,
                    query: highlightQuery ?? '',
                    style: AppTypography.body.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: width < _compactWidth ? 11 : 12.5,
                      height: 1.2,
                      color: AppColors.textLight.withValues(alpha: 0.64),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: ChipMetadataRow(
                        width: metadataWidth,
                        numero: _isTopBar ? item.numero : null,
                        summary: metadataSummary,
                        materialKindsGroup: materialKindsGroup,
                        onMaterialKindTap: onMaterialKindTap,
                        classificationLabel: classificationLabel,
                        categoria: item.categoria,
                        categoryIcon: categoryIcon,
                        offlineAvailability: offlineAvailability,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 4),
                      _NewChip(
                        label: AppLocalizations.of(context)!
                            .searchResultNew,
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      );

      return Row(
        children: [
          if (showDragHandle) ...[
            if (dragHandleTargetId != null)
              SpotlightGuideTarget(
                id: dragHandleTargetId!,
                child: dragIcon,
              )
            else
              dragIcon,
            const SizedBox(width: 4),
          ],
          Expanded(
            child: bodyTargetId != null
                ? SpotlightGuideTarget(
                    id: bodyTargetId!,
                    child: chipBody,
                  )
                : chipBody,
          ),
        // Fora do `Expanded`: o `LayoutBuilder` do corpo já recebe a largura
        // sem a etiqueta, e o breakpoint da linha de metadados sai certo.
        if (groupLabel != null) ...[
          const SizedBox(width: 6),
          ChipGroupLabel(label: groupLabel!, textWidthLimit: labelTextWidth),
        ],
        if (isCurrent && !_isTopBar) ...[
          const SizedBox(width: 6),
          const _CurrentChip(label: 'Atual'),
        ],
        if (_trailingAction != null) ...[
          const SizedBox(width: 4),
          _trailingAction!,
        ],
        if (onShare != null) ...[
          const SizedBox(width: 2),
          ShareOverflowButton(
            onShare: onShare!,
            shareLabel:
                AppLocalizations.of(context)?.sharePdf ?? 'Compartilhar',
            loading: shareLoading,
          ),
        ],
      ],
    );
  }
    final body = Padding(
      padding: showNavArrows ? padding : EdgeInsets.zero,
      // Com etiqueta, o teto do texto dela acompanha a largura da linha
      // (`clamp(0.4 × W, 64, 128)`): num celular estreito o título não fica
      // espremido por uma etiqueta de 128 px fixos. Sem etiqueta, nada de
      // `LayoutBuilder` (não mexe no chip solto nem na barra).
      child: groupLabel == null
          ? contentRow()
          : LayoutBuilder(
              builder: (context, constraints) => contentRow(
                labelTextWidth: ChipGroupLabel.maxTextWidthFor(
                  constraints.maxWidth,
                ),
              ),
            ),
    );

    // Com setas o chip vira o próprio carrossel: as zonas ficam coladas nas
    // bordas do Container (por isso o clip e o padding zerado aqui, movido
    // para dentro de `body`), e o corpo ganha altura mínima de toque (44) e
    // um respiro lateral do tamanho das zonas (senão o texto nasce por
    // baixo delas).
    final constrainedBody = showNavArrows
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: chipNavZoneWidth),
              child: body,
            ),
          )
        : body;
    final content = dimmed
        ? Opacity(opacity: 0.45, child: constrainedBody)
        : constrainedBody;

    final borderColor = isCurrent ? AppColors.goldLight : AppColors.gold;
    final borderWidth = isCurrent ? 2.5 : 2.0;
    final boxShadow = isCurrent
        ? const [
            BoxShadow(
              color: AppColors.goldGlow,
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
          ]
        : AppColors.shadowMd;

    return Container(
      decoration: lobePosition == null
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(chipRadius),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: boxShadow,
            )
          : ShapeDecoration(
              color: backgroundColor,
              shape: PeanutLobeBorder(
                position: lobePosition!,
                radius: carouselChipModalRadius,
              ),
            ),
      clipBehavior: showNavArrows ? Clip.antiAlias : Clip.none,
      padding: showNavArrows ? EdgeInsets.zero : padding,
      // `Stack`/`Positioned`, não `Row`+`stretch`: o corpo continua dono da
      // própria altura (como sem setas) e as zonas só acompanham (`top: 0,
      // bottom: 0`). Isso funciona tanto solto num `Column` sem `Expanded`
      // (altura infinita, D2) quanto com o textScaler alto (o corpo cresce
      // e as zonas crescem junto) — um `Row` com `stretch` exige altura
      // finita vinda de fora, e uma altura fixa não cresce com o texto
      // (estoura em textScaler alto).
      child: showNavArrows
          ? Stack(
              children: [
                constrainedBody,
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: ChipNavZone(
                    icon: Icons.chevron_left,
                    tooltip: l10n?.readerCarouselPrevious ?? 'Louvor anterior',
                    enabled: canGoPrevious && onPrevious != null,
                    onTap: onPrevious,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: ChipNavZone(
                    icon: Icons.chevron_right,
                    tooltip: l10n?.readerCarouselNext ?? 'Próximo louvor',
                    enabled: canGoNext && onNext != null,
                    onTap: onNext,
                  ),
                ),
              ],
            )
          : content,
    );
  }

  /// Ripple do corpo: no gomo, 24 do lado da pílula e 12 do lado da junta
  /// — o `InkWell` fica recuado pelo padding e não vaza pelo bico.
  BorderRadius _inkRadius(double chipRadius) {
    const pill = Radius.circular(carouselChipModalRadius);
    const joint = Radius.circular(12);
    return switch (lobePosition) {
      null => BorderRadius.circular(chipRadius),
      LobePosition.first => const BorderRadius.vertical(
        top: pill,
        bottom: joint,
      ),
      LobePosition.middle => const BorderRadius.all(joint),
      LobePosition.last => const BorderRadius.vertical(
        top: joint,
        bottom: pill,
      ),
    };
  }

  static String _titleLine(CarouselItem item, bool topBar) {
    if (topBar || item.numero.isEmpty) return item.nome;
    return '#${item.numero} — ${item.nome}';
  }
}

/// Chip «novo» — mesmo estilo do badge offline: pequeno, dourado, sem
/// competir com o título.
class _NewChip extends StatelessWidget {
  const _NewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          fontSize: 10,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

/// Tag de louvor atual no modal — mesmo estilo visual compacto das etiquetas
/// dos cards de louvor da tela de pesquisa ([ChipGroupLabel] / [_NewChip]).
class _CurrentChip extends StatelessWidget {
  const _CurrentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldLight, width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.label.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.goldLight,
        ),
      ),
    );
  }
}
