import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'tok', name: 'Jairo');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  testWidgets('tile de favoritos aparece só logado', (tester) async {
    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: [authStateProvider.overrideWith(_LoggedIn.new)],
    );
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsTitle), findsOneWidget);
  });

  testWidgets('deslogado não mostra o tile', (tester) async {
    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: [authStateProvider.overrideWith(_LoggedOut.new)],
    );
    await tester.pumpAndSettle();
    expect(find.text(pt.favoriteMaterialKindsTitle), findsNothing);
  });
}
