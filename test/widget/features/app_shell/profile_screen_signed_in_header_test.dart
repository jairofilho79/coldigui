import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

class _LoggedInAuth extends AuthNotifier {
  _LoggedInAuth({this.user = _defaultUser});

  static const _defaultUser = AuthUser(
    googleSub: 'sub-1',
    sessionToken: 'tok',
    name: 'Jairo Filho',
    email: 'jairofilho79@gmail.com',
    username: 'jairofilho79',
  );

  final AuthUser user;

  @override
  Future<AuthUser?> build() async => user;
}

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  group('ProfileScreen _SignedInHeader layout', () {
    testWidgets('em telas largas (desktop/tablet), avatar/nome e botões ficam na mesma linha', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpApp(
        tester,
        const ProfileScreen(),
        overrides: [authStateProvider.overrideWith(_LoggedInAuth.new)],
      );
      await tester.pumpAndSettle();

      final avatarRect = tester.getRect(find.byType(CircleAvatar));
      final nameRect = tester.getRect(find.text('Jairo Filho'));
      final signOutRect = tester.getRect(find.text(pt.profileSignOut));
      final deleteRect = tester.getRect(find.text(pt.profileDeleteAccount));

      // Botões ficam à direita do bloco avatar + nome
      expect(signOutRect.left, greaterThan(nameRect.right));
      expect(deleteRect.left, greaterThan(signOutRect.left));

      // Ficam na mesma linha (centros verticais próximos / alinhados horizontalmente)
      expect((avatarRect.center.dy - signOutRect.center.dy).abs(), lessThan(30));
      expect((nameRect.center.dy - signOutRect.center.dy).abs(), lessThan(30));
    });

    testWidgets('em telas mobile (largura estreita), avatar/nome fica no topo e botões embaixo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpApp(
        tester,
        const ProfileScreen(),
        overrides: [authStateProvider.overrideWith(_LoggedInAuth.new)],
      );
      await tester.pumpAndSettle();

      final nameRect = tester.getRect(find.text('Jairo Filho'));
      final usernameRect = tester.getRect(find.text('@jairofilho79'));
      final signOutRect = tester.getRect(find.text(pt.profileSignOut));
      final deleteRect = tester.getRect(find.text(pt.profileDeleteAccount));

      // Botões ficam abaixo do bloco de perfil
      expect(signOutRect.top, greaterThan(usernameRect.bottom));
      expect(deleteRect.top, greaterThan(usernameRect.bottom));
      expect(signOutRect.top, greaterThan(nameRect.bottom));

      // Não há overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('em telas super estreitas (320px), não estoura com overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpApp(
        tester,
        const ProfileScreen(),
        overrides: [authStateProvider.overrideWith(_LoggedInAuth.new)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Jairo Filho'), findsOneWidget);
      expect(find.text(pt.profileSignOut), findsOneWidget);
      expect(find.text(pt.profileDeleteAccount), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
