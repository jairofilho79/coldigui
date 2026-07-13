import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../domain/entities/playlist_tab.dart';
import '../providers/playlist_sync_lifecycle.dart';
import '../providers/playlist_sync_provider.dart';
import '../providers/playlists_provider.dart';
import '../providers/playlists_ui_provider.dart';
import '../widgets/import_playlist_dialog.dart';
import '../widgets/playlist_list_tile.dart';

/// UC-06/07 — Gestão de playlists com abas [PlaylistTab] (Fase 4.8 + UC-15 sync).
///
/// **Layout (polish jun/2026):** [TabBar] sobre fundo creme; lista ou estado vazio
/// com texto [AppColors.textLight] (contraste no [AppColors.background] do scaffold).
/// **FAB stack:** [FloatingActionButton.extended] importar (sempre visível); na aba
/// `unsaved`, [FloatingActionButton.small] branco (`heroTag: playlist-delete-all-unsaved`,
/// `Icons.delete_sweep_outlined`) 12px acima — tooltip [playlistDeleteAllUnsaved].
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        PlaylistSyncLifecycleMixin {
  late final TabController _tabController;
  final _tileKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    startPlaylistSyncLifecycle();
  }

  @override
  void dispose() {
    stopPlaylistSyncLifecycle();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = PlaylistTab.values[_tabController.index];
    ref.read(playlistsUiProvider.notifier).selectTab(tab);
  }

  void _syncTabFromProvider(PlaylistsUiState ui) {
    final index = ui.tab.index;
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
    final scrollId = ui.scrollToPlaylistId;
    if (scrollId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _tileKeys[scrollId];
        final context = key?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
        ref.read(playlistsUiProvider.notifier).clearScrollTarget();
      });
    }
  }

  GlobalKey _keyFor(String playlistId) =>
      _tileKeys.putIfAbsent(playlistId, GlobalKey.new);

  String _emptyMessage(AppLocalizations l10n, PlaylistTab tab) {
    return switch (tab) {
      PlaylistTab.unsaved => l10n.playlistEmptyUnsaved,
      PlaylistTab.saved => l10n.playlistEmptySaved,
      PlaylistTab.favorites => l10n.playlistEmptyFavorites,
    };
  }

  Future<void> _importPlaylist(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showImportPlaylistDialog(context);
    if (result == null || !context.mounted) return;

    final carouselItems = ref.read(carouselLouvoresProvider);
    if (carouselItems.isNotEmpty) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: l10n.playlistLoadConfirmTitle,
        message: l10n.playlistLoadConfirmMessage,
      );
      if (confirmed != true || !context.mounted) return;
    }

    final playlistId = await ref
        .read(playlistsProvider.notifier)
        .importSharedFromUrl(
          sharePdfs: result.sharePdfs,
          shareName: result.shareName,
        );
    if (!context.mounted) return;

    if (playlistId == null) {
      showAppSnackbar(context, l10n.playlistImportInvalidUrl);
      return;
    }

    ref.read(playlistsUiProvider.notifier).selectTab(PlaylistTab.saved);
    showAppSnackbar(context, l10n.playlistImported);
  }

  Future<void> _deleteAllUnsaved(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.playlistDeleteAllUnsavedTitle,
      message: l10n.playlistDeleteAllUnsavedMessage,
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(playlistsProvider.notifier).deleteAllUnsaved();
    if (context.mounted) {
      showAppSnackbar(context, l10n.playlistDeleteAllUnsavedDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(playlistsProvider);
    final ui = ref.watch(playlistsUiProvider);
    final syncing = ref.watch(playlistSyncProvider).isSyncing;
    ref.listen(playlistsUiProvider, (_, next) => _syncTabFromProvider(next));

    final currentTab = ui.tab;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentTab == PlaylistTab.unsaved)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'playlist-delete-all-unsaved',
                tooltip: l10n.playlistDeleteAllUnsaved,
                backgroundColor: AppColors.textLight,
                foregroundColor: AppColors.title,
                onPressed: () => _deleteAllUnsaved(context),
                child: const Icon(Icons.delete_sweep_outlined),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'playlist-import',
            onPressed: () => _importPlaylist(context),
            icon: const Icon(Icons.download),
            label: Text(l10n.playlistImport),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.playlistTabUnsaved),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.playlistTabSaved),
                      if (syncing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(text: l10n.playlistTabFavorites),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: PlaylistTab.values
                  .map((tab) {
                    final items = ref
                        .read(playlistsProvider.notifier)
                        .itemsForTab(tab);
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _emptyMessage(l10n, tab),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textLight),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return PlaylistListTile(
                          key: _keyFor(item.playlist.playlistId),
                          item: item,
                          tab: tab,
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}
