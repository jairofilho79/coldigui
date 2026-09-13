import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_playlist_name_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_audio_face_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Barra global de seleção temporária (UC-05 / UC-11) exibida no [ShellScaffold].
///
/// Única instância compartilhada em todas as rotas do shell, inclusive `/leitor`
/// e `/audio`.
///
/// **Face PDF:** chips das entradas não-áudio da lista ativa
/// ([carouselItemsProvider]).
/// **Face áudio:** [CarouselAudioFaceBar] quando há sessão ou entradas de
/// áudio na lista ativa ([audioCarouselItemsProvider]).
///
/// Retorna [SizedBox.shrink] quando não há PDFs nem áudio relevante.
///
/// Monta também o listener de "Seguir o áudio"
/// ([listenAudioFollowReader]) — é o único widget presente em todas as rotas
/// do shell, inclusive quando a barra não desenha nada.
class CarouselChips extends ConsumerWidget {
  const CarouselChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenAudioFollowReader(ref, context);

    final pdfItems = ref.watch(carouselItemsProvider);
    final audioItems = ref.watch(audioCarouselItemsProvider);
    final face = ref.watch(playlistMediaFaceProvider);
    // Só isto: a barra é montada em toda rota do shell e não pode reconstruir
    // a ~5 Hz com o resto do estado da sessão (posição, agora num provider
    // separado — A7).
    final hasSessionQueue = ref.watch(
      audioPlayerSessionProvider.select((s) => s.queue.isNotEmpty),
    );
    final hasPdf = pdfItems.isNotEmpty;

    if (!shouldShowCarouselAudioFace(
      face: face,
      hasPdf: hasPdf,
      hasAudio: audioItems.isNotEmpty || hasSessionQueue,
    )) {
      if (!hasPdf) return const SizedBox.shrink();
      return _CarouselChipsBar(items: pdfItems);
    }
    return const CarouselAudioFaceBar();
  }
}

/// As duas faces são filtros da mesma lista (B.1): a face de áudio aparece
/// quando o usuário a escolheu e há áudio, ou quando não há **nada** na face de
/// partituras para mostrar no lugar dela.
///
/// [hasAudio] junta as duas origens de áudio — fila da sessão e entradas de
/// áudio da lista ativa. Após [AudioPlayerSessionNotifier.close] (fila vazia) a
/// barra continua na face de partituras enquanto houver PDF nela.
///
/// Pública (não só `@visibleForTesting`): também decide, em [ShellScaffold],
/// se a face de áudio já cobre os controles do mini-player (D5) — o
/// mini-player só aparece quando esta função devolve `false`.
bool shouldShowCarouselAudioFace({
  required PlaylistMediaFace face,
  required bool hasPdf,
  required bool hasAudio,
}) {
  if (!hasPdf && !hasAudio) return false;
  if (face == PlaylistMediaFace.audio) return hasAudio;
  return hasAudio && !hasPdf;
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

  void _onReaderRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_isReaderRoute) {
        _lastSyncedReaderMaterialId = null;
        ref.read(readerRouteParamsProvider.notifier).clear();
        return;
      }

      final materialId = _resolveReaderMaterialId(readOnly: true);
      if (materialId != _lastSyncedReaderMaterialId) {
        setState(() {
          _lastSyncedReaderMaterialId = materialId;
          _carouselNavLoading = false;
          _openingReader = false;
        });
      }

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
              'O PDF foi removido do dispositivo. Conecte-se ou use '
                  'Configurações Offline → Baixar faltantes.',
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
    required double barWidth,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onChipTap,
    required VoidCallback onOpenSelection,
    VoidCallback? onOpenPlayer,
  }) {
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
              loading: loading,
              onPrevious: onPrevious,
              onNext: onNext,
              onChipTap: onChipTap,
              onOpenPlayer: onOpenPlayer,
              onOpenSelection: onOpenSelection,
              swapMaterial: CarouselSwapMaterialButton(
                materialId: item.materialId,
                entryKey: item.key,
              ),
              trailingActions: const [CarouselBarTrailingActions()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShellMode({
    required bool showActivePlaylistName,
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
      onChipTap: onReaderWithoutPdfId ? null : () => _openInReader(focusedItem),
      onOpenPlayer: onReaderWithoutPdfId
          ? null
          : () => _openInReader(focusedItem),
      onOpenSelection: () => showCarouselSelectionSheet(
        context,
        onItemTap: (item) async {
          if (onReaderWithoutPdfId) {
            await _replaceReaderWithCarouselItem(item);
          } else {
            await _openInReader(item);
          }
        },
      ),
    );
  }

  Widget _buildReaderMode(
    String materialId, {
    required bool showActivePlaylistName,
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

        if (_isReaderRoute) {
          final materialId = _readerMaterialId;
          if (materialId != null) {
            return _buildReaderMode(
              materialId,
              showActivePlaylistName: showActivePlaylistName,
              barWidth: constraints.maxWidth,
            );
          }
        }

        return _buildShellMode(
          showActivePlaylistName: showActivePlaylistName,
          barWidth: constraints.maxWidth,
        );
      },
    );
  }
}

/// Largura mínima da barra para mostrar [ActivePlaylistNameChip] (spec B.3).
const _activePlaylistNameMinWidth = 480.0;
