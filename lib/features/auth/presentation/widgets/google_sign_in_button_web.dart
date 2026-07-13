import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;

import '../../../../core/constants/app_config.dart';
import '../providers/auth_state_provider.dart';

/// Botão oficial GIS (obrigatório no Web — popup do SDK).
///
/// Não chama [GoogleSignIn.initialize] — isso fica só no [AuthNotifier].
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.isGoogleClientIdMissing) {
      return Text(
        'Login indisponível: GOOGLE_CLIENT_ID_WEB ausente no build',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Text(
        'Login indisponível: $error',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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
