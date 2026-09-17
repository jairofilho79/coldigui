import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/my_contributions_provider.dart';
import '../utils/contribution_labels.dart';
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

  /// Cursor já pedido pelo gatilho de *construção* do último item (abaixo).
  /// Sem isto, uma falha na próxima página reconstrói o item final a cada
  /// rebuild (o `loadingMore` volta a `false` e o `nextCursor` não muda) e
  /// `_loadMoreFromBuild` disparava `loadMore()` de novo a cada frame — uma
  /// tempestade de pedidos, um por rebuild. Rolar a lista (`_maybeLoadMore`)
  /// continua livre para tentar de novo a qualquer momento.
  String? _requestedCursor;

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
  /// pedido de rede não corre durante a construção de outro widget. Cobre
  /// listas longas: o `ListView.builder` só constrói os itens perto do
  /// scroll atual, então o item final só existe (e o gatilho abaixo só
  /// dispara) quando o usuário rola até lá.
  ///
  /// Sempre tenta de novo (não olha `_requestedCursor`): é o único jeito de
  /// tentar de novo depois de uma falha, além do botão "tentar de novo" do
  /// estado de erro da lista inteira.
  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    _loadMore();
  }

  /// Mesmo gatilho do fim da lista, mas chamado direto do `itemBuilder` ao
  /// construir o último item — cobre listas curtas o bastante para caber
  /// inteiras no viewport (o `ListView` nunca emite notificação de scroll
  /// nesse caso, então `_maybeLoadMore` sozinho nunca dispararia).
  ///
  /// Só pede uma vez por cursor: se a página anterior falhou, o `nextCursor`
  /// não muda, e reconstruir o mesmo último item (que acontece a cada
  /// rebuild da tela) não pode reemitir o pedido sozinho.
  void _loadMoreFromBuild(String cursor) {
    if (_requestedCursor == cursor) return;
    _requestedCursor = cursor;
    _loadMore();
  }

  void _loadMore() {
    final current = ref.read(myContributionsProvider).value;
    if (current == null || current.nextCursor == null || current.loadingMore) {
      return;
    }
    // Falha na próxima página é silenciosa aqui: `loadMore()` já reverte
    // `loadingMore` e mantém os itens carregados; o próximo scroll (ou a
    // próxima construção do último item, uma vez por cursor) tenta de novo.
    unawaited(
      ref.read(myContributionsProvider.notifier).loadMore().catchError((_) {}),
    );
  }

  Future<void> _onRefresh() {
    // Um novo `refresh()` pode repetir o mesmo `nextCursor` da página
    // anterior (ex.: a primeira página não mudou) — sem isto, o gatilho de
    // construção não pediria a próxima página de novo.
    _requestedCursor = null;
    return ref.read(myContributionsProvider.notifier).refresh();
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
            FilledButton(onPressed: _onRefresh, child: Text(l10n.retry)),
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
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
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
      onRefresh: _onRefresh,
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
          if (index == state.items.length - 1 &&
              state.nextCursor != null &&
              !state.loadingMore) {
            // Agendado para depois do frame (nunca síncrono dentro do
            // `build`): constrói o último item já pede a próxima página,
            // mesmo que a lista inteira caiba no viewport sem rolar.
            final cursor = state.nextCursor!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMoreFromBuild(cursor);
            });
          }
          final c = state.items[index];
          return ListTile(
            title: Text(
              c.title,
              style: AppTypography.body.copyWith(color: AppColors.textLight),
            ),
            subtitle: Text(
              '${contributionKindLabel(l10n, c.kind)} · '
              '${_formatDate(c.createdAt)}',
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

/// `dd/MM/yyyy` em hora local — mesmo padrão sem `intl` de
/// `formatLeafletHeaderDate`.
String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
