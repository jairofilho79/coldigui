import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/find_material_for_group.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_display_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_audio_face_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_shell.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_trailing_actions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_navigator_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_hydrate.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Barra global de seleção temporária (UC-05 / UC-11) exibida no [ShellScaffold].
///
/// Única instância compartilhada em todas as rotas do shell, inclusive `/leitor`
/// e `/audio`.
///
/// **Face PDF:** chips do carousel Isar (como antes).
/// **Face áudio:** [CarouselAudioFaceBar] quando há sessão/playlist de áudio.
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

    final pdfItems = ref.watch(carouselLouvoresDisplayProvider);
    final face = ref.watch(playlistMediaFaceProvider);
    // Só isto: a barra é montada em toda rota do shell e não pode reconstruir
    // a ~5 Hz com o resto do estado da sessão (posição, agora num provider
    // separado — A7).
    final hasSession = ref.watch(
      audioPlayerSessionProvider.select((s) => s.queue.isNotEmpty),
    );
    final hasAudioPlaylist = _activeHasAudioIds(ref);
    final hasPdf = pdfItems.isNotEmpty;

    if (!shouldShowCarouselAudioFace(
      face: face,
      hasPdf: hasPdf,
      hasSessionQueue: hasSession,
      hasAudioPlaylist: hasAudioPlaylist,
    )) {
      if (!hasPdf) return const SizedBox.shrink();
      return _CarouselChipsBar(items: pdfItems);
    }
    return const CarouselAudioFaceBar();
  }

  bool _activeHasAudioIds(WidgetRef ref) {
    final activeId = ref.watch(activePlaylistIdProvider);
    if (activeId == null) return false;
    for (final item in ref.watch(playlistsProvider)) {
      if (item.playlist.playlistId == activeId) {
        return item.playlist.audioIds.isNotEmpty;
      }
    }
    return false;
  }
}

/// Após [AudioPlayerSessionNotifier.close] (fila vazia + face PDF) não força
/// áudio só por `audioIds`. Face áudio só com sessão ou playlist de áudio.
@visibleForTesting
bool shouldShowCarouselAudioFace({
  required PlaylistMediaFace face,
  required bool hasPdf,
  required bool hasSessionQueue,
  required bool hasAudioPlaylist,
}) {
  final hasAudio = hasSessionQueue || hasAudioPlaylist;
  if (!hasPdf && !hasAudio) return false;
  if (face == PlaylistMediaFace.audio) return hasAudio;
  return hasSessionQueue && !hasPdf;
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
  String? _lastSyncedReaderPdfId;

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
        _lastSyncedReaderPdfId = null;
        ref.read(readerRouteParamsProvider.notifier).clear();
        return;
      }

      final pdfId = _resolveReaderPdfId(readOnly: true);
      if (pdfId != _lastSyncedReaderPdfId) {
        setState(() {
          _lastSyncedReaderPdfId = pdfId;
          _carouselNavLoading = false;
          _openingReader = false;
        });
      }

      if (pdfId != null) {
        ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(pdfId);
      }
    });
  }

  GoRouterState? get _routerState {
    final router = GoRouter.maybeOf(context);
    return router == null ? null : GoRouterState.of(context);
  }

  bool get _isReaderRoute {
    final path = _routerState?.uri.path;
    return path == RoutePaths.reader || path == RoutePaths.chords;
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

  String? _resolveReaderPdfId({required bool readOnly}) {
    final pdfId = _readerRouteParams(readOnly: readOnly)[UrlSyncParams.pdfId];
    if (pdfId != null && pdfId.isNotEmpty) return pdfId;

    if (!_isReaderRoute || items.isEmpty) return null;
    final focusedIndex =
        (readOnly
                ? ref.read(carouselFocusedIndexProvider)
                : ref.watch(carouselFocusedIndexProvider))
            .clamp(0, items.length - 1);
    return items[focusedIndex].pdfId;
  }

  String? get _readerPdfId => _resolveReaderPdfId(readOnly: false);

  String get _readerTitulo {
    final titulo = _readerRouteParams(readOnly: false)[UrlSyncParams.titulo];
    if (titulo != null && titulo.isNotEmpty) return titulo;
    final pdfId = _readerPdfId;
    if (pdfId == null) return '';
    return _itemForPdfId(pdfId, '').nome;
  }

  CarouselItem _itemForPdfId(String pdfId, String titulo) {
    for (final item in items) {
      if (item.pdfId == pdfId) return item;
    }
    return CarouselItem(
      pdfId: pdfId,
      sortOrder: 0,
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
        pdfId: item.pdfId,
        navigate: (location) async {
          context.push(location);
        },
      );
      if (!mounted) return;
      ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(item.pdfId);
    } finally {
      if (mounted) setState(() => _openingReader = false);
    }
  }

  Future<void> _handleCarouselItemRemoved(String removedPdfId) async {
    final currentPdfId = _readerPdfId;
    if (currentPdfId == null || removedPdfId != currentPdfId) return;

    final remaining = ref.read(carouselLouvoresProvider);
    if (!mounted) return;

    if (remaining.isEmpty) {
      context.pop();
      return;
    }

    setState(() => _carouselNavLoading = true);
    try {
      final location = await ref
          .read(readerCarouselActionsProvider.notifier)
          .navigateToPdfId(targetPdfId: remaining.first.pdfId);
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
      onItemTap: (selected) =>
          _replaceReaderWithCarouselItem(selectedPdfId: selected.pdfId),
    );
  }

  Future<void> _replaceReaderWithCarouselItem({
    required String selectedPdfId,
    String? currentPdfId,
  }) async {
    final activePdfId = currentPdfId ?? _resolveReaderPdfId(readOnly: true);
    if (activePdfId != null && selectedPdfId == activePdfId) return;
    if (_carouselNavLoading) return;

    setState(() => _carouselNavLoading = true);
    try {
      await openCarouselPdfInReader(
        ref: ref,
        context: context,
        pdfId: selectedPdfId,
        navigate: (location) async {
          context.replace(location);
        },
      );
      if (!mounted) return;
      ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(selectedPdfId);
    } finally {
      if (mounted) setState(() => _carouselNavLoading = false);
    }
  }

  Future<void> _navigateCarouselInReader({
    required CarouselReaderDirection direction,
    required CarouselReaderPosition position,
  }) async {
    if (_carouselNavLoading) return;

    final targetPdfId = switch (direction) {
      CarouselReaderDirection.previous => position.previousPdfId,
      CarouselReaderDirection.next => position.nextPdfId,
    };
    if (targetPdfId == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _carouselNavLoading = true);

    try {
      ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(targetPdfId);

      final location = await ref
          .read(readerCarouselActionsProvider.notifier)
          .navigateToPdfId(targetPdfId: targetPdfId);
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
    } on PdfExternallyDeletedException catch (e) {
      if (mounted) showAppSnackbar(context, e.message);
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

  /// Faixas de áudio do louvor de [pdfId] (PDF ou cifra) no acervo.
  List<AudioTrack> _groupTracksForPdfId(String pdfId) {
    final groupId = groupIdForMaterialId(
      materialId: pdfId,
      byPdfId: ref.watch(coldigomLouvoresCacheProvider),
      chordsById: ref.watch(coldigomChordMaterialsCacheProvider),
      catalog: ref.watch(louvoresManifestProvider).value?.louvores ?? const [],
    );
    if (groupId == null) return const [];
    return tracksForGroup(
      groupId,
      ref.watch(coldigomAudioTracksCacheProvider).values.toList(),
    );
  }

  /// Faixas da lista ativa, na ordem salva (vazio sem playlist de áudio).
  List<AudioTrack> _activePlaylistTracks() {
    final activeId = ref.read(activePlaylistIdProvider);
    if (activeId == null) return const [];
    for (final item in ref.read(playlistsProvider)) {
      if (item.playlist.playlistId == activeId) {
        return tracksForAudioIds(
          item.playlist.audioIds,
          ref.read(coldigomAudioTracksCacheProvider),
        );
      }
    }
    return const [];
  }

  /// Toca o áudio do louvor aberto no leitor (D10 — o slot morto da barra 2).
  ///
  /// Fila = áudios da lista ativa quando ela já contém a faixa; senão só os do
  /// louvor. Começa sempre na faixa preferida do grupo ([findAudioForGroup]).
  Future<void> _playGroupAudio(List<AudioTrack> groupTracks) async {
    if (groupTracks.isEmpty) return;
    final target = findAudioForGroup(groupTracks.first.groupId, groupTracks);
    if (target == null) return;

    final playlistTracks = _activePlaylistTracks();
    final queue = playlistTracks.any((t) => t.audioId == target.audioId)
        ? playlistTracks
        : groupTracks;

    await playAudioInSession(ref: ref, track: target, queue: queue);
  }

  Widget _buildNavigatorBar({
    required CarouselItem item,
    required bool canGoPrevious,
    required bool canGoNext,
    required bool loading,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onChipTap,
    required VoidCallback onOpenSelection,
    VoidCallback? onOpenPlayer,
    IconData openPlayerIcon = Icons.open_in_full,
    String? openPlayerTooltip,
  }) {
    return CarouselBarShell(
      applySafeArea: false,
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
        openPlayerIcon: openPlayerIcon,
        openPlayerTooltip: openPlayerTooltip,
        onOpenSelection: onOpenSelection,
        swapMaterial: CarouselSwapMaterialButton(pdfId: item.pdfId),
        trailingActions: const [CarouselBarTrailingActions()],
      ),
    );
  }

  Widget _buildShellMode() {
    final sourceItems = ref.read(carouselLouvoresProvider);
    final focusedIndex = ref.watch(carouselFocusedIndexProvider);
    final safeSourceIndex = focusedIndex.clamp(0, sourceItems.length - 1);
    final focusedPdfId = sourceItems[safeSourceIndex].pdfId;
    final displayIndex = items.indexWhere((item) => item.pdfId == focusedPdfId);
    final focusedItem =
        items[displayIndex >= 0
            ? displayIndex
            : safeSourceIndex.clamp(0, items.length - 1)];
    final onReaderWithoutPdfId = _isReaderRoute;

    // No leitor sem `pdfId` na URL o slot "abrir" também era morto (D10).
    final groupTracks = onReaderWithoutPdfId
        ? _groupTracksForPdfId(focusedPdfId)
        : const <AudioTrack>[];

    return _buildNavigatorBar(
      item: focusedItem,
      canGoPrevious: safeSourceIndex > 0,
      canGoNext: safeSourceIndex < sourceItems.length - 1,
      loading: _openingReader || _carouselNavLoading,
      onPrevious: onReaderWithoutPdfId
          ? (safeSourceIndex > 0
                ? () => _replaceReaderWithCarouselItem(
                    selectedPdfId: sourceItems[safeSourceIndex - 1].pdfId,
                  )
                : null)
          : () => ref.read(carouselFocusedIndexProvider.notifier).goPrevious(),
      onNext: onReaderWithoutPdfId
          ? (safeSourceIndex < sourceItems.length - 1
                ? () => _replaceReaderWithCarouselItem(
                    selectedPdfId: sourceItems[safeSourceIndex + 1].pdfId,
                  )
                : null)
          : () => ref.read(carouselFocusedIndexProvider.notifier).goNext(),
      onChipTap: onReaderWithoutPdfId ? null : () => _openInReader(focusedItem),
      onOpenPlayer: onReaderWithoutPdfId
          ? (groupTracks.isEmpty
                ? null
                : () => unawaited(_playGroupAudio(groupTracks)))
          : () => _openInReader(focusedItem),
      openPlayerIcon: onReaderWithoutPdfId
          ? Icons.play_circle_outline
          : Icons.open_in_full,
      openPlayerTooltip: onReaderWithoutPdfId
          ? AppLocalizations.of(context)?.carouselPlayGroupAudio
          : null,
      onOpenSelection: () => showCarouselSelectionSheet(
        context,
        onItemTap: (item) async {
          if (onReaderWithoutPdfId) {
            await _replaceReaderWithCarouselItem(selectedPdfId: item.pdfId);
          } else {
            await _openInReader(item);
          }
        },
      ),
    );
  }

  Widget _buildReaderMode(String pdfId) {
    final position = ref.watch(readerCarouselPositionProvider(pdfId));
    final item = _itemForPdfId(pdfId, _readerTitulo);
    final loading = _carouselNavLoading;

    // D10: no leitor o slot "abrir" tocava nada — vira "tocar áudio deste
    // louvor" e some quando o louvor não tem áudio.
    final groupTracks = _groupTracksForPdfId(pdfId);
    final playAudio = groupTracks.isEmpty
        ? null
        : () => unawaited(_playGroupAudio(groupTracks));
    final playAudioTooltip = AppLocalizations.of(
      context,
    )?.carouselPlayGroupAudio;

    if (position == null) {
      return _buildNavigatorBar(
        item: item,
        canGoPrevious: false,
        canGoNext: false,
        loading: loading,
        onOpenSelection: _openReaderSelectionSheet,
        onOpenPlayer: playAudio,
        openPlayerIcon: Icons.play_circle_outline,
        openPlayerTooltip: playAudioTooltip,
      );
    }

    return _buildNavigatorBar(
      item: item,
      canGoPrevious: position.canGoPrevious,
      canGoNext: position.canGoNext,
      loading: loading,
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
      onOpenPlayer: playAudio,
      openPlayerIcon: Icons.play_circle_outline,
      openPlayerTooltip: playAudioTooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isReaderRoute) {
      final pdfId = _readerPdfId;
      if (pdfId != null) {
        return _buildReaderMode(pdfId);
      }
    }

    return _buildShellMode();
  }
}
