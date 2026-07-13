import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;

import '../../../../core/constants/app_config.dart';
import '../providers/auth_state_provider.dart';

/// Botão oficial GIS (obrigatório no Web — popup do SDK).
///
/// O [authStateProvider] escuta `authenticationEvents` e completa a sessão.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = AppConfig.isGoogleClientIdMissing
        ? Future<void>.error('GOOGLE_CLIENT_ID_WEB ausente no build')
        : GoogleSignIn.instance.initialize(
            clientId: AppConfig.googleClientIdWeb,
          );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);

    if (AppConfig.isGoogleClientIdMissing) {
      return Text(
        'Login indisponível: GOOGLE_CLIENT_ID_WEB ausente no build',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Login indisponível: ${snapshot.error}',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        return gis.renderButton(
          configuration: gis.GSIButtonConfiguration(
            type: gis.GSIButtonType.standard,
            theme: gis.GSIButtonTheme.outline,
            size: gis.GSIButtonSize.large,
            text: gis.GSIButtonText.signinWith,
            shape: gis.GSIButtonShape.rectangular,
            logoAlignment: gis.GSIButtonLogoAlignment.left,
          ),
        );
      },
    );
  }
}
