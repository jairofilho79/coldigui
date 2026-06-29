import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_shell/presentation/widgets/deep_link_listener.dart';
import 'features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'l10n/app_localizations.dart';

/// Widget raiz — MaterialApp com tema Coletânea Digital, l10n e GoRouter.
///
/// Se [AppConfig.isApiBaseUrlMissing], renderiza tela de diagnóstico (sem router)
/// em vez de iniciar o catálogo. Caso contrário, dispara [louvoresManifestProvider]
/// no boot via [ref.listen] (sem [ref.watch] — evita rebuild do router quando o
/// manifest com ~4600 itens conclui). Envolve o router com [DeepLinkListener]
/// (Fase 4.5 — import automático de playlist via deep link).
///
/// Ambos os [MaterialApp] usam `debugShowCheckedModeBanner: false` para ocultar
/// o selo DEBUG no canto superior direito.
class ColdiguiApp extends ConsumerWidget {
  const ColdiguiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.isApiBaseUrlMissing) {
      return MaterialApp(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _MissingApiBaseUrlScreen(),
      );
    }

    // listen (não watch): inicia o fetch sem reconstruir MaterialApp.router ao concluir.
    ref.listen(louvoresManifestProvider, (_, _) {});

    final router = ref.watch(appRouterProvider);

    return DeepLinkListener(
      child: MaterialApp.router(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

/// Exibida quando [AppConfig.apiBaseUrl] não foi definido no build.
class _MissingApiBaseUrlScreen extends StatelessWidget {
  const _MissingApiBaseUrlScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PLPCG')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: SelectableText(
          'PLPCG_API_BASE_URL não está definido neste build.\n\n'
          'Reinstale com:\n'
          'flutter run --dart-define-from-file=dart_defines/plpcg.json\n\n'
          'ou:\n'
          'flutter build ios --dart-define-from-file=dart_defines/plpcg.json',
        ),
      ),
    );
  }
}
