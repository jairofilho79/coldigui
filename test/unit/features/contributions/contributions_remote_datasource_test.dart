import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);
  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ContributionsRemoteDatasource, _FixedAdapter) _make(int status, Object? body) {
  final adapter = _FixedAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return (ContributionsRemoteDatasource(dio), adapter);
}

void main() {
  final payload = {
    'kind': 'improvement',
    'subkind': 'feature',
    'title': 't',
    'body': 'b',
  };

  test(
    'submit manda multipart com payload e file[], Bearer, e devolve id/status',
    () async {
      final (ds, adapter) = _make(201, {'id': 'c1', 'status': 'recebida'});
      final out = await ds.submit(
        sessionToken: 'sess_x',
        payload: payload,
        attachments: [
          ContributionAttachment(
            name: 'a.pdf',
            size: 3,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      expect(out.id, 'c1');
      expect(out.status, ContributionStatus.recebida);
      final req = adapter.lastRequest!;
      expect(req.path, '/api/contributions');
      expect(req.headers['Authorization'], 'Bearer sess_x');
      final form = req.data as FormData;
      expect(form.fields.single.key, 'payload');
      expect(jsonDecode(form.fields.single.value), payload);
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'a.pdf');
    },
  );

  test('429 vira ContributionQuotaExceeded com resetAt', () async {
    final (ds, _) = _make(429, {
      'error': 'quota_exceeded',
      'resetAt': '2026-09-18T00:00:00Z',
    });
    expect(
      () =>
          ds.submit(sessionToken: 's', payload: payload, attachments: const []),
      throwsA(
        isA<ContributionQuotaExceeded>().having(
          (e) => e.resetAt.toUtc().hour,
          'hora',
          0,
        ),
      ),
    );
  });

  test('400/413 viram ContributionRejected com error e file', () async {
    final (ds, _) = _make(413, {'error': 'file_too_large', 'file': 'g.pdf'});
    expect(
      () =>
          ds.submit(sessionToken: 's', payload: payload, attachments: const []),
      throwsA(
        isA<ContributionRejected>()
            .having((e) => e.error, 'error', 'file_too_large')
            .having((e) => e.file, 'file', 'g.pdf'),
      ),
    );
  });

  test('401 vira AuthUnauthorizedException', () async {
    final (ds, _) = _make(401, {'error': 'unauthorized'});
    expect(
      () => ds.fetchMine(sessionToken: 's'),
      throwsA(isA<AuthUnauthorizedException>()),
    );
  });

  test('fetchMine parseia página, status em_analise e cursor', () async {
    final (ds, adapter) = _make(200, {
      'data': [
        {
          'id': 'c1',
          'kind': 'wrong_info',
          'subkind': 'metadata',
          'title': 'T',
          'body': 'B',
          'fields': {'field': 'tonality'},
          'links': ['https://youtu.be/a'],
          'status': 'em_analise',
          'decision_note': null,
          'created_at': '2026-09-17 10:00:00',
          'updated_at': '2026-09-17 11:00:00',
          'files': [
            {
              'id': 'f1',
              'original_name': 'g.pdf',
              'size': 12,
              'scan_status': 'limpa',
            },
          ],
        },
      ],
      'nextCursor': 'abc',
    });
    final page = await ds.fetchMine(sessionToken: 's', cursor: 'prev');
    expect(adapter.lastRequest!.queryParameters['cursor'], 'prev');
    expect(page.nextCursor, 'abc');
    final c = page.items.single;
    expect(c.status, ContributionStatus.emAnalise);
    expect(c.createdAt.isUtc, isTrue);
    expect(c.files.single.originalName, 'g.pdf');
    expect(c.links, ['https://youtu.be/a']);
  });
}
