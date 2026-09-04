import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;

import '../../../../core/constants/app_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_state_provider.dart';

/// Botão oficial GIS (obrigatório no Web — popup do SDK).
///
/// Não chama [GoogleSignIn.initialize] — isso fica só no [AuthNotifier].
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (AppConfig.isGoogleClientIdMissing) {
      return Text(
        l10n.authSignInUnavailable,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final auth = ref.watch(authStateProvider);
    final signInUnavailable = ref.watch(googleSignInUnavailableProvider);

    // O SDK não subiu (bloqueado, offline, CORS): o login fica indisponível,
    // mas a sessão restaurada em [AuthNotifier.build] continua valendo (A5).
    if (signInUnavailable) {
      return Text(
        l10n.authSignInUnavailable,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return auth.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) {
        debugPrint('[auth] estado de login em erro: $error');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.authSignInUnavailable,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(authStateProvider),
              child: Text(l10n.authSignInRetry),
            ),
          ],
        );
      },
      data: (_) => gis.renderButton(
        configuration: gis.GSIButtonConfiguration(
          type: gis.GSIButtonType.standard,
          theme: gis.GSIButtonTheme.outline,
          size: gis.GSIButtonSize.large,
          text: gis.GSIButtonText.signinWith,
          shape: gis.GSIButtonShape.rectangular,
          logoAlignment: gis.GSIButtonLogoAlignment.left,
        ),
      ),
    );
  }
}
