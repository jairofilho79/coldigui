// test/widget/features/contributions/entry_points_test.dart
//
// Tarefa 5 — ponto de entrada do Perfil: «Ajude a melhorar» aparece sempre
// (a própria tela já cuida do deslogado com o convite de login) e «Minhas
// contribuições» só dentro do bloco logado.
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/pump_app.dart';

void main() {
  testWidgets(
    'Perfil logado mostra «Ajude a melhorar» e «Minhas contribuições»',
    (tester) async {
      await pumpApp(
        tester,
        const ProfileScreen(),
        overrides: [
          authStateProvider.overrideWith(
            () => FakeAuthNotifier(
              const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Ajude a melhorar o PLPCG'), findsOneWidget);
      expect(find.text('Minhas contribuições'), findsOneWidget);
    },
  );

  testWidgets(
    'Perfil deslogado mostra «Ajude a melhorar» (abre o convite) mas não «Minhas contribuições»',
    (tester) async {
      await pumpApp(
        tester,
        const ProfileScreen(),
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Ajude a melhorar o PLPCG'), findsOneWidget);
      expect(find.text('Minhas contribuições'), findsNothing);
    },
  );
}
