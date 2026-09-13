import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/auth_state_provider.dart';

/// Botão nativo / fallback — Web usa o redirect OIDC (`google_sign_in_button_web.dart`).
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final busy = auth.isLoading;

    return FilledButton.icon(
      onPressed: busy
          ? null
          : () async {
              try {
                await ref.read(authStateProvider.notifier).signInWithGoogle();
              } on Object catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Falha ao entrar: $e')));
              }
            },
      icon: const Icon(Icons.login),
      label: Text(
        busy ? 'Entrando…' : AppLocalizations.of(context)!.authSignInWithGoogle,
      ),
    );
  }
}
