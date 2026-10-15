/// Opções globais (estáticas) do go_router — chamada uma vez em `main()`.
///
/// Na web (`go_router_options_web.dart`), ativa `usePathUrlStrategy()` para
/// permitir URLs limpas sem `#` (ex: `/louvor/:id`, `/biblioteca`) e
/// `optionURLReflectsImperativeAPIs = true`.
library;

export 'go_router_options_stub.dart'
    if (dart.library.js_interop) 'go_router_options_web.dart';
