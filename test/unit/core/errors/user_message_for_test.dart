import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/errors/user_message_for.dart';
import 'package:coldigui/features/auth/data/auth_remote_datasource.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
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
    test('PDF removido do dispositivo mantém a mensagem própria', () {
      const error = PdfExternallyDeletedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), error.message);
    });

    test('falha de download mantém a mensagem própria', () {
      const error = PdfFetchFailedException('Falha ao baixar o PDF');

      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });
  });

  group('causa embrulhada (Important 2)', () {
    test('PdfFetchFailedException com causa de rede vira erro de conexão', () {
      const error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: null,
      );
      final withCause = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.connectionError),
      );

      expect(userMessageFor(pt, withCause), pt.errorNoConnection);
      // Sem causa continua caindo na mensagem própria.
      expect(userMessageFor(pt, error), 'Falha ao baixar o PDF');
    });

    test('causa de timeout vira mensagem de timeout', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.receiveTimeout),
      );

      expect(userMessageFor(pt, error), pt.errorTimeout);
    });

    test('causa 5xx vira mensagem de servidor', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: _dio(DioExceptionType.badResponse, statusCode: 503),
      );

      expect(userMessageFor(pt, error), pt.errorServer);
    });

    test('causa de armazenamento vira aviso de armazenamento', () {
      final error = PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: const StorageUnavailableException('offline.put'),
      );

      expect(userMessageFor(pt, error), pt.offlineStorageUnavailable);
    });

    test('PdfLocalOpenFailure desembrulha a causa de rede', () {
      final error = PdfLocalOpenFailure(
        cause: _dio(DioExceptionType.connectionError),
        hasValidMagicBytes: null,
      );

      expect(userMessageFor(pt, error), pt.errorNoConnection);
    });
  });

  group('família PDF prefere chave l10n (Important 2)', () {
    test('PDF offline indisponível usa a chave, não o literal PT', () {
      const error = PdfOfflineUnavailableException(pdfId: 'p1');

      expect(userMessageFor(pt, error), pt.pdfOfflineUnavailableMessage);
      expect(userMessageFor(en, error), en.pdfOfflineUnavailableMessage);
      // Em inglês não pode sair a mensagem PT embutida na exceção.
      expect(userMessageFor(en, error), isNot(error.message));
    });

    test('leitura local falha usa a chave própria', () {
      const error = PdfLocalReadFailedException(pdfId: 'p1');

      expect(userMessageFor(en, error), en.pdfLocalReadFailedMessage);
    });

    test('sem chave l10n cai na mensagem da própria exceção', () {
      const error = PdfExternallyDeletedException(pdfId: 'p1');

      expect(userMessageFor(pt, error), error.message);
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
