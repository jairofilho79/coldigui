import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

/// Configuração web do go_router: ativa URL sem hash (#) e reflete APIs imperativas na URL.
void configureGoRouterGlobals() {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
}
