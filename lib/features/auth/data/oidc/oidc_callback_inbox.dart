import 'oidc_callback.dart';

/// Entrega única do callback capturado em `main()` ao `AuthNotifier`
/// (spec D9): `take()` devolve e esvazia, então um `invalidate` do provider
/// não reprocessa o mesmo token.
class OidcCallbackInbox {
  OidcCallbackInbox([this._pending]);

  OidcCallbackResult? _pending;

  OidcCallbackResult? take() {
    final result = _pending;
    _pending = null;
    return result;
  }
}
