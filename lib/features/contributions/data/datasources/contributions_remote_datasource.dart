import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../auth/data/auth_remote_datasource.dart'
    show AuthUnauthorizedException;
import '../../../coldigom/data/constants/coldigom_endpoints.dart';
import '../../domain/entities/contribution_attachment.dart';
import '../../domain/entities/contribution_summary.dart';

/// `429` do contrato — o formulário usa `resetAt` para dizer quando tentar de novo.
class ContributionQuotaExceeded implements Exception {
  ContributionQuotaExceeded(this.resetAt);
  final DateTime resetAt;
}

/// `400`/`413` do contrato — o formulário traduz `error` em mensagem.
class ContributionRejected implements Exception {
  ContributionRejected({required this.status, required this.error, this.file});
  final int status;
  final String error;
  final String? file;
}

/// `POST /api/contributions` (multipart) e leitura das próprias contribuições
/// — tudo com Bearer `sess_…`.
class ContributionsRemoteDatasource {
  ContributionsRemoteDatasource(this._dio);

  final Dio _dio;

  Options _auth(String sessionToken, {Duration? sendTimeout}) => Options(
    headers: {'Authorization': 'Bearer $sessionToken'},
    sendTimeout: sendTimeout,
    // 4xx são respostas do contrato, não falhas de transporte.
    validateStatus: (status) => status != null && status < 500,
  );

  void _throwIfUnauthorized(int? status) {
    if (status == 401) throw AuthUnauthorizedException(status!);
  }

  /// Envia o rascunho já serializado (`ContributionDraft.toPayload`) mais os
  /// anexos como `file[]` multipart. Sem retry aqui de propósito — quem
  /// chama decide se tenta de novo, e um retry automático duplicaria a
  /// contribuição no servidor.
  Future<({String id, ContributionStatus status})> submit({
    required String sessionToken,
    required Map<String, dynamic> payload,
    required List<ContributionAttachment> attachments,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({'payload': jsonEncode(payload)});
    for (final a in attachments) {
      form.files.add(
        MapEntry('file', MultipartFile.fromBytes(a.bytes, filename: a.name)),
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ColdigomEndpoints.contributions,
      data: form,
      options: _auth(sessionToken, sendTimeout: const Duration(minutes: 5)),
      onSendProgress: onProgress,
    );
    _throwIfUnauthorized(response.statusCode);
    final data = response.data ?? const <String, dynamic>{};
    if (response.statusCode == 429) {
      throw ContributionQuotaExceeded(
        DateTime.tryParse(data['resetAt'] as String? ?? '') ??
            DateTime.now().toUtc().add(const Duration(days: 1)),
      );
    }
    if (response.statusCode != 201) {
      throw ContributionRejected(
        status: response.statusCode ?? 0,
        error: data['error'] as String? ?? 'unknown',
        file: data['file'] as String?,
      );
    }
    return (
      id: data['id'] as String,
      status: ContributionStatus.fromWire(data['status'] as String),
    );
  }

  Future<ContributionsPage> fetchMine({
    required String sessionToken,
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.contributionsMine,
      queryParameters: {'cursor': ?cursor},
      options: _auth(sessionToken),
    );
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('contributions_mine_${response.statusCode}');
    }
    final data = response.data!;
    return ContributionsPage(
      items: [
        for (final j in data['data'] as List)
          ContributionSummary.fromJson((j as Map).cast<String, dynamic>()),
      ],
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<ContributionSummary> fetchOne({
    required String sessionToken,
    required String id,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ColdigomEndpoints.contribution(id),
      options: _auth(sessionToken),
    );
    _throwIfUnauthorized(response.statusCode);
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('contribution_${response.statusCode}');
    }
    return ContributionSummary.fromJson(
      (response.data!['data'] as Map).cast<String, dynamic>(),
    );
  }
}
