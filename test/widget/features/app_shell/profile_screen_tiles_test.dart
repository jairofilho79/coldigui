import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoggedOutAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Spec D3 — tiles do hub Perfil, de cima para baixo: Biblioteca, Offline,
/// Sobre. «Listas» virou aba própria e saiu daqui.
void main() {
  testWidgets('tiles na ordem Biblioteca, Offline, Sobre — sem Listas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith(_LoggedOutAuth.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final biblioteca = tester.getTopLeft(find.text('Biblioteca'));
    final offline = tester.getTopLeft(find.text('Offline'));
    final sobre = tester.getTopLeft(find.text('Sobre'));

    expect(biblioteca.dy, lessThan(offline.dy));
    expect(offline.dy, lessThan(sobre.dy));
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.text('Listas'), findsNothing);
  });
}
