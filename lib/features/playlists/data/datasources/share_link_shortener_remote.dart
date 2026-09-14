import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../domain/ports/share_link_shortener.dart';

/// Timeout do encurtador (spec C.2) — errar rápido importa mais que o
/// resultado aqui: em qualquer erro, quem chama cai na URL longa.
const shareLinkShortenerTimeout = Duration(seconds: 3);

/// Impl Dio de [ShareLinkShortener] — `POST /api/links` no Worker
/// `plpcg-catalog` (D7, spec C.2).
class ShareLinkShortenerRemote implements ShareLinkShortener {
  ShareLinkShortenerRemote(this._dio, {required this.sessionToken});

  final Dio _dio;

  /// Token Google do usuário atual, resolvido a cada chamada (a rota exige
  /// `Authorization`). `null`/vazio manda a request sem o header — o Worker
  /// recusa com 401, que [shorten] deixa propagar como qualquer outro erro.
  final String? Function() sessionToken;

  /// `POST /api/links` com `{query}`; devolve `url` da resposta.
  ///
  /// Timeout de 3s cobre tanto o envio/recebimento (`Options.sendTimeout` /
  /// `receiveTimeout`, que o adapter respeita depois de conectar) quanto a
  /// fase de conexão (`CancelToken` cancelado por um timer manual — Dio não
  /// tem `connectTimeout` por request, só em `BaseOptions`).
  ///
  /// Lança em qualquer falha — rede, timeout, `4xx`/`5xx`, corpo sem `url`.
  @override
  Future<String> shorten(String query) async {
    final token = sessionToken();
    final cancelToken = CancelToken();
    final guard = Timer(
      shareLinkShortenerTimeout,
      () => cancelToken.cancel('timeout'),
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.links,
        data: {'query': query},
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          sendTimeout: shareLinkShortenerTimeout,
          receiveTimeout: shareLinkShortenerTimeout,
        ),
        cancelToken: cancelToken,
      );
      final url = response.data?['url'];
      if (url is! String || url.isEmpty) {
        throw const FormatException('resposta do encurtador sem url');
      }
      return url;
    } finally {
      guard.cancel();
    }
  }
}
