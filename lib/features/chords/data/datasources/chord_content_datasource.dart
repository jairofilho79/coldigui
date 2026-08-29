import 'package:dio/dio.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../../domain/entities/chordpro_song.dart';
import '../../domain/usecases/parse_chordpro.dart';

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

  /// Música parseada, ou `null` quando indisponível.
  ///
  /// `null` cobre os quatro casos em que o sheet não deve listar a cifra:
  /// chave vazia, 404, falha de rede e arquivo sem nenhuma linha de letra.
  Future<ChordProSong?> fetchSong(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);

    final String body;
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode != 200) return null;
      body = response.data ?? '';
    } on Object {
      return null;
    }

    if (body.trim().isEmpty) return null;

    final song = parseChordPro(body);
    return song.hasLyrics ? song : null;
  }
}
