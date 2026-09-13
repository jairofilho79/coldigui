import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/louvor_search_tokens.dart';
import '../../../../core/widgets/golden_tagged_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../coldigom/data/models/praise_dto.dart';
import '../../domain/entities/material_kind_prefs.dart';
import '../providers/coldigom_material_kinds_provider.dart';
import '../providers/material_kind_prefs_provider.dart';
import '../providers/material_kind_prefs_sync_provider.dart';
import '../widgets/material_kind_card.dart';

/// «Materiais favoritos»: até [kMaxFavoriteMaterialKinds] material kinds
/// Coldigom em ordem de preferência. Salva a cada mudança — sem botão.
///
/// Sub-página do Perfil como Sobre/Offline: sem `Scaffold`/`AppBar` próprio
/// (o header e a seta de voltar vêm do [ShellScaffold]/[PlpcgPrimaryAppBar]).
/// Visual no padrão da Pesquisar: texto branco no fundo escuro, busca em
/// [GoldenTaggedContainer] e linhas como chip vinho com borda dourada
/// ([MaterialKindCard]).
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
  final _searchFocus = FocusNode();
  String _query = '';
  var _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus == _searchFocused) return;
    setState(() => _searchFocused = _searchFocus.hasFocus);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: FavoriteMaterialKindsScreen._maxContentWidth,
        ),
        child: user == null ? _signedOut(l10n) : _signedIn(l10n),
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
            style: AppTypography.body.copyWith(color: AppColors.textLight),
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
    // `.value` (não `.asData?.value`): quando o provider recarrega porque o
    // auth reemitiu (refresh de token), o Riverpod 3 entrega `AsyncLoading`
    // com o valor anterior — `asData` seria `null` e a lista colapsaria para
    // «Nenhum favorito ainda» por um frame (mesma correção do rank provider).
    final prefs = prefsAsync.value ?? MaterialKindPrefs.empty;
    final kinds = kindsAsync.asData?.value ?? const <ColdigomMaterialKindDto>[];
    final labels = {for (final kind in kinds) kind.id: kind.name};
    final chosen = prefs.kindIds;
    final full = chosen.length >= kMaxFavoriteMaterialKinds;
    final normalizedQuery = LouvorSearchTokens.normalize(_query);
    final candidates = [
      for (final kind in kinds)
        if (!chosen.contains(kind.id) &&
            (normalizedQuery.isEmpty ||
                LouvorSearchTokens.normalize(kind.name)
                    .contains(normalizedQuery)))
          kind,
    ];
    // Online, cada toque fica `pendingPush` só pelos ms até o push: a linha
    // só aparece se a rodada não está em curso (ou já falhou), senão piscaria
    // a cada edição.
    final showSyncPending =
        (prefs.pendingPush && !syncState.isSyncing) ||
        syncState.lastErrorCause != null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              Text(
                l10n.favoriteMaterialKindsHelp(kMaxFavoriteMaterialKinds),
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
              if (showSyncPending) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 16,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        syncState.lastErrorCause == null
                            ? l10n.favoriteMaterialKindsSyncPending
                            : '${l10n.favoriteMaterialKindsSyncPending} — '
                                  '${userMessageFor(l10n, syncState.lastErrorCause!)}',
                        style: _secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _sectionLabel(
                l10n.favoriteMaterialKindsYours(
                  chosen.length,
                  kMaxFavoriteMaterialKinds,
                ),
              ),
              if (chosen.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.favoriteMaterialKindsEmpty,
                    style: _secondaryText,
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
            // O item arrastado vai para uma `OverlayEntry`, fora da árvore
            // do `Scaffold`; o [MaterialKindCard] já carrega o próprio
            // `Material` e sombra, então o proxy é o card como está.
            proxyDecorator: (child, index, animation) => child,
            itemBuilder: (context, index) {
              final id = chosen[index];
              return MaterialKindCard(
                key: ValueKey('fav-$id'),
                leading: SizedBox(
                  width: 20,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
                title: labels[id] ?? l10n.favoriteMaterialKindsUnknownKind,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.favoriteMaterialKindsRemoveTooltip,
                      color: AppColors.textLight,
                      onPressed: () => _save([...chosen]..removeAt(index)),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle,
                          color: AppColors.textLight.withValues(alpha: 0.7),
                        ),
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
                    style: AppTypography.label.copyWith(
                      color: AppColors.textLight.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              _searchField(l10n),
              const SizedBox(height: 12),
              if (kindsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
              // O Riverpod 3 guarda o erro anterior durante o retry
              // automático (com backoff): `isLoading && hasError` é estado
              // real — nessa hora fica só o spinner, sem a linha de retry.
              if (kindsAsync.hasError && !kindsAsync.isLoading)
                MaterialKindCard(
                  leading: const Icon(Icons.refresh, color: AppColors.gold),
                  title: l10n.favoriteMaterialKindsLoadError,
                  subtitle: l10n.favoriteMaterialKindsRetry,
                  onTap: () => ref.invalidate(coldigomMaterialKindsProvider),
                ),
              if (kindsAsync.hasValue && candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.favoriteMaterialKindsNoMatch,
                    style: _secondaryText,
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
              return MaterialKindCard(
                key: ValueKey('cand-${kind.id}'),
                title: kind.name,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.favoriteMaterialKindsAddTooltip,
                  color: AppColors.textLight,
                  disabledColor: AppColors.textLight.withValues(alpha: 0.35),
                  onPressed: full ? null : () => _save([...chosen, kind.id]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Busca no mesmo molde da [SearchBar] da Pesquisar: caixa creme com tag,
  /// glow dourado no foco, ícone/texto vinho.
  Widget _searchField(AppLocalizations l10n) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _searchFocus.requestFocus,
      child: GoldenTaggedContainer(
        label: l10n.searchLabel,
        glowEnabled: true,
        glowActive: _searchFocused,
        contentPadding: GoldenTaggedContainer.compactContentPaddingFor(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search, color: AppColors.title, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: AppTypography.body.copyWith(height: 1.1),
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: l10n.favoriteMaterialKindsSearchHint,
                  hintStyle: AppTypography.hint(italic: true)
                      .copyWith(height: 1.1),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _secondaryText => AppTypography.body.copyWith(
    color: AppColors.textLight.withValues(alpha: 0.7),
  );

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.headline.copyWith(color: AppColors.gold),
      ),
    );
  }
}
