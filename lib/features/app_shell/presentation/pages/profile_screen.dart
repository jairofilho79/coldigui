import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';

/// Hub do Perfil — login Google, Sobre, Listas e Offline.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          children: [
            auth.when(
              data: (user) => user == null
                  ? const _SignedOutHeader()
                  : _SignedInHeader(user: user),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Erro de autenticação: $e'),
                    const SizedBox(height: 12),
                    const GoogleSignInButton(),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => goToShellDestination(context, RoutePaths.about),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Listas'),
              onTap: () => goToShellDestination(context, RoutePaths.playlists),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('Offline'),
              onTap: () => goToShellDestination(context, RoutePaths.offline),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutHeader extends StatelessWidget {
  const _SignedOutHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('Conta'), SizedBox(height: 12), GoogleSignInButton()],
      ),
    );
  }
}

class _SignedInHeader extends ConsumerWidget {
  const _SignedInHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: user.pictureUrl != null
                    ? NetworkImage(user.pictureUrl!)
                    : null,
                child: user.pictureUrl == null
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name ?? 'Usuário',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (user.email != null)
                      Text(user.email!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
