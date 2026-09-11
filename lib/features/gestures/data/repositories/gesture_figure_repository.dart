import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../datasources/gesture_figure_store.dart';

/// Figuras dos gestos: store local primeiro, rede só no miss.
///
/// Tudo best-effort e sem exceção para fora: figura que não veio é
/// placeholder na tela, e a próxima abertura tenta de novo.
class GestureFigureRepository {
  const GestureFigureRepository(this._store, this._dio, {required String apiBase})
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final GestureFigureStorePort _store;
  final Dio _dio;
  final String _apiBase;

  /// Quantos downloads em voo o [prefetch] mantém.
  static const int prefetchConcurrency = 4;

  /// Bytes da figura, do store ou da rede; `null` se não deu.
  Future<Uint8List?> get(String r2Key) async {
    final key = r2Key.trim();
    if (key.isEmpty) return null;

    final cached = await _store.read(key);
    if (cached != null) return cached;

    final bytes = await _download(key);
    if (bytes == null) return null;
    await _store.write(key, bytes);
    return bytes;
  }

  /// Aquece o store com [r2Keys] (deduplicadas), ignorando falhas.
  Future<void> prefetch(Iterable<String> r2Keys) async {
    final pending = r2Keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet().toList();
    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final key = pending.removeLast();
        await get(key);
      }
    }

    await Future.wait([for (var i = 0; i < prefetchConcurrency; i++) worker()]);
  }

  Future<Uint8List?> _download(String key) async {
    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (response.statusCode != 200 || data == null || data.isEmpty) {
        return null;
      }
      return Uint8List.fromList(data);
    } on Object catch (error) {
      debugPrint('[gestos] download da figura $key falhou: $error');
      return null;
    }
  }
}
