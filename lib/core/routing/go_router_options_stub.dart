import 'package:go_router/go_router.dart';

/// Configuração não-web do go_router: reflete APIs imperativas na URL.
void configureGoRouterGlobals() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
}
