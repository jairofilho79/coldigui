import 'package:dio/dio.dart';

import '../../../../core/utils/coldigom_asset_url.dart';

/// Falha ao buscar um recurso de gestos — rede, timeout ou status inesperado.
///
/// Separa "não existe" (404 → `null`) de "não deu para saber agora": sem isso
/// uma queda de rede viraria, para o resto do app, um louvor sem gestos.
class GestureFetchFailedException implements Exception {
  const GestureFetchFailedException(this.resource, this.cause);

  /// `r2Key` do documento, ou `'dictionary'`.
  final String resource;

  final Object cause;

  @override
  String toString() => 'GestureFetchFailedException($resource): $cause';
}

/// Busca o JSON `.gestures` de um material coldigom.
///
/// Mesma escada do `ChordContentDatasource`: um GET pelo proxy de assets
/// resolve "existe?" e "qual é?" de uma vez — o arquivo tem poucos KB.
class GestureContentDatasource {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado.
  const GestureContentDatasource(this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final Dio _dio;
  final String _apiBase;

  /// JSON cru, ou `null` quando o arquivo não existe (chave vazia, 404, corpo
  /// vazio). Qualquer outra falha vira [GestureFetchFailedException].
  Future<String?> fetchContent(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);

    final Response<String> response;
    try {
      response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw GestureFetchFailedException(key, error);
    } on Object catch (error) {
      throw GestureFetchFailedException(key, error);
    }

    final status = response.statusCode;
    if (status == 404) return null;
    if (status != 200) {
      throw GestureFetchFailedException(
        key,
        DioException.badResponse(
          statusCode: status ?? 0,
          requestOptions: response.requestOptions,
          response: response,
        ),
      );
    }

    final body = response.data ?? '';
    return body.trim().isEmpty ? null : body;
  }
}
