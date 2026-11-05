import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../datasources/score_byte_store.dart';

/// Falha ao baixar uma partitura — rede, timeout ou status inesperado.
///
/// Separa "não existe" (404 → `null`) de "não deu para saber agora".
class ScoreFetchFailedException implements Exception {
  const ScoreFetchFailedException(this.r2Key, this.cause);

  final String r2Key;
  final Object cause;

  @override
  String toString() => 'ScoreFetchFailedException($r2Key): $cause';
}

/// Bytes de uma partitura do coldigom: store local primeiro, rede no miss.
///
/// Toda partitura aberta fica disponível offline. Com cópia local, a rede só
/// é consultada em background ([refreshInBackground]) e a versão nova vale a
/// partir da próxima abertura — trocar a partitura no meio da leitura (ou da
/// execução) seria pior que mostrar a anterior.
class ScoreFileRepository {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado.
  ScoreFileRepository(this._store, this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final ScoreByteStorePort _store;
  final Dio _dio;
  final String _apiBase;

  Future<Uint8List?> readLocal(String r2Key) => _store.read(r2Key.trim());

  /// Há cópia local de [r2Key]? (download em lote e estatísticas offline).
  Future<bool> hasLocal(String r2Key) => _store.contains(r2Key.trim());

  /// Predicado «há cópia local» para checagens em lote: uma listagem só.
  Future<bool Function(String r2Key)> localPresence() async {
    final names = await _store.fileNames();
    return (r2Key) => names.contains(scoreByteStoreFileName(r2Key.trim()));
  }

  /// Baixa e grava; `null` quando o arquivo não existe.
  Future<Uint8List?> fetch(String r2Key, {CancelToken? cancelToken}) async {
    final key = r2Key.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(r2Key, 'r2Key', 'chave de partitura vazia');
    }
    final bytes = await _download(key, cancelToken);
    if (cancelToken?.cancelError case final error?) throw error;
    if (bytes != null) await _store.write(key, bytes);
    return bytes;
  }

  /// Atualiza a cópia local sem bloquear quem abriu; falhas só são logadas.
  void refreshInBackground(String r2Key) {
    unawaited(
      fetch(r2Key).then<void>(
        (_) {},
        onError: (Object error) =>
            debugPrint('[partitura] revalidação de $r2Key falhou: $error'),
      ),
    );
  }

  Future<Uint8List?> _download(String key, CancelToken? cancelToken) async {
    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ScoreFetchFailedException(key, error);
    } on Object catch (error) {
      throw ScoreFetchFailedException(key, error);
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ScoreFetchFailedException(key, 'HTTP ${response.statusCode}');
    }
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw ScoreFetchFailedException(key, 'resposta HTTP 200 vazia');
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}
