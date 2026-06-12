import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Query params ativos da rota `/leitor`, espelhados por [PdfReaderScreen].
///
/// Fallback para [CarouselChips] quando a URL do GoRouter ainda não expõe
/// query params. Em `/leitor`, [CarouselChips] prioriza
/// `GoRouterState.uri.queryParameters` (atualização imediata após `replace`) e
/// usa este provider só quando a URL está vazia.
class ReaderRouteParamsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void update(Map<String, String> queryParams) {
    state = Map<String, String>.unmodifiable(queryParams);
  }

  void clear() {
    state = const {};
  }
}

/// Params da visita atual a `/leitor`; vazio fora do leitor.
final readerRouteParamsProvider =
    NotifierProvider<ReaderRouteParamsNotifier, Map<String, String>>(
  ReaderRouteParamsNotifier.new,
);
