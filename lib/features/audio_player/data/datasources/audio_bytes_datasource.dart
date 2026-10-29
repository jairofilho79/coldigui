import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/network/retry_interceptor.dart';
import '../../../../core/utils/coldigom_asset_url.dart';

/// Bytes de um áudio Coldigom para persistir (download do `/offline`).
///
/// Mesma regra de URL de `AudioTrackUrl.fetchUrlForTrack`: na web passa pelo
/// proxy same-policy (`/api/coldigom/<chave>`), no nativo vai direto ao
/// worker. `isWeb` é injetado para o teste cobrir os dois ramos sem `kIsWeb`.
/// O retry do interceptor fica desligado: `DownloadColdigomMaterials` já
/// retenta com o backoff de `download_retry.dart`, como o PDF.
class AudioBytesDatasource {
  const AudioBytesDatasource(
    this._dio, {
    required String apiBase,
    required bool isWeb,
  }) : _apiBase = apiBase, // ignore: prefer_initializing_formals
       _isWeb = isWeb; // ignore: prefer_initializing_formals

  final Dio _dio;
  final String _apiBase;
  final bool _isWeb;

  Future<Uint8List> fetch(String r2Key, {CancelToken? cancelToken}) async {
    final url = _isWeb
        ? ColdigomAssetUrl.fetchUrlForKey(r2Key, apiBase: _apiBase)
        : ColdigomAssetUrl.directUrlForKey(r2Key);
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: OfflineConfig.pdfDownloadReceiveTimeout,
        sendTimeout: OfflineConfig.pdfDownloadSendTimeout,
        extra: const {RetryInterceptor.disableKey: true},
      ),
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('Resposta de áudio vazia: $r2Key');
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}
