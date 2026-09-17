import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/oidc/oidc_callback.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/create_username_dialog.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';

/// Hub do Perfil — login Google, Biblioteca, Offline e Sobre.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            auth.when(
              data: (user) => _AccountPanel(
                child: user == null
                    ? const _SignedOutHeader()
                    : _SignedInHeader(user: user),
              ),
              loading: () => const _AccountPanel(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => _AccountPanel(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // O botão já mostra a própria UI de D15 para esse
                      // erro (título + texto + ação) — duplicar o texto
                      // genérico aqui deixaria a mensagem repetida.
                      if (e is! OidcContextMismatchException) ...[
                        Text(
                          userMessageFor(l10n, e),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Center(child: GoogleSignInButton()),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ProfilePageTile(
              icon: Icons.library_books,
              title: 'Biblioteca',
              onTap: () => goToShellDestination(context, RoutePaths.library),
            ),
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.volunteer_activism_outlined,
              title: l10n.contributeTitle,
              // `openContribute` (não `context.push` direto): manda o
              // `from` no payload — o Perfil é de onde a maioria dos
              // envios parte, e sem o `from` isso não vai pro servidor.
              onTap: () => openContribute(context),
            ),
            if (auth.asData?.value != null) ...[
              const SizedBox(height: 10),
              _ProfilePageTile(
                icon: Icons.star_outline,
                title: l10n.favoriteMaterialKindsTitle,
                onTap: () => goToShellDestination(
                  context,
                  RoutePaths.favoriteMaterialKinds,
                ),
              ),
              const SizedBox(height: 10),
              _ProfilePageTile(
                icon: Icons.inbox_outlined,
                title: l10n.myContributionsTitle,
                onTap: () =>
                    goToShellDestination(context, RoutePaths.myContributions),
              ),
            ],
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.cloud_download,
              title: 'Offline',
              onTap: () => goToShellDestination(context, RoutePaths.offline),
            ),
            const SizedBox(height: 10),
            _ProfilePageTile(
              icon: Icons.info_outline,
              title: 'Sobre',
              onTap: () => goToShellDestination(context, RoutePaths.about),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.btnBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: AppColors.shadowMd,
      ),
      child: child,
    );
  }
}

class _SignedOutHeader extends StatelessWidget {
  const _SignedOutHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Entrar para sincronizar seus dados',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use sua conta Google para sincronizar listas e outras features.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 20),
          GoogleSignInButton(),
        ],
      ),
    );
  }
}

class _SignedInHeader extends ConsumerWidget {
  const _SignedInHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ref.read(authStateProvider.notifier).signOut(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.3),
                  backgroundImage: user.pictureUrl != null
                      ? NetworkImage(user.pictureUrl!)
                      : null,
                  child: user.pictureUrl == null
                      ? const Icon(Icons.person, size: 28, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name ?? 'Usuário',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (user.hasUsername)
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => showCreateUsernameDialog(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.usernameCreateButton,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePageTile extends StatelessWidget {
  const _ProfilePageTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.btnBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
