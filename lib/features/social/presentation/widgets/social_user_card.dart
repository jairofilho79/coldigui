import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/social/domain/entities/public_playlist.dart';
import 'package:coldigui/features/social/domain/entities/social_user.dart';
import 'package:coldigui/features/social/presentation/providers/social_search_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card expansível de usuário social (visual próximo aos cards de louvor).
class SocialUserCard extends ConsumerStatefulWidget {
  const SocialUserCard({required this.user, super.key});

  final SocialUser user;

  @override
  ConsumerState<SocialUserCard> createState() => _SocialUserCardState();
}

class _SocialUserCardState extends ConsumerState<SocialUserCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: AppColors.shadowMd,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.gold.withValues(
                            alpha: 0.25,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.title,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${widget.user.username}',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 16,
                                  color: AppColors.title,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.socialPlaylistCount(
                                  widget.user.playlistCount,
                                ),
                                style: AppTypography.label.copyWith(
                                  fontSize: 12,
                                  color: AppColors.title.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.title.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _ExpandedPlaylists(username: widget.user.username),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlaylists extends ConsumerWidget {
  const _ExpandedPlaylists({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(socialUserPlaylistsProvider(username));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.gold.withValues(alpha: 0.35),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.socialPlaylistsError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (playlists) {
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.socialPlaylistsEmpty),
              );
            }
            final groups = _groupByCategory(playlists);
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                      child: Text(
                        _categoryLabel(l10n, entry.key),
                        style: AppTypography.label.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.title.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    for (final playlist in entry.value)
                      _PublicPlaylistTile(playlist: playlist),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static Map<PlaylistCategory?, List<PublicPlaylist>> _groupByCategory(
    List<PublicPlaylist> playlists,
  ) {
    final map = <PlaylistCategory?, List<PublicPlaylist>>{};
    for (final category in PlaylistCategory.values) {
      final items = playlists
          .where((p) => p.publicationCategory == category)
          .toList(growable: false);
      if (items.isNotEmpty) map[category] = items;
    }
    final unknown = playlists
        .where((p) => p.publicationCategory == null)
        .toList(growable: false);
    if (unknown.isNotEmpty) map[null] = unknown;
    return map;
  }

  static String _categoryLabel(
    AppLocalizations l10n,
    PlaylistCategory? category,
  ) {
    return switch (category) {
      PlaylistCategory.evangelizacao => l10n.playlistCategoryEvangelizacao,
      PlaylistCategory.aprendizado => l10n.playlistCategoryAprendizado,
      PlaylistCategory.medleys => l10n.playlistCategoryMedleys,
      PlaylistCategory.cultoEspecial => l10n.playlistCategoryCultoEspecial,
      null => l10n.socialCategoryOther,
    };
  }
}

class _PublicPlaylistTile extends ConsumerStatefulWidget {
  const _PublicPlaylistTile({required this.playlist});

  final PublicPlaylist playlist;

  @override
  ConsumerState<_PublicPlaylistTile> createState() =>
      _PublicPlaylistTileState();
}

class _PublicPlaylistTileState extends ConsumerState<_PublicPlaylistTile> {
  var _loading = false;

  Future<void> _import() async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final notifier = ref.read(playlistsProvider.notifier);
      var added = 0;
      for (final pdfId in widget.playlist.pdfIds) {
        final ok = await notifier.addLouvorToActivePlaylist(pdfId);
        if (ok) added++;
      }
      if (!mounted) return;
      showAppSnackbar(
        context,
        added > 0
            ? l10n.socialPlaylistImported(added)
            : l10n.socialPlaylistImportNone,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.playlist.pdfIds.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.btnBackground.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _loading ? null : _import,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.playlist_add, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.nome,
                        style: AppTypography.body.copyWith(
                          color: AppColors.title,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AppLocalizations.of(context)!.playlistPdfCount(count),
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          color: AppColors.title.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                else
                  Icon(
                    Icons.add_circle_outline,
                    color: AppColors.title.withValues(alpha: 0.55),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
