import 'package:dio/dio.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/parse_chordpro.dart';

/// Falha ao buscar o `.chord` de [r2Key] — rede, timeout ou status != 200/404.
///
/// Existe para separar "a cifra não existe" (404 → `null`) de "não deu para
/// saber agora": sem essa distinção uma queda de rede vira, para o resto do
/// app, um louvor sem cifra.
class ChordFetchFailedException implements Exception {
  const ChordFetchFailedException(this.r2Key, this.cause);

  /// Chave Coldigom do arquivo pedido.
  final String r2Key;

  /// Erro original (normalmente [DioException]).
  final Object cause;

  @override
  String toString() => 'ChordFetchFailedException($r2Key): $cause';
}

/// Busca e parseia o conteúdo `.chord` de um material coldigom.
///
/// Uma ida à rede resolve as duas perguntas do sheet — "existe?" e "qual é o
/// conteúdo?" — porque os arquivos têm 611 B em média. Por isso não há HEAD:
/// o GET já traz tudo, e o resultado alimenta o leitor sem segunda requisição.
class ChordContentDatasource {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado —
  // a forma sugerida pelo lint perderia o nome externo `apiBase`.
  const ChordContentDatasource(this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final Dio _dio;
  final String _apiBase;

  /// Conteúdo cru do `.chord`, ou `null` quando o arquivo não existe.
  ///
  /// `null` só nos casos em que a resposta é conclusiva: chave vazia, 404 e
  /// corpo vazio (lápide). Qualquer outra falha vira
  /// [ChordFetchFailedException] — quem chama decide entre cache e "tentar de
  /// novo", em vez de tratar como cifra inexistente.
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
      throw ChordFetchFailedException(key, error);
    } on Object catch (error) {
      throw ChordFetchFailedException(key, error);
    }

    final status = response.statusCode;
    if (status == 404) return null;
    if (status != 200) {
      throw ChordFetchFailedException(
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

  /// Música parseada, ou `null` quando a cifra não existe.
  ///
  /// Propaga [ChordFetchFailedException] de [fetchContent].
  Future<ChordProSong?> fetchSong(String r2Key) async {
    final body = await fetchContent(r2Key);
    if (body == null) return null;
    return parseChordSongOrNull(body);
  }
}

/// Parseia [content] e devolve `null` quando o arquivo não tem nenhuma linha
/// de letra (arquivo-lápide publicado sem conteúdo útil).
ChordProSong? parseChordSongOrNull(String content) {
  final song = parseChordPro(content);
  return song.hasLyrics ? song : null;
}
