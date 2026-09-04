import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/errors/user_message_for.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? statusCode}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  late AppLocalizations pt;
  late AppLocalizations en;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('DioException', () {
    test('erro de conexão vira mensagem de rede', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.connectionError)),
        pt.errorNoConnection,
      );
    });

    test('os três timeouts viram mensagem de timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          userMessageFor(pt, _dio(type)),
          pt.errorTimeout,
          reason: '$type',
        );
      }
    });

    test('5xx vira mensagem de servidor', () {
      for (final status in [500, 502, 503]) {
        expect(
          userMessageFor(
            pt,
            _dio(DioExceptionType.badResponse, statusCode: status),
          ),
          pt.errorServer,
          reason: '$status',
        );
      }
    });

    test('401 e 403 viram sessão expirada', () {
      for (final status in [401, 403]) {
        expect(
          userMessageFor(
            pt,
            _dio(DioExceptionType.badResponse, statusCode: status),
          ),
          pt.errorSessionExpired,
          reason: '$status',
        );
      }
    });

    test('404 e outros 4xx caem no genérico', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.badResponse, statusCode: 404)),
        pt.errorGeneric,
      );
    });

    test('cancelamento e erro desconhecido caem no genérico', () {
      expect(
        userMessageFor(pt, _dio(DioExceptionType.cancel)),
        pt.errorGeneric,
      );
      expect(
        userMessageFor(pt, _dio(DioExceptionType.unknown)),
        pt.errorGeneric,
      );
    });
  });

  test('StorageUnavailableException vira aviso de armazenamento', () {
    expect(
      userMessageFor(pt, const StorageUnavailableException('playlists.insert')),
      pt.offlineStorageUnavailable,
    );
  });

  test('AuthUnauthorizedException vira sessão expirada', () {
    expect(
      userMessageFor(pt, AuthUnauthorizedException(401)),
      pt.errorSessionExpired,
    );
  });

  group('exceções de PDF já conhecidas', () {
    test('PDF offline indisponível mantém a mensagem própria', () {
      const error = PdfOfflineUnavailableException(pdfId: 'p1');

      expect(userMessageFor(pt, error), error.message);
    });

    test('PDF removido do dispositivo mantém a mensagem própria', () {
      const error = PdfExternallyDeletedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), error.message);
    });

    test('falha de download mantém a mensagem própria', () {
      const error = PdfFetchFailedException('Falha ao baixar o PDF');

      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });
  });

  group('fallback', () {
    test('exceção desconhecida nunca vaza o toString', () {
      final message = userMessageFor(pt, StateError('detalhe_interno_feio'));

      expect(message, pt.errorGeneric);
      expect(message, isNot(contains('detalhe_interno_feio')));
    });

    test('String crua também cai no genérico', () {
      expect(userMessageFor(pt, 'boom'), pt.errorGeneric);
    });
  });

  test('respeita o idioma recebido', () {
    expect(
      userMessageFor(en, _dio(DioExceptionType.connectionError)),
      en.errorNoConnection,
    );
    expect(
      userMessageFor(en, _dio(DioExceptionType.connectionError)),
      isNot(pt.errorNoConnection),
    );
  });
}
