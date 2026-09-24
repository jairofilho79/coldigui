import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/domain/utils/find_material_for_group.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Barra global de seleção temporária (UC-05 / UC-11) exibida no [ShellScaffold].
///
/// Única instância compartilhada em todas as rotas do shell, inclusive `/leitor`
/// e `/audio`.
///
/// Sem faces (spec 2026-09-12, D1): chips de toda a lista ativa
/// ([carouselItemsProvider]) — PDF, cifra, gesto e áudio juntos, na mesma
/// ordem em que estão na lista. O áudio vive no mini-player, fora daqui.
///
/// Retorna [SizedBox.shrink] quando a lista está vazia.
///
/// Monta também o listener de "Seguir o áudio"
/// ([listenAudioFollowReader]) — é o único widget presente em todas as rotas
/// do shell, inclusive quando a barra não desenha nada.
class CarouselChips extends ConsumerWidget {
  const CarouselChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenAudioFollowReader(ref, context);

    // Só a lista: a barra é montada em toda rota do shell e não pode
    // reconstruir a ~5 Hz com o estado da sessão de áudio (A7) — o áudio vive
    // no mini-player, fora daqui.
    final items = ref.watch(carouselItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    return _CarouselChipsBar(items: items);
  }
}

class _CarouselChipsBar extends ConsumerStatefulWidget {
  const _CarouselChipsBar({required this.items});

  final List<CarouselItem> items;

  @override
  ConsumerState<_CarouselChipsBar> createState() => _CarouselChipsBarState();
}

class _CarouselChipsBarState extends ConsumerState<_CarouselChipsBar> {
  var _openingReader = false;
  var _carouselNavLoading = false;
  String? _lastSyncedReaderMaterialId;

  List<CarouselItem> get items => widget.items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onReaderRouteChanged(),
    );
  }

  @override
  void didUpdateWidget(covariant _CarouselChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onReaderRouteChanged();
  }

  /// A rota é uma dependência herdada (`GoRouterState.of` lê um
  /// `InheritedNotifier`): é por aqui que a troca de rota chega — a barra vive
  /// no shell, acima do `navigationShell`, e não recebe `didUpdateWidget` só
  /// porque o leitor trocou de louvor.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onReaderRouteChanged();
  }

  /// Sincroniza o foco da lista com o material da rota do leitor — **só
  /// quando a rota mudou**.
  ///
  /// Quem navega pela lista (setas, teclado, chip) foca a entrada **antes** de
  /// resolver a rota, e resolver um PDF leva mais de um frame. Se a barra
  /// reconstruir nesse meio-tempo (o warmup Coldigom re-emite o lookup e a
  /// lista), a rota ainda é a do louvor anterior — refocar por ela devolveria
  /// o foco ao louvor de onde o usuário saiu, e o gestor ao vivo mandaria o
  /// `set` "um louvor atrás".
  void _onReaderRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_isReaderRoute) {
        _lastSyncedReaderMaterialId = null;
        ref.read(readerRouteParamsProvider.notifier).clear();
        return;
      }

      final materialId = _resolveReaderMaterialId(readOnly: true);
      if (materialId == _lastSyncedReaderMaterialId) return;

      setState(() {
        _lastSyncedReaderMaterialId = materialId;
        _carouselNavLoading = false;
        _openingReader = false;
      });
      if (materialId != null) _focusMaterialId(materialId);
    });
  }

  /// Foca a ocorrência de [materialId] na face de partituras.
  ///
  /// A ocorrência já focada vence (B.5): o mesmo louvor pode estar duas vezes
  /// na lista e trocar o foco para a primeira delas moveria o usuário sozinho.
  void _focusMaterialId(String materialId) {
    final all = ref.read(carouselItemsProvider);
    if (all.isEmpty) return;
    final focused = ref.read(carouselFocusedIndexProvider);
    if (focused >= 0 &&
        focused < all.length &&
        all[focused].materialId == materialId) {
      return;
    }
    for (final item in all) {
      if (item.materialId != materialId) continue;
      ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
      return;
    }
  }

  GoRouterState? get _routerState {
    final router = GoRouter.maybeOf(context);
    return router == null ? null : GoRouterState.of(context);
  }

  bool get _isReaderRoute {
    final path = _routerState?.uri.path;
    return path == RoutePaths.reader ||
        path == RoutePaths.chords ||
        path == RoutePaths.gestos;
  }

  Map<String, String> _readerRouteParams({required bool readOnly}) {
    if (!_isReaderRoute) return const {};
    final fromRouter = _routerState?.uri.queryParameters ?? const {};
    if (fromRouter.isNotEmpty) return fromRouter;
    final fromScreen = readOnly
        ? ref.read(readerRouteParamsProvider)
        : ref.watch(readerRouteParamsProvider);
    return fromScreen;
  }

  String? _resolveReaderMaterialId({required bool readOnly}) {
    final fromUrl = _readerRouteParams(readOnly: readOnly)[UrlSyncParams.pdfId];
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;

    if (!_isReaderRoute || items.isEmpty) return null;
    final focusedIndex =
        (readOnly
                ? ref.read(carouselFocusedIndexProvider)
                : ref.watch(carouselFocusedIndexProvider))
            .clamp(0, items.length - 1);
    return items[focusedIndex].materialId;
  }

  String? get _readerMaterialId => _resolveReaderMaterialId(readOnly: false);

  String get _readerTitulo {
    final titulo = _readerRouteParams(readOnly: false)[UrlSyncParams.titulo];
    if (titulo != null && titulo.isNotEmpty) return titulo;
    final materialId = _readerMaterialId;
    if (materialId == null) return '';
    return _itemForMaterialId(materialId, '').nome;
  }

  /// Item da face para [materialId] — a ocorrência focada quando é a dele,
  /// senão a primeira. Fora da lista, um item sintético com o título da URL.
  CarouselItem _itemForMaterialId(String materialId, String titulo) {
    final focused = ref.read(carouselFocusedIndexProvider);
    if (focused >= 0 &&
        focused < items.length &&
        items[focused].materialId == materialId) {
      return items[focused];
    }
    for (final item in items) {
      if (item.materialId == materialId) return item;
    }
    return CarouselItem(
      materialId: materialId,
      index: 0,
      numero: '',
      nome: titulo,
      categoria: '',
      classificacao: '',
    );
  }

  /// «Abrir» o item focado: leitor para o que se lê, player para áudio
  /// (spec 2026-09-12, §3.2). O chip da barra, o botão «Abrir» e o toque no
  /// sheet de seleção (fora do leitor) despacham todos por aqui.
  Future<void> _openItem(CarouselItem item) async {
    if (item.isAudio) return _openAudio(item);
    return _openInReader(item);
  }

  Future<void> _openInReader(CarouselItem item) async {
    if (_openingReader) return;
    setState(() => _openingReader = true);
    try {
      await openCarouselPdfInReader(
        ref: ref,
        context: context,
        materialId: item.materialId,
        navigate: (location) async {
          context.push(location);
        },
      );
      if (!mounted) return;
      ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
    } finally {
      if (mounted) setState(() => _openingReader = false);
    }
  }

  /// Toca [item] no player global — fila híbrida (spec §3.2:
  /// `queueForTrack`, a lista quando a faixa está nela, senão o grupo).
  Future<void> _openAudio(CarouselItem item) async {
    if (_openingReader) return;
    final lookup = ref.read(catalogMaterialLookupProvider);
    final track = lookup.audioTrack(item.materialId);
    if (track == null) {
      final l10n = AppLocalizations.of(context);
      showAppSnackbar(
        context,
        l10n?.audioPlaybackError ?? 'Não foi possível tocar o áudio',
      );
      return;
    }
    setState(() => _openingReader = true);
    try {
      ref.read(carouselFocusedIndexProvider.notifier).focusKey(item.key);
      await openAudioInPlayer(
        ref: ref,
        context: context,
        track: track,
        queue: queueForTrack(
          track: track,
          groupTracks: tracksForGroup(
            track.groupId,
            lookup.audioTracksById.values.toList(growable: false),
          ),
          activeQueue: activeListAudioQueue(ref),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingReader = false);
    }
  }

  Future<void> _handleCarouselItemRemoved(String removedMaterialId) async {
    final currentMaterialId = _readerMaterialId;
    if (currentMaterialId == null || removedMaterialId != currentMaterialId) {
      return;
    }

    final remaining = ref.read(carouselItemsProvider);
    if (!mounted) return;

    // O material aberto pode estar repetido: sair uma ocorrência não tira o
    // leitor de onde ele está enquanto sobrar outra do mesmo material.
    if (remaining.any((item) => item.materialId == currentMaterialId)) return;

    if (remaining.isEmpty) {
      context.pop();
      return;
    }

    setState(() => _carouselNavLoading = true);
    try {
      final location = await ref
          .read(readerCarouselActionsProvider.notifier)
          .navigateToKey(key: remaining.first.key);
      if (!mounted) return;

      if (location != null) {
        context.replace(location);
      }
    } finally {
      if (mounted) setState(() => _carouselNavLoading = false);
    }
  }

  Future<void> _openReaderSelectionSheet() {
    return showCarouselSelectionSheet(
      context,
      onItemRemoved: _handleCarouselItemRemoved,
      onItemTap: _replaceReaderWithCarouselItem,
    );
  }

  Future<void> _replaceReaderWithCarouselItem(CarouselItem selected) async {
    // Áudio não troca o leitor (é outra face) — abre no player, como faria
    // fora do leitor (spec §3.2).
    if (selected.isAudio) return _openAudio(selected);

    final activeMaterialId = _resolveReaderMaterialId(readOnly: true);
    if (activeMaterialId != null && selected.materialId == activeMaterialId) {
      return;
    }
    if (_carouselNavLoading) return;

    setState(() => _carouselNavLoading = true);
    try {
      // O foco vai **antes** da rota: é a chave focada que diz a
      // `readerCarouselPositionProvider` qual ocorrência está aberta, e as
      // setas do leitor têm que sair desta, não da primeira do mesmo id.
      ref.read(carouselFocusedIndexProvider.notifier).focusKey(selected.key);
      await openCarouselPdfInReader(
        ref: ref,
        context: context,
        materialId: selected.materialId,
        navigate: (location) async {
          context.replace(location);
        },
      );
    } finally {
      if (mounted) setState(() => _carouselNavLoading = false);
    }
  }

  Future<void> _navigateCarouselInReader({
    required CarouselReaderDirection direction,
    required CarouselReaderPosition position,
  }) async {
    if (_carouselNavLoading) return;

    // Navega por **chave**: o mesmo louvor repetido na lista tem vizinhos
    // diferentes em cada ocorrência, e um id sozinho não diz qual é a daqui.
    final targetKey = switch (direction) {
      CarouselReaderDirection.previous => position.previousKey,
      CarouselReaderDirection.next => position.nextKey,
    };
    if (targetKey == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _carouselNavLoading = true);

    try {
      // `navigateToKey` já foca a ocorrência antes de resolver a rota.
      final location = await ref
          .read(readerCarouselActionsProvider.notifier)
          .navigateToKey(key: targetKey);
      if (!mounted) return;

      if (location == null) {
        showAppSnackbar(
          context,
          l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
        );
        return;
      }

      context.replace(location);
    } on InvalidPdfPathException {
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
        );
      }
    } on PdfOfflineUnavailableException catch (e) {
      if (mounted) showAppSnackbar(context, e.message);
    } on PdfExternallyDeletedException {
      // A exceção não carrega mais literal PT: o texto vem do l10n (D.6).
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfExternallyDeleted ??
              'O PDF foi removido do dispositivo. Conecte-se ou baixe o '
                  'tipo dele de novo em Offline → Baixar para usar offline.',
        );
      }
    } on PdfFetchFailedException catch (e) {
      if (mounted) showAppSnackbar(context, e.message);
    } on Object {
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
        );
      }
    } finally {
      if (mounted) setState(() => _carouselNavLoading = false);
    }
  }

  Widget _buildNavigatorBar({
    required CarouselItem item,
    required bool canGoPrevious,
    required bool canGoNext,
    required bool loading,
    required bool showActivePlaylistName,
    required bool showLabels,
    required double barWidth,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onChipTap,
    required VoidCallback onOpenSelection,
    VoidCallback? onOpen,
  }) {
    // Grupo «louvor» só aparece com alternativa de material — sem isso, o
    // botão «Material» ficaria sempre oculto e o grupo, vazio.
    //
    // Resolvido uma vez aqui (e não dentro do botão) porque uma entrada de
    // áudio focada não tem `materialId` — o id dela é de faixa, e
    // `findSwapMaterialGroup` só o reconhece pelo parâmetro `audioId`
    // (B.6/Crítico #1). O botão recebe o grupo já pronto.
    final swapGroup = resolveCarouselSwapMaterialGroup(
      ref,
      materialId: item.isAudio ? null : item.materialId,
      audioId: item.isAudio ? item.materialId : null,
    );

    return CarouselBarShell(
      applySafeArea: false,
      child: Row(
        children: [
          // C11: nome da lista ativa à esquerda — some abaixo de 480 px (a
          // chip do louvor tem prioridade na largura).
          if (showActivePlaylistName)
            ActivePlaylistNameChip(
              maxWidth: ActivePlaylistNameChip.maxWidthForBar(barWidth),
            ),
          Expanded(
            child: CarouselNavigatorBar(
              item: item,
              chipVariant: CarouselLouvorChipVariant.topBar,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              showLabels: showLabels,
              loading: loading,
              onPrevious: onPrevious,
              onNext: onNext,
              onChipTap: onChipTap,
              onOpen: onOpen,
              onOpenSelection: onOpenSelection,
              swapMaterial: swapGroup == null
                  ? null
                  : CarouselSwapMaterialButton(
                      materialId: item.isAudio ? null : item.materialId,
                      audioId: item.isAudio ? item.materialId : null,
                      entryKey: item.key,
                      group: swapGroup,
                      showLabel: showLabels,
                    ),
              trailingActions: [
                CarouselBarTrailingActions(showLabels: showLabels),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShellMode({
    required bool showActivePlaylistName,
    required bool showLabels,
    required double barWidth,
  }) {
    final focusedIndex = ref
        .watch(carouselFocusedIndexProvider)
        .clamp(0, items.length - 1);
    final focusedItem = items[focusedIndex];
    final onReaderWithoutPdfId = _isReaderRoute;

    return _buildNavigatorBar(
      item: focusedItem,
      canGoPrevious: focusedIndex > 0,
      canGoNext: focusedIndex < items.length - 1,
      loading: _openingReader || _carouselNavLoading,
      showActivePlaylistName: showActivePlaylistName,
      showLabels: showLabels,
      barWidth: barWidth,
      onPrevious: onReaderWithoutPdfId
          ? (focusedIndex > 0
                ? () => _replaceReaderWithCarouselItem(items[focusedIndex - 1])
                : null)
          : () => ref.read(carouselFocusedIndexProvider.notifier).goPrevious(),
      onNext: onReaderWithoutPdfId
          ? (focusedIndex < items.length - 1
                ? () => _replaceReaderWithCarouselItem(items[focusedIndex + 1])
                : null)
          : () => ref.read(carouselFocusedIndexProvider.notifier).goNext(),
      onChipTap: onReaderWithoutPdfId ? null : () => _openItem(focusedItem),
      onOpen: onReaderWithoutPdfId ? null : () => _openItem(focusedItem),
      onOpenSelection: () => showCarouselSelectionSheet(
        context,
        onItemTap: (item) async {
          if (onReaderWithoutPdfId) {
            await _replaceReaderWithCarouselItem(item);
          } else {
            await _openItem(item);
          }
        },
      ),
    );
  }

  Widget _buildReaderMode(
    String materialId, {
    required bool showActivePlaylistName,
    required bool showLabels,
    required double barWidth,
  }) {
    final position = ref.watch(readerCarouselPositionProvider(materialId));
    final item = _itemForMaterialId(materialId, _readerTitulo);
    final loading = _carouselNavLoading;

    if (position == null) {
      return _buildNavigatorBar(
        item: item,
        canGoPrevious: false,
        canGoNext: false,
        loading: loading,
        showActivePlaylistName: showActivePlaylistName,
        showLabels: showLabels,
        barWidth: barWidth,
        onOpenSelection: _openReaderSelectionSheet,
      );
    }

    return _buildNavigatorBar(
      item: item,
      canGoPrevious: position.canGoPrevious,
      canGoNext: position.canGoNext,
      loading: loading,
      showActivePlaylistName: showActivePlaylistName,
      showLabels: showLabels,
      barWidth: barWidth,
      onPrevious: position.canGoPrevious
          ? () => _navigateCarouselInReader(
              direction: CarouselReaderDirection.previous,
              position: position,
            )
          : null,
      onNext: position.canGoNext
          ? () => _navigateCarouselInReader(
              direction: CarouselReaderDirection.next,
              position: position,
            )
          : null,
      onOpenSelection: _openReaderSelectionSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // C11: a chip do nome da lista ativa some abaixo disto — a chip do
        // louvor tem prioridade na largura da barra.
        final showActivePlaylistName =
            constraints.maxWidth >= _activePlaylistNameMinWidth;
        // Legendas sob os ícones só cabem em barra larga (spec D3).
        final showLabels = constraints.maxWidth >= carouselBarLabelsMinWidth;

        if (_isReaderRoute) {
          final materialId = _readerMaterialId;
          if (materialId != null) {
            return _buildReaderMode(
              materialId,
              showActivePlaylistName: showActivePlaylistName,
              showLabels: showLabels,
              barWidth: constraints.maxWidth,
            );
          }
        }

        return _buildShellMode(
          showActivePlaylistName: showActivePlaylistName,
          showLabels: showLabels,
          barWidth: constraints.maxWidth,
        );
      },
    );
  }
}

/// Largura mínima da barra para mostrar [ActivePlaylistNameChip] (spec B.3).
const _activePlaylistNameMinWidth = 480.0;
