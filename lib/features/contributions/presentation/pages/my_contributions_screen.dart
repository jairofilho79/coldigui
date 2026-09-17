import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/contribution_kind.dart';
import '../providers/my_contributions_provider.dart';
import '../widgets/contribution_status_chip.dart';
import '../widgets/sign_in_to_contribute.dart';

/// «Minhas contribuições» (spec §6.4): histórico paginado por cursor dos
/// envios do usuário — sub-página da branch Perfil (sem `Scaffold`/`AppBar`
/// próprio, igual `FavoriteMaterialKindsScreen`: o chrome vem do `ShellScaffold`).
class MyContributionsScreen extends ConsumerStatefulWidget {
  const MyContributionsScreen({super.key});

  @override
  ConsumerState<MyContributionsScreen> createState() =>
      _MyContributionsScreenState();
}

class _MyContributionsScreenState extends ConsumerState<MyContributionsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  /// Dispara `loadMore()` perto do fim da lista — fora do `build`, então o
  /// pedido de rede não corre durante a construção de outro widget.
  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    final current = ref.read(myContributionsProvider).value;
    if (current == null || current.nextCursor == null || current.loadingMore) {
      return;
    }
    // Falha na próxima página é silenciosa aqui: `loadMore()` já reverte
    // `loadingMore` e mantém os itens carregados; o próximo scroll tenta de
    // novo sozinho.
    unawaited(
      ref.read(myContributionsProvider.notifier).loadMore().catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      return const Center(child: SignInToContribute());
    }

    final async = ref.watch(myContributionsProvider);
    return async.when(
      data: (state) => _buildBody(context, l10n, state),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _buildError(l10n),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(myContributionsProvider.notifier).refresh(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    MyContributionsState state,
  ) {
    Future<void> onRefresh() =>
        ref.read(myContributionsProvider.notifier).refresh();

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          controller: _scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.myContributionsEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.items.length + (state.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final c = state.items[index];
          return ListTile(
            title: Text(
              c.title,
              style: AppTypography.body.copyWith(color: AppColors.textLight),
            ),
            subtitle: Text(
              '${_kindLabel(l10n, c.kind)} · ${_formatDate(c.createdAt)}',
              style: AppTypography.body.copyWith(
                color: AppColors.textLight.withValues(alpha: 0.7),
              ),
            ),
            trailing: ContributionStatusChip(status: c.status),
            onTap: () => context.push('${RoutePaths.myContributions}/${c.id}'),
          );
        },
      ),
    );
  }
}

/// Espelha `_kindLabel` de `contribution_kind_chips.dart` — privado lá, não
/// vale a pena publicar só para isto.
String _kindLabel(AppLocalizations l10n, ContributionKind kind) =>
    switch (kind) {
      ContributionKind.bug => l10n.contributeKindBug,
      ContributionKind.wrongInfo => l10n.contributeKindWrongInfo,
      ContributionKind.content => l10n.contributeKindContent,
      ContributionKind.improvement => l10n.contributeKindImprovement,
      ContributionKind.other => l10n.contributeKindOther,
    };

/// `dd/MM/yyyy` em hora local — mesmo padrão sem `intl` de
/// `formatLeafletHeaderDate`.
String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
