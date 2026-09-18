import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_shell/presentation/pages/missing_api_config_screen.dart';
import 'features/app_shell/presentation/widgets/deep_link_listener.dart';
import 'features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'features/coldigom/data/constants/coldigom_api_config.dart';
import 'features/pdf_reader/data/pdfrx_bootstrap.dart';
import 'l10n/app_localizations.dart';

/// Widget raiz — MaterialApp com tema Coletânea Digital, l10n e GoRouter.
///
/// Se falta `PLPCG_API_BASE_URL` ou `COLDIGOM_API_BASE_URL`, renderiza
/// [MissingApiConfigScreen] (sem router) em vez de iniciar o catálogo. Caso
/// contrário, dispara [louvoresManifestProvider]
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
    final missingDefines = [
      if (AppConfig.isApiBaseUrlMissing) 'PLPCG_API_BASE_URL',
      if (ColdigomApiConfig.isBaseUrlMissing) 'COLDIGOM_API_BASE_URL',
    ];
    if (missingDefines.isNotEmpty) {
      return MaterialApp(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: MissingApiConfigScreen(missingDefines: missingDefines),
      );
    }

    // listen (não watch): inicia o fetch sem reconstruir MaterialApp.router ao concluir.
    ref.listen(louvoresManifestProvider, (_, _) {});

    final router = ref.watch(appRouterProvider);

    return PdfrxIdlePreloader(
      child: DeepLinkListener(
        child: MaterialApp.router(
          title: 'PLPCG',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }
}
