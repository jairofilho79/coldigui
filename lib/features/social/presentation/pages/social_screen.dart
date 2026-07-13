import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/create_username_dialog.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart'
    as plpcg;
import 'package:coldigui/features/social/presentation/providers/social_search_provider.dart';
import 'package:coldigui/features/social/presentation/widgets/social_user_card.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aba Social — busca de pessoas e importação de listas públicas.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.asData?.value != null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: auth.when(
                  data: (user) {
                    if (user == null) return const _AuthRequiredBanner();
                    return _UsernameBanner(
                      username: user.username,
                      onCreate: () => showCreateUsernameDialog(context),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const _AuthRequiredBanner(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: plpcg.SearchBar(
                  hintText: l10n.socialSearchHint,
                  onQueryChanged: (value) {
                    ref.read(socialSearchRawQueryProvider.notifier).state =
                        value;
                  },
                ),
              ),
            ),
            ..._resultsSlivers(context, ref, signedIn),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultsSlivers(
    BuildContext context,
    WidgetRef ref,
    bool signedIn,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!signedIn) {
      return [_centeredMessage(l10n.socialSignInRequired)];
    }

    final query = ref.watch(socialSearchDebouncedQueryProvider);
    if (query.isEmpty) {
      return [_centeredMessage(l10n.socialSearchEmptyHint)];
    }

    final results = ref.watch(socialSearchResultsProvider);
    return [
      results.when(
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
        error: (_, _) => _centeredMessage(l10n.socialSearchError),
        data: (users) {
          if (users.isEmpty) {
            return _centeredMessage(l10n.socialSearchNoResults);
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => SocialUserCard(user: users[index]),
              childCount: users.length,
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  static Widget _centeredMessage(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.title.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }
}

class _UsernameBanner extends StatelessWidget {
  const _UsernameBanner({required this.username, required this.onCreate});

  final String? username;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasUsername = username != null && username!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.btnBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            hasUsername ? Icons.alternate_email : Icons.person_add_alt_1,
            color: AppColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: hasUsername
                ? Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : Text(
                    l10n.usernameCreatePrompt,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
          ),
          if (!hasUsername)
            TextButton(
              onPressed: onCreate,
              child: Text(l10n.usernameCreateButton),
            ),
        ],
      ),
    );
  }
}

class _AuthRequiredBanner extends StatelessWidget {
  const _AuthRequiredBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.btnBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            l10n.socialSignInRequired,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const GoogleSignInButton(),
        ],
      ),
    );
  }
}
