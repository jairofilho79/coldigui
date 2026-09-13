import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../coldigom/data/models/praise_dto.dart';
import '../../domain/entities/material_kind_prefs.dart';
import '../providers/coldigom_material_kinds_provider.dart';
import '../providers/material_kind_prefs_provider.dart';
import '../providers/material_kind_prefs_sync_provider.dart';

/// «Materiais favoritos»: até [kMaxFavoriteMaterialKinds] material kinds
/// Coldigom em ordem de preferência. Salva a cada mudança — sem botão.
///
/// Deslogado vê só o convite para entrar (a preferência é da conta), mas a
/// rota existe para quem chega por URL.
class FavoriteMaterialKindsScreen extends ConsumerStatefulWidget {
  const FavoriteMaterialKindsScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  ConsumerState<FavoriteMaterialKindsScreen> createState() =>
      _FavoriteMaterialKindsScreenState();
}

class _FavoriteMaterialKindsScreenState
    extends ConsumerState<FavoriteMaterialKindsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> kindIds) {
    return ref.read(materialKindPrefsProvider.notifier).save(kindIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoriteMaterialKindsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FavoriteMaterialKindsScreen._maxContentWidth,
          ),
          child: user == null ? _signedOut(l10n) : _signedIn(l10n),
        ),
      ),
    );
  }

  Widget _signedOut(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            l10n.favoriteMaterialKindsSignInPrompt,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          const GoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _signedIn(AppLocalizations l10n) {
    final prefsAsync = ref.watch(materialKindPrefsProvider);
    final kindsAsync = ref.watch(coldigomMaterialKindsProvider);
    final syncState = ref.watch(materialKindPrefsSyncProvider);
    final prefs = prefsAsync.asData?.value ?? MaterialKindPrefs.empty;
    final kinds = kindsAsync.asData?.value ?? const <ColdigomMaterialKindDto>[];
    final labels = {for (final kind in kinds) kind.id: kind.name};
    final chosen = prefs.kindIds;
    final full = chosen.length >= kMaxFavoriteMaterialKinds;
    final normalizedQuery = LouvorSearchTokens.normalize(_query);
    final candidates = [
      for (final kind in kinds)
        if (!chosen.contains(kind.id) &&
            (normalizedQuery.isEmpty ||
                LouvorSearchTokens.normalize(
                  kind.name,
                ).contains(normalizedQuery)))
          kind,
    ];
    final showSyncPending =
        prefs.pendingPush || syncState.lastErrorCause != null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              Text(
                l10n.favoriteMaterialKindsHelp(kMaxFavoriteMaterialKinds),
                style: AppTypography.body.copyWith(color: AppColors.textDark),
              ),
              if (showSyncPending) ...[
                const SizedBox(height: 8),
                Text(
                  syncState.lastErrorCause == null
                      ? l10n.favoriteMaterialKindsSyncPending
                      : '${l10n.favoriteMaterialKindsSyncPending} — '
                            '${userMessageFor(l10n, syncState.lastErrorCause!)}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _sectionLabel(
                l10n.favoriteMaterialKindsYours(
                  chosen.length,
                  kMaxFavoriteMaterialKinds,
                ),
              ),
              if (chosen.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.favoriteMaterialKindsEmpty,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: chosen.length,
            // `onReorderItem` (não o `onReorder` obsoleto) já entrega
            // `newIndex` ajustado para a lista sem o item removido.
            onReorderItem: (oldIndex, newIndex) {
              final next = [...chosen];
              final moved = next.removeAt(oldIndex);
              next.insert(newIndex, moved);
              _save(next);
            },
            // `SliverReorderableList` solta o item arrastado numa
            // `OverlayEntry`, fora da árvore do `Scaffold` — sem isso, o
            // `ListTile` do item flutuante quebra por falta de ancestral
            // `Material` (mesmo problema resolvido em
            // `carouselSelectionReorderProxyDecorator`).
            proxyDecorator: (child, index, animation) {
              return Material(
                color: AppColors.card,
                elevation: 4,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final id = chosen[index];
              return ListTile(
                key: ValueKey('fav-$id'),
                leading: Text(
                  '${index + 1}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                title: Text(
                  labels[id] ?? l10n.favoriteMaterialKindsUnknownKind,
                  style: AppTypography.body.copyWith(color: AppColors.textDark),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.favoriteMaterialKindsRemoveTooltip,
                      color: AppColors.title,
                      onPressed: () => _save([...chosen]..removeAt(index)),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_handle,
                        color: AppColors.title,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              _sectionLabel(l10n.favoriteMaterialKindsAdd),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.favoriteMaterialKindsLimitReached(
                      kMaxFavoriteMaterialKinds,
                    ),
                    style: AppTypography.label.copyWith(color: AppColors.title),
                  ),
                ),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.favoriteMaterialKindsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              if (kindsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (kindsAsync.hasError)
                ListTile(
                  leading: const Icon(Icons.refresh, color: AppColors.title),
                  title: Text(l10n.favoriteMaterialKindsLoadError),
                  subtitle: Text(l10n.favoriteMaterialKindsRetry),
                  onTap: () => ref.invalidate(coldigomMaterialKindsProvider),
                ),
              if (kindsAsync.hasValue && candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.favoriteMaterialKindsNoMatch,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final kind = candidates[index];
              return ListTile(
                key: ValueKey('cand-${kind.id}'),
                title: Text(
                  kind.name,
                  style: AppTypography.body.copyWith(color: AppColors.textDark),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.favoriteMaterialKindsAddTooltip,
                  color: AppColors.title,
                  onPressed: full ? null : () => _save([...chosen, kind.id]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
