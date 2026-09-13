import 'package:dio/dio.dart';

import '../constants/gesture_dictionary_config.dart';
import 'gesture_content_datasource.dart';

/// Resultado de `GET /api/gestures/dictionary`.
sealed class GestureDictionaryFetchResult {
  const GestureDictionaryFetchResult();
}

/// 200: corpo novo (com o `ETag` que o servidor mandou, se mandou).
final class GestureDictionaryFresh extends GestureDictionaryFetchResult {
  const GestureDictionaryFresh({required this.body, required this.etag});

  final String body;
  final String? etag;
}

/// 304: o cache continua válido.
final class GestureDictionaryNotModified extends GestureDictionaryFetchResult {
  const GestureDictionaryNotModified();
}

/// 404: o coldigom ainda não publica o dicionário.
final class GestureDictionaryNotFound extends GestureDictionaryFetchResult {
  const GestureDictionaryNotFound();
}

/// Busca o dicionário com `If-None-Match`.
///
/// É chamada de API JSON (como `/api/plpcg/praises`), não de asset: vai
/// direto na base, sem o proxy `/api/coldigom/*` (esse só existe para assets
/// sob COEP). A URL é absoluta para o `--dart-define` de override funcionar
/// mesmo com o `baseUrl` do `Dio` apontando para o coldigom.
class GestureDictionaryDatasource {
  const GestureDictionaryDatasource(this._dio, {required String baseUrl})
    // ignore: prefer_initializing_formals
    : _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  String get _url {
    final base = _baseUrl.trim();
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed${GestureDictionaryConfig.path}';
  }

  Future<GestureDictionaryFetchResult> fetch({String? etag}) async {
    final Response<String> response;
    try {
      response = await _dio.get<String>(
        _url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {if (etag != null && etag.isNotEmpty) 'If-None-Match': etag},
          // 304 não é erro: deixa passar para o `switch` abaixo.
          validateStatus: (status) =>
              status != null && (status < 400 || status == 404),
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const GestureDictionaryNotFound();
      }
      throw GestureFetchFailedException('dictionary', error);
    } on Object catch (error) {
      throw GestureFetchFailedException('dictionary', error);
    }

    switch (response.statusCode) {
      case 200:
        return GestureDictionaryFresh(
          body: response.data ?? '',
          etag: response.headers.value('etag'),
        );
      case 304:
        return const GestureDictionaryNotModified();
      case 404:
        return const GestureDictionaryNotFound();
      default:
        throw GestureFetchFailedException(
          'dictionary',
          DioException.badResponse(
            statusCode: response.statusCode ?? 0,
            requestOptions: response.requestOptions,
            response: response,
          ),
        );
    }
  }
}
