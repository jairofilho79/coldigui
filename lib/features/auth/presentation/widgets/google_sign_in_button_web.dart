import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/oidc/oidc_callback.dart';
import '../providers/auth_state_provider.dart';
import 'google_logo.dart';

/// Botão de login web: redirect OIDC em vez do popup do GIS (spec D1/D2),
/// para a página poder viver sob `Cross-Origin-Opener-Policy: same-origin`.
///
/// Não depende do SDK do Google ter carregado (D11) — só do Client ID.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    if (ref.watch(googleClientIdProvider).isEmpty) {
      return Text(l10n.authSignInUnavailable, style: textStyle);
    }

    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) {
        debugPrint('[auth] estado de login em erro: $error');
        if (error is OidcContextMismatchException) {
          return _ContextMismatch(
            onSignIn: () => _startRedirect(context, ref),
            showBrowserHint: ref.read(oidcBrowserProvider).isStandaloneDisplay,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.authSignInUnavailable, style: textStyle),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(authStateProvider),
              child: Text(l10n.authSignInRetry),
            ),
          ],
        );
      },
      data: (_) => _SignInButton(onPressed: () => _startRedirect(context, ref)),
    );
  }

  /// `returnTo` é a rota atual — sem router (testes de tela isolada) cai em `/`.
  void _startRedirect(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    final returnTo = router == null
        ? '/'
        : GoRouterState.of(context).uri.toString();
    ref
        .read(authStateProvider.notifier)
        .startGoogleRedirect(returnTo: returnTo);
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: const GoogleLogo(),
        label: Text(l10n.authSignInWithGoogle),
      ),
    );
  }
}

/// Estado de D15: o Google respondeu num contexto que não iniciou o login.
class _ContextMismatch extends StatelessWidget {
  const _ContextMismatch({
    required this.onSignIn,
    required this.showBrowserHint,
  });

  final VoidCallback onSignIn;
  final bool showBrowserHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.authSignInContextMismatchTitle,
          style: theme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.authSignInContextMismatchBody,
          style: theme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _SignInButton(onPressed: onSignIn),
        if (showBrowserHint) ...[
          const SizedBox(height: 8),
          Text(
            l10n.authSignInOpenInBrowserHint,
            style: theme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
